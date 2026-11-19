import Foundation
import Testing
@testable import BusTimeApp

private final class APIStubState: @unchecked Sendable {
    private let lock = NSLock()
    private var _changed = false
    private var _offline = false
    private var _invalid = false
    private var _requests: [URLRequest] = []
    var changed: Bool { get { lock.withLock { _changed } } set { lock.withLock { _changed = newValue } } }
    var offline: Bool { get { lock.withLock { _offline } } set { lock.withLock { _offline = newValue } } }
    var invalid: Bool { get { lock.withLock { _invalid } } set { lock.withLock { _invalid = newValue } } }
    var requests: [URLRequest] { lock.withLock { _requests } }
    func record(_ request: URLRequest) { lock.withLock { _requests.append(request) } }
    func reset() { lock.withLock { _requests = []; _changed = false; _offline = false; _invalid = false } }
}

private final class TimetableURLProtocol: URLProtocol, @unchecked Sendable {
    static let state = APIStubState()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        do {
            Self.state.record(request)
            if Self.state.offline { throw URLError(.notConnectedToInternet) }
            let payload = try seedPayload()
            let snapshots = payload["snapshots"] as! [[String: Any]]
            let path = request.url!.path
            let changed = Self.state.changed
            let version = changed ? 2 : 1
            let etag = "\"catalog-\(version)\""
            var result: [String: Any]
            var status = 200
            if path.hasSuffix("/routes") {
                result = ["schema_version": 1, "routes": snapshots.map {
                    ["id": $0["route_id"]!, "version": $0["route_id"] as? String == "mansion-station" ? version : 1]
                }]
                if request.value(forHTTPHeaderField: "If-None-Match") == etag { status = 304 }
            } else {
                let route = path.components(separatedBy: "/")[4]
                result = snapshots.first { $0["route_id"] as? String == route }!
                if path.hasSuffix("/changes") {
                    var trips = result.removeValue(forKey: "buses") as! [[String: Any]]
                    let deleted = trips.removeFirst()["id"]!
                    var updated = trips.removeFirst()
                    updated["note"] = "API updated"
                    if Self.state.invalid {
                        var stops = updated["stops"] as! [[String: Any]]
                        stops[0]["time"] = "25:01"
                        updated["stops"] = stops
                    }
                    result["version"] = 2
                    result["upserts"] = [updated]
                    result["deleted_ids"] = [deleted]
                }
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["ETag": etag])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if status != 304 { client?.urlProtocol(self, didLoad: try JSONSerialization.data(withJSONObject: result)) }
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
}

private func seedPayload() throws -> [String: Any] {
    let url = Bundle(for: FixtureBundleAnchor.self).url(forResource: "timetableSeed", withExtension: "json")!
    return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
}
private final class FixtureBundleAnchor: NSObject {}

@Suite(.serialized)
struct TimetableRepositoryTests {
    private func repository(cacheStore: TimetableCacheStore? = nil,
                            now: Date = Date(), connectionStream: AsyncStream<Bool>? = nil) -> TimetableRepository {
        TimetableURLProtocol.state.reset()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [TimetableURLProtocol.self]
        return TimetableRepository(baseURL: URL(string: "https://timetable.test/api/v1")!, session: URLSession(configuration: config),
                                   cacheStore: cacheStore, nowProvider: { now }, connectionStream: connectionStream)
    }

    @Test func initialDatabaseExactlyPreservesBundledTrips() async throws {
        let snapshots = try await repository().refresh()
        #expect(snapshots.values.reduce(0) { $0 + $1.buses.count } == 115)
        for route in BusRoute.allCases {
            let snapshot = snapshots[route.origin.identifier + "-" + route.destination.identifier]!
            let date = AppCalendar.japan.date(from: DateComponents(year: 2026, month: 8, day: 12))!
            let remote = snapshot.timetable(on: date)
            let bundled = BusSchedule.timetable(for: route)
            #expect(Set(remote.map(\.id)) == Set(bundled.map(\.id)))
            for trip in remote { #expect(trip.note == bundled.first(where: { $0.id == trip.id })?.note) }
        }
    }

    @Test func refreshUsesETagThenOnlyChangedRouteDeltaIncludingDeletion() async throws {
        let repo = repository()
        let initial = try await repo.refresh()
        let unchanged = try await repo.refresh()
        #expect(unchanged["mansion-station"]?.version == 1)
        #expect(TimetableURLProtocol.state.requests.count == 7) // catalogue + five routes + 304 catalogue
        TimetableURLProtocol.state.changed = true
        let updated = try await repo.refresh()
        #expect(updated["mansion-station"]?.version == 2)
        #expect(updated["mansion-station"]!.buses.count == initial["mansion-station"]!.buses.count - 1)
        #expect(updated["mansion-station"]!.buses.contains { $0.note == "API updated" })
        #expect(TimetableURLProtocol.state.requests.count == 9)
        #expect(TimetableURLProtocol.state.requests.last?.url?.query == "since_version=1")
        #expect(TimetableURLProtocol.state.requests.allSatisfy { $0.value(forHTTPHeaderField: "X-Admin-Key") == nil })
    }

    @Test @MainActor func startupRefreshUpdatesViewModelTimetable() async throws {
        let repo = repository()
        let date = AppCalendar.japan.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 10))!
        let defaults = UserDefaults(suiteName: "TimetableRepositoryTests")!
        defaults.removePersistentDomain(forName: "TimetableRepositoryTests")
        defer { defaults.removePersistentDomain(forName: "TimetableRepositoryTests") }
        let model = HomeViewModel(nowProvider: { date }, defaults: defaults, timetableRepository: repo)
        await model.refreshTimetables()
        let before = model.currentFullTimetable.count
        TimetableURLProtocol.state.changed = true
        await model.refreshTimetables()
        #expect(model.currentFullTimetable.count == before - 1)
        #expect(model.currentFullTimetable.contains { $0.note == "API updated" })
    }

    @Test func specialSuspensionOverridesNormalWeekdayAndDoesNotRepeat() async throws {
        let snapshots = try await repository().refresh()
        let seed = snapshots["mansion-station"]!
        let special = RemoteSchedule(id: "special", routeId: seed.routeId, kind: "special", serviceDate: "2026-08-12", validFrom: nil, validUntil: nil, isSuspended: true, priority: 10)
        let snapshot = TimetableSnapshot(schemaVersion: 1, routeId: seed.routeId, version: 2, updatedAt: seed.updatedAt, schedules: seed.schedules + [special], buses: seed.buses)
        let day = AppCalendar.japan.date(from: DateComponents(year: 2026, month: 8, day: 12))!
        #expect(snapshot.timetable(on: day).isEmpty)
        #expect(snapshot.timetable(on: AppCalendar.japan.date(byAdding: .day, value: 1, to: day)!).count == seed.buses.count)
        let malformed = TimetableSnapshot(schemaVersion: 2, routeId: seed.routeId, version: 2, updatedAt: seed.updatedAt, schedules: seed.schedules, buses: seed.buses)
        #expect(throws: TimetableAPIError.self) { try malformed.validate(expectedRoute: seed.routeId) }
    }

    @Test func specialWeekendNotificationUsesTheActualServiceDate() {
        let calendar = AppCalendar.japan
        let saturday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 8))!
        let trip = RemoteTrip(id: "special-bus", routeId: "mansion-station", scheduleId: "special", stops: [
            RemoteStopTime(stopId: "mansion", name: "コロンブスシティ", time: "9:00"),
            RemoteStopTime(stopId: "station", name: "海浜幕張駅", time: "9:08")
        ], note: nil)
        let schedule = RemoteSchedule(id: "special", routeId: "mansion-station", kind: "special", serviceDate: "2026-08-15", validFrom: nil, validUntil: nil, isSuspended: false, priority: 10)
        let snapshot = TimetableSnapshot(schemaVersion: 1, routeId: "mansion-station", version: 2, updatedAt: "2026-08-12T01:00:00Z", schedules: [schedule], buses: [trip])
        let bus = snapshot.timetable(on: saturday)[0]
        let dates = BusNotificationTimeCalculator.notificationDate(for: bus.departure, minutesBefore: 5,
            from: saturday, calendar: calendar, serviceDate: bus.scheduledServiceDate)
        #expect(dates?.departureDate == calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 9)))
        #expect(dates?.notificationDate == calendar.date(from: DateComponents(year: 2026, month: 8, day: 15, hour: 8, minute: 55)))
        let afterDeparture = saturday.addingTimeInterval(2 * 60 * 60)
        #expect(BusNotificationTimeCalculator.nextDepartureDate(for: bus.departure, from: afterDeparture,
            calendar: calendar, serviceDate: bus.scheduledServiceDate) == nil)
    }

    private func temporaryCache() -> TimetableCacheStore {
        TimetableCacheStore(url: FileManager.default.temporaryDirectory
            .appendingPathComponent("TimetableTests-" + UUID().uuidString).appendingPathComponent("cache.json"))
    }

    @Test @MainActor func cachedAPIChangesDisplayImmediatelyAfterRestartWithoutNetwork() async throws {
        let store = temporaryCache()
        defer { try? FileManager.default.removeItem(at: store.url.deletingLastPathComponent()) }
        let first = repository(cacheStore: store)
        _ = try await first.refresh()
        TimetableURLProtocol.state.changed = true
        let changed = try await first.refresh()
        #expect(await first.info().didUpdate)
        let restored = repository(cacheStore: store)
        #expect(restored.initialCache?.snapshots["mansion-station"]?.version == 2)
        let date = AppCalendar.japan.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 10))!
        let defaults = UserDefaults(suiteName: "TimetableCacheTests")!
        defaults.removePersistentDomain(forName: "TimetableCacheTests")
        defer { defaults.removePersistentDomain(forName: "TimetableCacheTests") }
        let model = HomeViewModel(nowProvider: { date }, defaults: defaults, timetableRepository: restored)
        #expect(model.currentFullTimetable.count == changed["mansion-station"]!.buses.count)
        #expect(model.currentFullTimetable.contains { $0.note == "API updated" })
        #expect(TimetableURLProtocol.state.requests.isEmpty)
        await restored.setConnection(online: false)
        await model.refreshTimetables()
        #expect(model.timetableSyncInfo.connection == .offline)
        #expect(model.timetableSyncInfo.hasCache)
        #expect(TimetableURLProtocol.state.requests.isEmpty)
    }

    @Test func connectionFailurePreservesSavedDataAndRecoveryUsesDelta() async throws {
        let store = temporaryCache()
        defer { try? FileManager.default.removeItem(at: store.url.deletingLastPathComponent()) }
        _ = try await repository(cacheStore: store).refresh()
        let original = try Data(contentsOf: store.url)
        let restored = repository(cacheStore: store)
        TimetableURLProtocol.state.offline = true
        await #expect(throws: URLError.self) { try await restored.refresh() }
        #expect(await restored.info().connection == .offline)
        #expect(try Data(contentsOf: store.url) == original)
        TimetableURLProtocol.state.offline = false
        TimetableURLProtocol.state.changed = true
        await restored.setConnection(online: true)
        let updated = try await restored.refresh()
        #expect(updated["mansion-station"]?.version == 2)
        #expect(TimetableURLProtocol.state.requests.last?.url?.query == "since_version=1")
        #expect(store.load(endpoint: URL(string: "https://timetable.test/api/v1")!)?.snapshots["mansion-station"]?.version == 2)
    }

    @Test func brokenCacheTriggersFullRefetchAndReplacement() async throws {
        let store = temporaryCache()
        defer { try? FileManager.default.removeItem(at: store.url.deletingLastPathComponent()) }
        _ = try await repository(cacheStore: store).refresh()
        try Data("{corrupted".utf8).write(to: store.url)
        let restored = repository(cacheStore: store)
        #expect(restored.initialCache == nil)
        let loaded = try await restored.refresh()
        #expect(loaded.count == 5)
        #expect(TimetableURLProtocol.state.requests.count == 6)
        #expect(TimetableURLProtocol.state.requests.allSatisfy { $0.url?.query == nil })
        #expect(store.load(endpoint: URL(string: "https://timetable.test/api/v1")!) != nil)
        #expect(store.load(endpoint: URL(string: "https://another.test/api/v1")!) == nil)
    }

    @Test func invalidUpdateDoesNotPoisonCacheOrAdvanceVersion() async throws {
        let store = temporaryCache()
        defer { try? FileManager.default.removeItem(at: store.url.deletingLastPathComponent()) }
        let repo = repository(cacheStore: store)
        _ = try await repo.refresh()
        let original = try Data(contentsOf: store.url)
        TimetableURLProtocol.state.changed = true
        TimetableURLProtocol.state.invalid = true
        await #expect(throws: TimetableAPIError.self) { try await repo.refresh() }
        #expect(await repo.info().connection == .unavailable)
        #expect(try Data(contentsOf: store.url) == original)
        TimetableURLProtocol.state.invalid = false
        let recovered = try await repo.refresh()
        #expect(recovered["mansion-station"]?.version == 2)
        #expect(TimetableURLProtocol.state.requests.last?.url?.query == "since_version=1")
    }

    @Test func unchangedServerRefreshesFreshnessAndPersistsETag() async throws {
        let store = temporaryCache()
        defer { try? FileManager.default.removeItem(at: store.url.deletingLastPathComponent()) }
        let before = Date(timeIntervalSince1970: 1786496400)
        _ = try await repository(cacheStore: store, now: before).refresh()
        let after = before.addingTimeInterval(4 * 24 * 60 * 60)
        let restored = repository(cacheStore: store, now: after)
        let stale = await restored.info()
        #expect(stale.isStale(at: before.addingTimeInterval(3 * 24 * 60 * 60)))
        #expect(!stale.isStale(at: before.addingTimeInterval(3 * 24 * 60 * 60 - 1)))
        _ = try await restored.refresh()
        #expect(TimetableURLProtocol.state.requests.count == 1)
        #expect(TimetableURLProtocol.state.requests.first?.value(forHTTPHeaderField: "If-None-Match") == "\"catalog-1\"")
        #expect(await restored.info().verifiedAt == after)
        #expect(await restored.info().isStale(at: after) == false)
        #expect(store.load(endpoint: URL(string: "https://timetable.test/api/v1")!)?.verifiedAt == after)
    }

    @Test @MainActor func networkReturnAutomaticallySynchronizesViewModel() async throws {
        var continuation: AsyncStream<Bool>.Continuation!
        let stream = AsyncStream<Bool> { continuation = $0 }
        let repo = repository(connectionStream: stream)
        let date = AppCalendar.japan.date(from: DateComponents(year: 2026, month: 8, day: 12, hour: 10))!
        let defaults = UserDefaults(suiteName: "TimetableConnectionTests")!
        defaults.removePersistentDomain(forName: "TimetableConnectionTests")
        defer { defaults.removePersistentDomain(forName: "TimetableConnectionTests") }
        let model = HomeViewModel(nowProvider: { date }, defaults: defaults, timetableRepository: repo)
        let watcher = Task { await model.watchTimetableConnectivity() }
        defer { watcher.cancel(); continuation.finish() }
        continuation.yield(false)
        for _ in 0..<500 {
            if model.timetableSyncInfo.connection == .offline { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(model.timetableSyncInfo.connection == .offline)
        #expect(TimetableURLProtocol.state.requests.isEmpty)
        continuation.yield(true)
        for _ in 0..<500 {
            if model.timetableSyncInfo.connection == .current { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(model.timetableSyncInfo.connection == .current)
        #expect(TimetableURLProtocol.state.requests.count == 6)
    }

}
