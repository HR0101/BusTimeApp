import Foundation
import Combine
import ActivityKit
import CoreLocation
import UIKit

// このクラスが、アプリの状態とロジックを管理します。
// ObservableObjectなので、SwiftUIのView（画面）はこのクラスのプロパティの変更を監視できます。
/// ホーム画面の状態とユーザー操作を仲介するViewModelです。
/// 時刻表データや通知処理は既存APIとの互換性のためこのファイルに保持し、
/// 公開する画面状態はHomeStateMachineで一元管理します。
class HomeViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    
    // MARK: - UIの状態を管理するプロパティ
    
    // @Publishedを付けると、このプロパティの値が変更されたときに、自動的にUIが更新されます。
    @Published private(set) var selectedRoute: Route = .mansionToStation
    @Published private(set) var selectedOrigin: Stop = .mansion
    @Published private(set) var selectedDestination: Stop = .station
    @Published var searchType: SearchType = .departure          // 選択中の検索方法（出発 or 到着）
    @Published var searchTime: Date = Date()
    @Published var searchResults: [Bus] = []                    // 検索結果のバスリスト
    @Published var searchCriteriaDescription: String = "検索条件: まだ検索されていません" // 検索条件の説明テキスト
    @Published private(set) var searchResultDescription: String = "出発地・目的地と時刻を選んでください"
    @Published var holidayMessage: String? = nil                // 土日・祝日の場合のエラーメッセージ
    
    @Published var countdownMessages: [String: String] = [:]    // カウントダウン表示用
    @Published var trackedBusId: String? = nil                  // Live Activityで追跡中のバスID
    @Published var liveActivityError: String? = nil             // Live Activity関連のエラーメッセージ
    @Published private(set) var state: HomeState = .idle
    @Published private(set) var routeAvailabilityMessage: String? = nil
    @Published private(set) var availabilityReferenceDate: Date

    // MARK: - 内部でだけ使うプロパティ
    
    private var allTimetables: [Route: [Bus]] = [:] // 全ルートの時刻表データ
    private let publicHolidays = [                  // 祝日リスト
        "2025-01-01", "2025-01-13", "2025-02-11", "2025-02-23", "2025-03-20",
        "2025-04-29", "2025-05-03", "2025-05-04", "2025-05-05", "2025-07-21",
        "2025-08-11", "2025-09-15", "2025-09-23", "2025-10-13", "2025-11-03",
        "2025-11-23", "2025-12-23"
    ]
    private var timer: AnyCancellable?              // カウントダウン用のタイマー
    
    private var currentActivity: Activity<BusActivityAttributes>? = nil
    private var lastActivityRemainingMinutes: Int? = nil // Live Activityへの過剰な更新を防ぐためのキャッシュ
    private var stateMachine = HomeStateMachine()
    private let nowProvider: () -> Date
    
    private let locationManager = CLLocationManager() // 位置情報取得用マネージャー
    private let columbusCityLocation = CLLocation(latitude: 35.6589411, longitude: 140.0357708)
    private let kaihinMakuhariStationLocation = CLLocation(latitude: 35.6485608, longitude: 140.0416924)
    private let yokadoLocation = CLLocation(latitude: 35.6569440, longitude: 140.0510100)
    private let maxAutoRouteDistance: CLLocationDistance = 1_500
    private let maxLocationAge: TimeInterval = 120
    private let maxLocationAccuracy: CLLocationAccuracy = 500

    // MARK: - 選択肢を管理するための列挙型
    
    enum Stop: String, CaseIterable, Identifiable {
        case mansion = "コロンブスシティ"
        case station = "海浜幕張駅"
        case yokado = "ヨーカドー前"

        var id: Self { self }

        var systemName: String {
            switch self {
            case .mansion:
                return "building.2.fill"
            case .station:
                return "tram.fill"
            case .yokado:
                return "cart.fill"
            }
        }
    }

    enum Route: String, CaseIterable {
        case mansionToStation = "コロンブスシティ → 海浜幕張駅"
        case stationToMansion = "海浜幕張駅 → コロンブスシティ"
        case mansionToYokado = "コロンブスシティ → ヨーカドー前"
        case stationToYokado = "海浜幕張駅 → ヨーカドー前"
        case yokadoToMansion = "ヨーカドー前 → コロンブスシティ"

        var origin: Stop {
            switch self {
            case .mansionToStation, .mansionToYokado:
                return .mansion
            case .stationToMansion, .stationToYokado:
                return .station
            case .yokadoToMansion:
                return .yokado
            }
        }

        var destination: Stop {
            switch self {
            case .mansionToStation:
                return .station
            case .stationToMansion, .yokadoToMansion:
                return .mansion
            case .mansionToYokado, .stationToYokado:
                return .yokado
            }
        }

        var guidance: String {
            switch self {
            case .stationToMansion:
                return "便によってヨーカドー前を経由します"
            case .mansionToYokado:
                return "海浜幕張駅を経由してヨーカドー前へ向かいます"
            default:
                return "選択した出発地から目的地まで運行します"
            }
        }

        static func route(from origin: Stop, to destination: Stop) -> Route? {
            allCases.first { $0.origin == origin && $0.destination == destination }
        }
    }
    
    // 検索方法の種類を定義します。
    enum SearchType: String, CaseIterable {
        case departure = "出発する時刻から探す"
        case arrival = "到着したい時刻から探す"

        var shortTitle: String {
            switch self {
            case .departure:
                return "出発から"
            case .arrival:
                return "到着まで"
            }
        }

        var timeTitle: String {
            switch self {
            case .departure:
                return "この時刻以降に出発"
            case .arrival:
                return "この時刻までに到着"
            }
        }

        var explanation: String {
            switch self {
            case .departure:
                return "指定した時刻以降に出発する便を、早い順に表示します"
            case .arrival:
                return "指定した時刻までに目的地へ着く便を、到着時刻が近い順に表示します"
            }
        }
    }
    
    // MARK: - 初期化処理
    
    init(nowProvider: @escaping () -> Date = Date.init) {
        self.nowProvider = nowProvider
        self.availabilityReferenceDate = nowProvider()
        super.init()
        setupTimetables() // 時刻表データを準備する
        
        // 位置情報の設定
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        
        checkHoliday()    // 休日かどうかをチェックする
        refreshRouteAvailability(at: availabilityReferenceDate)
        startTimer()      // カウントダウン用のタイマーを開始する
        restoreLiveActivity()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func checkLocationAndSetOrigin() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= maxLocationAccuracy,
              abs(location.timestamp.timeIntervalSinceNow) <= maxLocationAge else {
            return
        }
        
        updateOriginForCurrentLocation(location)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("位置情報取得エラー: \(error.localizedDescription)")
    }
    
    private func stopForCurrentLocation(_ location: CLLocation) -> Stop? {
        let stopCandidates: [(distance: CLLocationDistance, stop: Stop)] = [
            (location.distance(from: columbusCityLocation), .mansion),
            (location.distance(from: kaihinMakuhariStationLocation), .station),
            (location.distance(from: yokadoLocation), .yokado)
        ]
        guard let nearest = stopCandidates.min(by: { $0.distance < $1.distance }) else { return nil }
        
        guard nearest.distance <= maxAutoRouteDistance else { return nil }
        
        return nearest.stop
    }

    /// 現在地に最も近い停留所から、次に利用できるルートを自動選択します。
    /// その停留所から本日これ以降の便がない場合は、自動選択せず案内を表示します。
    func updateOriginForCurrentLocation(_ location: CLLocation, at referenceDate: Date? = nil) {
        let referenceDate = referenceDate ?? now()
        refreshRouteAvailability(at: referenceDate)

        guard let origin = stopForCurrentLocation(location) else { return }
        guard let route = recommendedRoute(from: origin, at: referenceDate) else {
            routeAvailabilityMessage = origin == .yokado
                ? "ヨーカドー前から出発する本日の便は終了しました"
                : "現在地付近から出発する本日の便は終了しました"
            return
        }

        routeAvailabilityMessage = nil
        applyRoute(route)
    }

    private var remainingRoutes: [Route] {
        Route.allCases.filter { routeHasRemainingService($0, at: availabilityReferenceDate) }
    }

    func routeHasRemainingService(_ route: Route, at referenceDate: Date) -> Bool {
        nextDepartureDate(for: route, at: referenceDate) != nil
    }

    func recommendedRoute(from origin: Stop, at referenceDate: Date) -> Route? {
        Route.allCases
            .filter { $0.origin == origin }
            .compactMap { route -> (route: Route, departure: Date)? in
                guard let departure = nextDepartureDate(for: route, at: referenceDate) else { return nil }
                return (route, departure)
            }
            .min { lhs, rhs in lhs.departure < rhs.departure }?
            .route
    }

    private func nextDepartureDate(for route: Route, at referenceDate: Date) -> Date? {
        guard let timetable = allTimetables[route] else { return nil }
        return timetable.compactMap { bus in
            BusNotificationTimeCalculator.departureDateForCurrentServiceDay(
                for: bus.departure,
                from: referenceDate
            )
        }
        .filter { $0 > referenceDate }
        .min()
    }

    func refreshRouteAvailability(at referenceDate: Date? = nil) {
        let referenceDate = referenceDate ?? now()
        let previousServiceDay = serviceDayStart(for: availabilityReferenceDate)
        availabilityReferenceDate = referenceDate
        if previousServiceDay != serviceDayStart(for: referenceDate) {
            routeAvailabilityMessage = nil
        }

        guard !routeHasRemainingService(selectedRoute, at: referenceDate) else { return }

        if let replacement = remainingRoutes.first(where: { $0.origin == selectedOrigin }) {
            let removedYokado = selectedRoute.destination == .yokado
            applyRoute(replacement)
            if removedYokado {
                routeAvailabilityMessage = "ヨーカドー前へ向かう本日の便は終了したため、候補から外しました"
            }
        } else if selectedOrigin == .yokado {
            routeAvailabilityMessage = "ヨーカドー前から出発する本日の便は終了しました"
        } else if remainingRoutes.isEmpty {
            routeAvailabilityMessage = "本日のバスはすべて終了しました"
        }
    }

    private func serviceDayStart(for date: Date) -> Date? {
        let calendar = Calendar.current
        guard let boundary = calendar.date(
            bySettingHour: BusNotificationTimeCalculator.serviceDayBoundaryHour,
            minute: 0,
            second: 0,
            of: date
        ) else {
            return nil
        }
        return date >= boundary
            ? boundary
            : calendar.date(byAdding: .day, value: -1, to: boundary)
    }

    var availableOrigins: [Stop] {
        Stop.allCases.filter { origin in remainingRoutes.contains { $0.origin == origin } }
    }

    var availableDestinations: [Stop] {
        Stop.allCases.filter { destination in
            guard let route = Route.route(from: selectedOrigin, to: destination) else { return false }
            return remainingRoutes.contains(route)
        }
    }

    var canSwapEndpoints: Bool {
        guard let route = Route.route(from: selectedDestination, to: selectedOrigin) else { return false }
        return remainingRoutes.contains(route)
    }

    func selectOrigin(_ origin: Stop) {
        guard availableOrigins.contains(origin), origin != selectedOrigin else { return }
        selectedOrigin = origin

        if let route = Route.route(from: origin, to: selectedDestination),
           remainingRoutes.contains(route) {
            selectedRoute = route
        } else if let destination = availableDestinations.first,
                  let route = Route.route(from: origin, to: destination) {
            selectedDestination = destination
            selectedRoute = route
        }
        routeAvailabilityMessage = nil
    }

    func selectDestination(_ destination: Stop) {
        guard let route = Route.route(from: selectedOrigin, to: destination),
              remainingRoutes.contains(route) else { return }
        selectedDestination = destination
        selectedRoute = route
        routeAvailabilityMessage = nil
    }

    func swapEndpoints() {
        guard let route = Route.route(from: selectedDestination, to: selectedOrigin),
              remainingRoutes.contains(route) else { return }
        applyRoute(route)
        routeAvailabilityMessage = nil
    }

    private func applyRoute(_ route: Route) {
        selectedRoute = route
        selectedOrigin = route.origin
        selectedDestination = route.destination
    }
    
    // 時刻表データをプログラム内に直接定義します。
    private func setupTimetables() {
        let columbusCity = "コロンブスシティ"
        let station = "海浜幕張駅"
        let yokado = "ヨーカドー前"
        let shoppingNote = "お買い物便"
        let viaYokadoNote = "ヨーカドー経由"
        let viaStationNote = "海浜幕張駅経由"
        
        let shoppingRows = [
            (columbus: "9:30", station: "9:38", yokado: "9:46", columbusReturn: "9:53"),
            (columbus: "10:30", station: "10:38", yokado: "10:46", columbusReturn: "10:53"),
            (columbus: "11:30", station: "11:38", yokado: "11:46", columbusReturn: "11:53"),
            (columbus: "13:30", station: "13:38", yokado: "13:46", columbusReturn: "13:53"),
            (columbus: "14:30", station: "14:38", yokado: "14:46", columbusReturn: "14:53"),
            (columbus: "15:30", station: "15:38", yokado: "15:46", columbusReturn: "15:53"),
            (columbus: "16:30", station: "16:38", yokado: "16:46", columbusReturn: "16:53")
        ]
        
        func directBus(_ departure: String, _ arrival: String, from origin: String, to destination: String, note: String? = nil) -> Bus {
            Bus(departure: departure, arrival: arrival, originName: origin, destinationName: destination, note: note)
        }
        
        func shoppingBusToStation(_ row: (columbus: String, station: String, yokado: String, columbusReturn: String)) -> Bus {
            directBus(row.columbus, row.station, from: columbusCity, to: station, note: shoppingNote)
        }
        
        func shoppingBusStationToMansion(_ row: (columbus: String, station: String, yokado: String, columbusReturn: String)) -> Bus {
            Bus(stops: [
                BusStopTime(name: station, time: row.station),
                BusStopTime(name: yokado, time: row.yokado),
                BusStopTime(name: columbusCity, time: row.columbusReturn)
            ], note: viaYokadoNote)
        }
        
        allTimetables[.mansionToStation] = [
            directBus("6:03", "6:11", from: columbusCity, to: station),
            directBus("6:30", "6:38", from: columbusCity, to: station),
            directBus("6:40", "6:48", from: columbusCity, to: station),
            directBus("6:50", "6:58", from: columbusCity, to: station),
            directBus("7:00", "7:08", from: columbusCity, to: station),
            directBus("7:10", "7:18", from: columbusCity, to: station),
            directBus("7:20", "7:28", from: columbusCity, to: station),
            directBus("7:30", "7:38", from: columbusCity, to: station),
            directBus("7:40", "7:48", from: columbusCity, to: station),
            directBus("7:50", "7:58", from: columbusCity, to: station),
            directBus("8:00", "8:08", from: columbusCity, to: station),
            directBus("8:10", "8:18", from: columbusCity, to: station),
            directBus("8:20", "8:28", from: columbusCity, to: station),
            directBus("8:30", "8:38", from: columbusCity, to: station),
            directBus("8:40", "8:48", from: columbusCity, to: station),
            directBus("9:00", "9:08", from: columbusCity, to: station),
            shoppingBusToStation(shoppingRows[0]),
            directBus("10:00", "10:08", from: columbusCity, to: station),
            shoppingBusToStation(shoppingRows[1]),
            directBus("11:00", "11:08", from: columbusCity, to: station),
            shoppingBusToStation(shoppingRows[2]),
            directBus("13:00", "13:08", from: columbusCity, to: station),
            shoppingBusToStation(shoppingRows[3]),
            directBus("14:00", "14:08", from: columbusCity, to: station),
            shoppingBusToStation(shoppingRows[4]),
            directBus("15:00", "15:08", from: columbusCity, to: station),
            shoppingBusToStation(shoppingRows[5]),
            directBus("16:00", "16:08", from: columbusCity, to: station),
            shoppingBusToStation(shoppingRows[6]),
            directBus("17:04", "17:11", from: columbusCity, to: station),
            directBus("17:37", "17:44", from: columbusCity, to: station),
            directBus("18:02", "18:09", from: columbusCity, to: station),
            directBus("18:19", "18:26", from: columbusCity, to: station),
            directBus("18:37", "18:44", from: columbusCity, to: station),
            directBus("19:01", "19:08", from: columbusCity, to: station),
            directBus("19:20", "19:27", from: columbusCity, to: station),
            directBus("19:39", "19:46", from: columbusCity, to: station),
            directBus("19:59", "20:06", from: columbusCity, to: station),
            directBus("20:17", "20:24", from: columbusCity, to: station),
            directBus("20:51", "20:58", from: columbusCity, to: station),
            directBus("21:08", "21:15", from: columbusCity, to: station),
            directBus("21:55", "22:02", from: columbusCity, to: station),
            directBus("22:19", "22:26", from: columbusCity, to: station),
            directBus("22:37", "22:44", from: columbusCity, to: station),
            directBus("23:06", "23:13", from: columbusCity, to: station),
            directBus("23:38", "23:45", from: columbusCity, to: station),
            directBus("0:04", "0:11", from: columbusCity, to: station)
        ]
        
        allTimetables[.stationToMansion] = [
            directBus("6:11", "6:18", from: station, to: columbusCity),
            directBus("6:38", "6:45", from: station, to: columbusCity),
            directBus("6:48", "6:55", from: station, to: columbusCity),
            directBus("6:58", "7:05", from: station, to: columbusCity),
            directBus("7:08", "7:15", from: station, to: columbusCity),
            directBus("7:18", "7:25", from: station, to: columbusCity),
            directBus("7:28", "7:35", from: station, to: columbusCity),
            directBus("7:38", "7:45", from: station, to: columbusCity),
            directBus("7:48", "7:55", from: station, to: columbusCity),
            directBus("7:58", "8:05", from: station, to: columbusCity),
            directBus("8:08", "8:15", from: station, to: columbusCity),
            directBus("8:18", "8:25", from: station, to: columbusCity),
            directBus("8:28", "8:35", from: station, to: columbusCity),
            directBus("8:48", "8:55", from: station, to: columbusCity),
            shoppingBusStationToMansion(shoppingRows[0]),
            directBus("10:08", "10:16", from: station, to: columbusCity),
            shoppingBusStationToMansion(shoppingRows[1]),
            directBus("11:08", "11:16", from: station, to: columbusCity),
            shoppingBusStationToMansion(shoppingRows[2]),
            directBus("13:08", "13:16", from: station, to: columbusCity),
            shoppingBusStationToMansion(shoppingRows[3]),
            directBus("14:08", "14:16", from: station, to: columbusCity),
            shoppingBusStationToMansion(shoppingRows[4]),
            directBus("15:08", "15:16", from: station, to: columbusCity),
            shoppingBusStationToMansion(shoppingRows[5]),
            directBus("16:08", "16:16", from: station, to: columbusCity),
            shoppingBusStationToMansion(shoppingRows[6]),
            directBus("17:12", "17:19", from: station, to: columbusCity),
            directBus("17:46", "17:53", from: station, to: columbusCity),
            directBus("18:11", "18:18", from: station, to: columbusCity),
            directBus("18:28", "18:35", from: station, to: columbusCity),
            directBus("18:46", "18:53", from: station, to: columbusCity),
            directBus("19:10", "19:17", from: station, to: columbusCity),
            directBus("19:29", "19:36", from: station, to: columbusCity),
            directBus("19:48", "19:55", from: station, to: columbusCity),
            directBus("20:08", "20:15", from: station, to: columbusCity),
            directBus("20:26", "20:33", from: station, to: columbusCity),
            directBus("20:43", "20:50", from: station, to: columbusCity),
            directBus("21:00", "21:07", from: station, to: columbusCity),
            directBus("21:17", "21:24", from: station, to: columbusCity),
            directBus("21:39", "21:46", from: station, to: columbusCity),
            directBus("22:04", "22:11", from: station, to: columbusCity),
            directBus("22:28", "22:35", from: station, to: columbusCity),
            directBus("22:46", "22:53", from: station, to: columbusCity),
            directBus("23:15", "23:22", from: station, to: columbusCity),
            directBus("23:47", "23:54", from: station, to: columbusCity),
            directBus("0:13", "0:19", from: station, to: columbusCity)
        ]
        
        allTimetables[.mansionToYokado] = shoppingRows.map { row in
            Bus(stops: [
                BusStopTime(name: columbusCity, time: row.columbus),
                BusStopTime(name: station, time: row.station),
                BusStopTime(name: yokado, time: row.yokado)
            ], note: viaStationNote)
        }
        
        allTimetables[.stationToYokado] = shoppingRows.map { row in
            directBus(row.station, row.yokado, from: station, to: yokado, note: shoppingNote)
        }
        
        allTimetables[.yokadoToMansion] = shoppingRows.map { row in
            directBus(row.yokado, row.columbusReturn, from: yokado, to: columbusCity, note: shoppingNote)
        }
    }
    
    // 1秒ごとにカウントダウンを更新するためのタイマーを開始します。
    private func startTimer() {
        // [weak self] は、メモリリークを防ぐためのおまじないです。
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self else { return }
            let currentDate = self.now()
            if !Calendar.current.isDate(
                currentDate,
                equalTo: self.availabilityReferenceDate,
                toGranularity: .minute
            ) {
                self.refreshRouteAvailability(at: currentDate)
            }
            self.updateCountdown(at: currentDate)
        }
    }

    // MARK: - ロジック（処理）に関するメソッド群
    
    // 現在時刻をDate型で取得します。
    private func now() -> Date {
        return nowProvider()
    }
    
    // "HH:mm"形式の文字列を、日付情報を持たない純粋な「時刻」のDateオブジェクトに変換します。
    private func timeStringToDate(_ timeString: String) -> Date? {
        let calendar = Calendar.current
        let components = timeString.split(separator: ":").map { Int($0) ?? 0 }
        guard components.count == 2 else { return nil }
        return calendar.date(from: DateComponents(hour: components[0], minute: components[1]))
    }
    
    // Dateオブジェクトから、その日の0時からの経過分数を計算します。(例: 1:30 -> 90)
    private func timeToMinutes(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
    
    // 0時〜3時の深夜便を24時間〜27時間として扱うための関数です（1日の区切りを午前4時にする）
    private func shiftTime(_ minutes: Int) -> Int {
        return minutes < 4 * 60 ? minutes + 24 * 60 : minutes
    }

    // 現在選択している検索方法の時刻を現在時刻に合わせます。
    func setSearchToCurrentTime() {
        searchTime = now()
        performSearch()
    }

    /// アプリ復帰時に、過去になった検索時刻と検索結果を現在時刻へ更新します。
    /// ユーザーが未来の時刻を指定している場合は、その条件を維持します。
    func refreshForAppActivation() {
        let currentDate = now()
        refreshRouteAvailability(at: currentDate)
        if searchTime < currentDate {
            searchTime = currentDate
        }
        performSearch()
    }

    // 検索を実行するメインのメソッドです。
    func performSearch() {
        send(.searchStarted)
        checkHoliday() // まず休日かチェック
        // もし休日なら、運休メッセージを表示して処理を中断します。
        guard holidayMessage == nil else {
            searchResults = []
            searchCriteriaDescription = "検索条件: 本日は運休です。"
            searchResultDescription = holidayMessage ?? "本日は運休です"
            send(.serviceUnavailable(holidayMessage ?? "本日は運休です。"))
            return
        }
        
        // 選択されているルートの時刻表を取得します。
        guard let currentTimetable = allTimetables[selectedRoute] else {
            send(.failed("選択された路線の時刻表を読み込めませんでした。"))
            return
        }
        
        // 検索方法に応じて処理を分岐します。
        if searchType == .arrival {
            let results = findNextBusesByArrival(timetable: currentTimetable, arrivalTargetTime: searchTime)
            self.searchResults = results
        } else {
            let results = findNextBusesByDeparture(timetable: currentTimetable, departureRefTime: searchTime)
            self.searchResults = results
        }
        updateSearchCriteriaDescription() // 検索条件の表示を更新します。
        searchResultDescription = searchResults.isEmpty
            ? "条件に合う便がありません。時刻または目的地を変更してください"
            : "\(searchResults.count)便見つかりました。\(searchType.explanation)"
        send(.searchSucceeded(hasResults: !searchResults.isEmpty))
    }

    private func send(_ event: HomeEvent) {
        stateMachine.send(event)
        state = stateMachine.state
    }

    // 「出発時刻」でバスを探すロジックです。
    private func findNextBusesByDeparture(timetable: [Bus], departureRefTime: Date) -> [Bus] {
        let departureRefMinutes = shiftTime(timeToMinutes(departureRefTime))
        let upcomingBuses = timetable.compactMap { bus -> (bus: Bus, sortKey: Int)? in
            guard let busDepartureDate = timeStringToDate(bus.departure) else { return nil }
            let busDepartureMinutes = shiftTime(timeToMinutes(busDepartureDate))
            
            // 指定された出発時刻以降のバスのみを候補とします。
            if busDepartureMinutes >= departureRefMinutes {
                return (bus, busDepartureMinutes)
            }
            return nil
        }
        // 候補のバスを、出発が早い順に並び替え、最初の2件を取得します。
        return upcomingBuses.sorted { $0.sortKey < $1.sortKey }.map { $0.bus }.prefix(2).map{$0}
    }

    // 「到着希望時刻」でバスを探すロジックです。
    private func findNextBusesByArrival(timetable: [Bus], arrivalTargetTime: Date) -> [Bus] {
        let arrivalTargetMinutes = shiftTime(timeToMinutes(arrivalTargetTime))

        let candidateBuses = timetable.compactMap { bus -> (bus: Bus, arrival: Int)? in
            guard let busArrivalDate = timeStringToDate(bus.arrival) else { return nil }

            let busArrivalMinutes = shiftTime(timeToMinutes(busArrivalDate))
            
            // バスが指定時刻以前に到着するかどうかをチェックします。
            if busArrivalMinutes <= arrivalTargetMinutes {
                return (bus, busArrivalMinutes)
            }
            return nil
        }

        // 候補のバスを、到着が遅い順（＝希望時刻に近い順）に並び替え、最初の2件を取得します。
        return candidateBuses.sorted { $0.arrival > $1.arrival }.map { $0.bus }.prefix(2).map{$0}
    }
    
    // UIに表示する検索条件の説明文を更新します。
    func updateSearchCriteriaDescription() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: searchTime)
        if searchType == .arrival {
            searchCriteriaDescription = "\(selectedOrigin.rawValue) → \(selectedDestination.rawValue)｜\(time)までに到着"
        } else {
            searchCriteriaDescription = "\(selectedOrigin.rawValue) → \(selectedDestination.rawValue)｜\(time)以降に出発"
        }
    }

    func resultReason(for bus: Bus) -> String {
        let target = searchType == .arrival ? bus.arrival : bus.departure
        return searchType == .arrival
            ? "\(target)到着・希望時刻までに到着"
            : "\(target)出発・指定時刻以降"
    }
    
    // 今日が土日・祝日かどうかをチェックし、メッセージを設定します。
    private func checkHoliday() {
        let calendar = Calendar.current
        let today = now()
        let weekday = calendar.component(.weekday, from: today) // 1が日曜, 7が土曜
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayString = formatter.string(from: today)
        if weekday == 1 || weekday == 7 {
            self.holidayMessage = "本日は土日のため運休です。"
        } else if publicHolidays.contains(todayString) {
            self.holidayMessage = "本日は祝日のため運休です。"
        } else {
            self.holidayMessage = nil
        }
    }
    
    private func updateCountdown(at currentDate: Date? = nil) {
        // 検索結果がなければ何もしません。
        guard !searchResults.isEmpty else {
            countdownMessages = [:] // メッセージを空にする
            return
        }
        
        var newMessages: [String: String] = [:]
        let now = currentDate ?? self.now()
        
        for bus in searchResults {
            guard let departureDate = BusNotificationTimeCalculator.departureDateForCurrentServiceDay(
                for: bus.departure,
                from: now
            ) else { continue }
            let remainingSeconds = departureDate.timeIntervalSince(now)
            
            var currentRemainingMinutes = 0
            var isDeparted = false
            
            if remainingSeconds <= 0 {
                newMessages[bus.id] = "出発済み"
                isDeparted = true
            } else if remainingSeconds < 60 {
                newMessages[bus.id] = "まもなく出発"
                currentRemainingMinutes = 1
            } else {
                let remainingMinutes = Int(ceil(remainingSeconds / 60))
                let h = remainingMinutes / 60
                let m = remainingMinutes % 60
                if h > 0 {
                    newMessages[bus.id] = m == 0
                        ? String(format: "あと%d時間", h)
                        : String(format: "あと%d時間%d分", h, m)
                } else {
                    newMessages[bus.id] = String(format: "あと%d分", m)
                }
                currentRemainingMinutes = remainingMinutes
            }
            
            // もしこのバスがLive Activityで追跡されている場合、更新を行う
            if bus.id == trackedBusId {
                if isDeparted || currentRemainingMinutes != lastActivityRemainingMinutes {
                    updateLiveActivity(remainingMinutes: currentRemainingMinutes, isDeparted: isDeparted)
                }
            }
        }
        
        // 計算が終わった後、UIに反映させる
        self.countdownMessages = newMessages
    }
    
    // MARK: - Live Activity 関連のメソッド

    var isLiveActivityActive: Bool {
        trackedBusId != nil
    }

    private func restoreLiveActivity() {
        guard let activity = Activity<BusActivityAttributes>.activities.first else { return }
        currentActivity = activity
        trackedBusId = activity.attributes.busID
        lastActivityRemainingMinutes = activity.content.state.remainingMinutes
    }
    
    func startLiveActivity(for bus: Bus) {
        restoreLiveActivity()

        if let trackedBusId, trackedBusId != bus.id {
            liveActivityError = "別の便のLive Activityを表示中です。先に「設定した通知」から表示を終了してください。"
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            liveActivityError = "Live Activityを開始できません。iPhoneの設定で、BusTimeのLive Activityを許可してください。"
            return
        }

        if trackedBusId == bus.id {
            liveActivityError = "この便はすでにLive Activityで表示中です。"
            return
        }

        let now = Date()
        guard let departureDate = BusNotificationTimeCalculator.departureDateForCurrentServiceDay(
            for: bus.departure,
            from: now
        ) else {
            liveActivityError = "出発時刻を確認できないため、Live Activityを開始できません。"
            return
        }

        guard departureDate > now else {
            liveActivityError = "この便はすでに出発しています。別の便を選んでください。"
            return
        }

        let attributes = BusActivityAttributes(
            busID: bus.id,
            busDepartureTime: bus.departure,
            busArrivalTime: bus.arrival,
            originName: bus.originName,
            destinationName: bus.destinationName,
            departureDate: departureDate,
            routeName: selectedRoute.rawValue
        )

        let remaining = max(0, Int(ceil(departureDate.timeIntervalSince(now) / 60)))
        let contentState = BusActivityAttributes.ContentState(remainingMinutes: remaining, isDeparted: false)
        let activityContent = ActivityContent(state: contentState, staleDate: departureDate)

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: activityContent,
                pushType: nil
            )
            currentActivity = activity
            trackedBusId = bus.id
            lastActivityRemainingMinutes = remaining
            liveActivityError = nil
        } catch {
            liveActivityError = "Live Activityを開始できませんでした。iPhoneの設定を確認して、もう一度お試しください。"
        }
    }
    
    private func updateLiveActivity(remainingMinutes: Int, isDeparted: Bool) {
        self.lastActivityRemainingMinutes = remainingMinutes
        
        Task { @MainActor [weak self] in
            guard let self, let activity = self.currentActivity else { return }
            let contentState = BusActivityAttributes.ContentState(remainingMinutes: remainingMinutes, isDeparted: isDeparted)
            let activityContent = ActivityContent(state: contentState, staleDate: nil)
            
            await activity.update(activityContent)
            
            if isDeparted {
                // 出発済みになったら数分後に自動終了させる
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                await activity.end(activityContent, dismissalPolicy: .default)
                
                if self.trackedBusId == activity.attributes.busID {
                    self.trackedBusId = nil
                    self.currentActivity = nil
                    self.lastActivityRemainingMinutes = nil
                }
            }
        }
    }
    
    func endLiveActivity() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            for act in Activity<BusActivityAttributes>.activities {
                await act.end(nil, dismissalPolicy: .immediate)
            }
            self.currentActivity = nil
            self.trackedBusId = nil
            self.lastActivityRemainingMinutes = nil
        }
    }

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    
    // 現在選択されているルートの全時刻表を返します。
    var currentFullTimetable: [Bus] {
        return allTimetables[selectedRoute] ?? []
    }
}
