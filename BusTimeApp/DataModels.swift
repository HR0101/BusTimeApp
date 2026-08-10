import Foundation

// 1つのバスの便を表す構造体です。
// SwiftUIのリストで各項目をユニークに識別するためにIdentifiableプロトコルに準拠させます。
struct Bus: Identifiable {
    var stops: [BusStopTime]
    var note: String?
    
    var departure: String {
        stops.first?.time ?? ""
    }
    
    var arrival: String {
        stops.last?.time ?? ""
    }
    
    // Identifiableプロトコルに必須のプロパティ。
    var id: String {
        stops.map { "\($0.name)-\($0.time)" }.joined(separator: "|")
    }
    
    var originName: String {
        stops.first?.name ?? ""
    }
    
    var destinationName: String {
        stops.last?.name ?? ""
    }
    
    var intermediateStops: [BusStopTime] {
        guard stops.count > 2 else { return [] }
        return Array(stops.dropFirst().dropLast())
    }
    
    var stopSummary: String {
        stops.map(\.name).joined(separator: " → ")
    }
    
    init(departure: String, arrival: String, originName: String, destinationName: String, note: String? = nil) {
        self.stops = [
            BusStopTime(name: originName, time: departure),
            BusStopTime(name: destinationName, time: arrival)
        ]
        self.note = note
    }
    
    init(stops: [BusStopTime], note: String? = nil) {
        self.stops = stops
        self.note = note
    }
}

struct BusStopTime: Identifiable, Hashable {
    var name: String
    var time: String
    
    var id: String {
        "\(name)-\(time)"
    }
}
