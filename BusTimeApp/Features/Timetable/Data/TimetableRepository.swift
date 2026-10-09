import Foundation

struct RemoteStopTime: Codable, Sendable {
    let stopId: String
    let name: String
    let time: String
}

struct RemoteTrip: Codable, Sendable {
    let id: String
    let routeId: String
    let scheduleId: String
    let stops: [RemoteStopTime]
    let note: String?

    var bus: Bus {
        let displayedNote: String?
        switch note {
        case "お買い物便": displayedNote = L10n.BusNote.shopping
        case "ヨーカドー経由": displayedNote = L10n.BusNote.viaYokado
        case "海浜幕張駅経由": displayedNote = L10n.BusNote.viaStation
        default: displayedNote = note
        }
        return Bus(stops: stops.map { BusStopTime(name: $0.name, time: $0.time) }, note: displayedNote)
    }
}

struct RemoteSchedule: Codable, Sendable {
    let id: String
    let routeId: String
    let kind: String
    let serviceDate: String?
    let validFrom: String?
    let validUntil: String?
    let isSuspended: Bool
    let priority: Int
}

struct TimetableSnapshot: Codable, Sendable {
    let schemaVersion: Int
    let routeId: String
    let version: Int
    let updatedAt: String
    let schedules: [RemoteSchedule]
    var buses: [RemoteTrip]

    func schedule(on date: Date, calendar: Calendar = AppCalendar.japan) -> RemoteSchedule? {
        let parts = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
        let key = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        let kind: String
        if parts.weekday == 1 || parts.weekday == 7 { kind = "weekend" }
        else { kind = BusServiceCalendar.isServiceDay(date, calendar: calendar) ? "weekday" : "holiday" }
        return schedules.filter {
            ($0.validFrom == nil || $0.validFrom! <= key) && ($0.validUntil == nil || $0.validUntil! >= key)
            && ($0.kind == "special" ? $0.serviceDate == key : $0.kind == kind)
        }.sorted {
            if ($0.kind == "special") != ($1.kind == "special") { return $0.kind == "special" }
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            return $0.id < $1.id
        }.first
    }

    func timetable(on date: Date, calendar: Calendar = AppCalendar.japan) -> [Bus] {
        guard let schedule = schedule(on: date, calendar: calendar), !schedule.isSuspended else { return [] }
        return buses.filter { $0.scheduleId == schedule.id }.map {
            var bus = $0.bus
            bus.scheduledServiceDate = date
            return bus
        }.sorted {
            Self.minutes($0.departure) < Self.minutes($1.departure)
        }
    }

    static func minutes(_ time: String) -> Int {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return -1 }
        return (parts[0] + (parts[0] < 4 ? 24 : 0)) * 60 + parts[1]
    }

    func validate(expectedRoute: String) throws {
        guard schemaVersion == 1, version > 0, routeId == expectedRoute,
              Set(buses.map(\.id)).count == buses.count,
              Set(schedules.map(\.id)).count == schedules.count else { throw TimetableAPIError.invalidData }
        for schedule in schedules {
            guard schedule.routeId == routeId, ["weekday", "weekend", "holiday", "special"].contains(schedule.kind),
                  (schedule.kind == "special") == (schedule.serviceDate != nil) else { throw TimetableAPIError.invalidData }
        }
        let endpoints = routeId.split(separator: "-").map(String.init)
        for trip in buses {
            let times = trip.stops.map { Self.minutes($0.time) }
            guard trip.routeId == routeId, schedules.contains(where: { $0.id == trip.scheduleId }),
                  trip.stops.count >= 2, endpoints.count == 2,
                  trip.stops.first?.stopId == endpoints[0], trip.stops.last?.stopId == endpoints[1],
                  !times.contains(-1), zip(times, times.dropFirst()).allSatisfy({ $0 < $1 }) else {
                throw TimetableAPIError.invalidData
            }
        }
    }
}

private struct TimetableDelta: Decodable {
    let schemaVersion: Int
    let routeId: String
    let version: Int
    let updatedAt: String
    let schedules: [RemoteSchedule]
    let upserts: [RemoteTrip]
    let deletedIds: [String]

    func applying(to previous: TimetableSnapshot) throws -> TimetableSnapshot {
        guard routeId == previous.routeId, version >= previous.version,
              Set(upserts.map(\.id)).isDisjoint(with: deletedIds) else { throw TimetableAPIError.invalidData }
        var trips = Dictionary(uniqueKeysWithValues: previous.buses.map { ($0.id, $0) })
        for id in deletedIds { trips.removeValue(forKey: id) }
        for trip in upserts { trips[trip.id] = trip }
        return TimetableSnapshot(schemaVersion: schemaVersion, routeId: routeId, version: version,
                                 updatedAt: updatedAt, schedules: schedules, buses: Array(trips.values))
    }
}

enum TimetableAPIError: Error { case invalidData, status(Int) }

/// Uses public read endpoints only; administrator credentials never enter the app.
actor TimetableRepository {
    private let baseURL: URL
    private let session: URLSession
    private var snapshots: [String: TimetableSnapshot] = [:]
    private var catalogETag: String?
    private var refreshing = false

    static var configured: TimetableRepository? {
        var endpoint = Bundle.main.object(forInfoDictionaryKey: "TimetableAPIBaseURL") as? String
        #if DEBUG
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "TimetableAPIBaseURL"),
           ProcessInfo.processInfo.arguments.indices.contains(index + 1) {
            endpoint = ProcessInfo.processInfo.arguments[index + 1]
        }
        #endif
        guard let endpoint, let url = URL(string: endpoint), url.host != nil else { return nil }
        #if DEBUG
        guard url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1"].contains(url.host!)) else { return nil }
        #else
        guard url.scheme == "https" else { return nil }
        #endif
        return TimetableRepository(baseURL: url)
    }

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func refresh() async throws -> [String: TimetableSnapshot] {
        guard !refreshing else { return snapshots }
        refreshing = true
        defer { refreshing = false }
        var request = URLRequest(url: baseURL.appendingPathComponent("routes"))
        request.timeoutInterval = 15
        request.setValue(catalogETag, forHTTPHeaderField: "If-None-Match")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw TimetableAPIError.invalidData }
        if response.statusCode == 304 { return snapshots }
        guard response.statusCode == 200 else { throw TimetableAPIError.status(response.statusCode) }
        struct Catalog: Decodable {
            struct Route: Decodable { let id: String; let version: Int }
            let schemaVersion: Int
            let routes: [Route]
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let catalog = try decoder.decode(Catalog.self, from: data)
        let knownRoutes = BusRoute.allCases.map { $0.origin.identifier + "-" + $0.destination.identifier }
        guard catalog.schemaVersion == 1, Set(catalog.routes.map(\.id)).isSuperset(of: knownRoutes) else {
            throw TimetableAPIError.invalidData
        }
        // Publish the complete new set only after every changed route has passed validation.
        var updated = snapshots
        for route in catalog.routes where knownRoutes.contains(route.id) && snapshots[route.id]?.version != route.version {
            let previous = snapshots[route.id]
            let useDelta = previous != nil && previous!.version < route.version
            var url = baseURL.appendingPathComponent("timetables/\(route.id)")
            if useDelta {
                url.appendPathComponent("changes")
                var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                components.queryItems = [URLQueryItem(name: "since_version", value: String(previous!.version))]
                url = components.url!
            }
            var tripRequest = URLRequest(url: url)
            tripRequest.timeoutInterval = 15
            let (body, result) = try await session.data(for: tripRequest)
            guard let http = result as? HTTPURLResponse, http.statusCode == 200 else {
                throw TimetableAPIError.status((result as? HTTPURLResponse)?.statusCode ?? 0)
            }
            let snapshot = try useDelta
                ? decoder.decode(TimetableDelta.self, from: body).applying(to: previous!)
                : decoder.decode(TimetableSnapshot.self, from: body)
            try snapshot.validate(expectedRoute: route.id)
            updated[route.id] = snapshot
        }
        snapshots = updated
        catalogETag = response.value(forHTTPHeaderField: "ETag")
        return snapshots
    }
}
