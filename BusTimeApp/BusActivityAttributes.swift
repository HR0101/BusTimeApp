import Foundation
import ActivityKit

public struct BusActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // 動的に変化するデータ（残り時間や出発状況）
        public var remainingMinutes: Int
        public var isDeparted: Bool
    }

    // 静的なデータ（対象便と出発日時）
    public var busID: String
    public var busDepartureTime: String
    public var busArrivalTime: String
    public var originName: String
    public var destinationName: String
    public var departureDate: Date
    public var routeName: String
}
