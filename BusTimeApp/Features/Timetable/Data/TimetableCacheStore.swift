import Foundation

struct TimetableCache: Codable, Sendable {
    let formatVersion: Int
    let endpoint: String
    let snapshots: [String: TimetableSnapshot]
    let catalogETag: String?
    let verifiedAt: Date
}

struct TimetableCacheStore: Sendable {
    let url: URL

    static var standard: TimetableCacheStore {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return TimetableCacheStore(url: directory.appendingPathComponent("Timetables/cache-v1.json"))
    }

    func load(endpoint: URL) -> TimetableCache? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size <= 5_000_000, let data = try? Data(contentsOf: url) else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cache = try decoder.decode(TimetableCache.self, from: data)
            guard cache.formatVersion == 1, cache.endpoint == endpoint.absoluteString else { return nil }
            let known = BusRoute.allCases.map { $0.origin.identifier + "-" + $0.destination.identifier }
            guard Set(cache.snapshots.keys) == Set(known) else { return nil }
            for (route, snapshot) in cache.snapshots { try snapshot.validate(expectedRoute: route) }
            return cache
        } catch {
            // Never expose a partially decoded cache. The next sync will fetch all routes.
            return nil
        }
    }

    func save(_ cache: TimetableCache) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(cache)
        guard data.count <= 5_000_000 else { throw TimetableAPIError.invalidData }
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        var location = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? location.setResourceValues(values)
    }
}

enum TimetableConnectionState: Sendable { case cached, syncing, current, offline, unavailable }

struct TimetableSyncInfo: Sendable {
    var connection: TimetableConnectionState = .cached
    var verifiedAt: Date?
    var hasCache = false
    var didUpdate = false

    func isStale(at date: Date) -> Bool {
        guard let verifiedAt else { return false }
        return date.timeIntervalSince(verifiedAt) >= 3 * 24 * 60 * 60
    }
}
