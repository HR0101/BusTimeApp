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
    @Published var serviceDay: ServiceDay = .today              // 検索の対象にする運行日
    @Published var searchType: SearchType = .departure          // 選択中の検索方法（出発 or 到着）
    @Published var searchTime: Date = Date()
    @Published var searchResults: [Bus] = []                    // 検索結果のバスリスト
    @Published var searchCriteriaDescription: String = L10n.Search.criteriaInitial // 検索条件の説明テキスト
    @Published private(set) var searchResultDescription: String = L10n.Search.resultInitial
    @Published var holidayMessage: String? = nil                // 土日・祝日の場合のエラーメッセージ
    
    @Published var countdownMessages: [String: String] = [:]    // カウントダウン表示用
    @Published private(set) var remainingMinutes: [String: Int] = [:] // 残り時間の数値表現（大きな数字での表示用）
    @Published var trackedBusId: String? = nil                  // Live Activityで追跡中のバスID
    @Published var liveActivityError: String? = nil             // Live Activity関連のエラーメッセージ
    @Published private(set) var state: HomeState = .idle
    @Published private(set) var routeAvailabilityMessage: String? = nil
    @Published private(set) var availabilityReferenceDate: Date
    /// 経路がどうやって決まったかです。画面に理由を出すために持ちます。
    @Published private(set) var routeDecision: RouteDecision = .timeOfDay
    /// 検索結果が次の運行日の便かどうかです。
    /// 深夜など、その運行日の便が終わったあとに翌朝の便を出している状態を表します。
    @Published private(set) var showsNextServiceDay = false

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
    private let maxLocationAge: TimeInterval = 120
    private let maxLocationAccuracy: CLLocationAccuracy = 500

    /// 出かける向きとみなす時間帯の終わりです。
    /// 午前は自宅から出る便、正午以降は自宅へ戻る便を初期値にします。
    private static let outboundEndHour = 12
    /// 前回使った、自宅ではない側の停留所を覚えておくキーです。
    private static let preferredPartnerStopKey = "preferredPartnerStop"
    /// 自宅にあたる停留所です。向きの判定はこの停留所を基準にします。
    private static let homeStop: Stop = .mansion

    private let defaults: UserDefaults
    /// 利用者が自分で経路を選んだかどうかです。
    /// 選んだあとは、位置情報で勝手に上書きしないようにします。
    private var hasManualRouteSelection = false

    // MARK: - 選択肢を管理するための列挙型
    
    /// 停留所と経路は、ウィジェットとも共有するため `BusSchedule` 側に置いています。
    /// 画面や既存のコードからは、これまでどおりの名前で参照できるようにします。
    typealias Stop = BusStop
    typealias Route = BusRoute

    /// 検索の対象にする運行日です。
    ///
    /// このアプリのダイヤは平日の1本だけなので、どの平日を選んでも時刻は同じです。
    /// 意味のある違いは「今日か、そうでないか」だけなので、2つに絞っています。
    enum ServiceDay: String, CaseIterable, Identifiable {
        case today = "今日"
        case otherWeekday = "他の平日"

        var id: Self { self }

        /// 画面に出す名前です。
        /// rawValueは保存や比較に使う識別子なので、日本語のまま固定しておきます。
        var displayName: String {
            switch self {
            case .today:
                return L10n.When.serviceDayTodayName
            case .otherWeekday:
                return L10n.When.serviceDayOtherWeekdayName
            }
        }
    }

    /// 表示中の経路がどうやって決まったかです。
    /// 利用者が「なぜこの経路なのか」を判断できるように、理由を画面へ出します。
    enum RouteDecision {
        /// 現在地から自動で決まりました。
        case automatic
        /// 位置情報が使えないため、時間帯と前回の設定から決まりました。
        case timeOfDay
        /// 利用者が自分で選びました。
        case manual

        var explanation: String {
            switch self {
            case .automatic:
                return L10n.Route.decisionAutomatic
            case .timeOfDay:
                return L10n.Route.decisionTimeOfDay
            case .manual:
                return L10n.Route.decisionManual
            }
        }

        var systemName: String {
            switch self {
            case .automatic:
                return "location.fill"
            case .timeOfDay:
                return "clock.fill"
            case .manual:
                return "hand.tap.fill"
            }
        }
    }

    // 検索方法の種類を定義します。
    enum SearchType: String, CaseIterable {
        case departure = "出発する時刻から探す"
        case arrival = "到着したい時刻から探す"

        var shortTitle: String {
            switch self {
            case .departure:
                return L10n.When.searchTypeDeparture
            case .arrival:
                return L10n.When.searchTypeArrival
            }
        }

        var timeTitle: String {
            switch self {
            case .departure:
                return L10n.When.departureTimeTitle
            case .arrival:
                return L10n.When.arrivalTimeTitle
            }
        }

        var explanation: String {
            switch self {
            case .departure:
                return L10n.When.departureExplanation
            case .arrival:
                return L10n.When.arrivalExplanation
            }
        }
    }
    
    // MARK: - 初期化処理
    
    init(
        nowProvider: @escaping () -> Date = Date.init,
        defaults: UserDefaults = .standard
    ) {
        self.nowProvider = nowProvider
        self.defaults = defaults
        self.availabilityReferenceDate = nowProvider()
        super.init()
        setupTimetables() // 時刻表データを準備する

        // 手動で選んだ経路はアプリを開き直すと解除されます。
        // ウィジェットにだけ古い選択が残らないよう、同じところで消しておきます。
        SharedAppData.manualRoute = nil

        // 位置情報の設定
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        checkHoliday()    // 休日かどうかをチェックする
        refreshRouteAvailability(at: availabilityReferenceDate)
        // 位置情報が届くまでの間も答えが出せるよう、先に時間帯から経路を置きます。
        applyRouteFromTimeOfDay(at: availabilityReferenceDate)
        // 最初の描画で完成した内容を出します。表示してから結果を差し込むと、
        // 画面の高さが伸びてスクロール位置がずれてしまうためです。
        searchTime = availabilityReferenceDate
        performSearch()
        startTimer()      // カウントダウン用のタイマーを開始する
        restoreLiveActivity()
    }
    
    // MARK: - CLLocationManagerDelegate
    
    /// 現在地から経路を決め直します。
    /// 位置情報が使えないときは、時間帯と前回の行き先から決めます。
    func checkLocationAndSetOrigin() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            applyRouteFromTimeOfDay()
        @unknown default:
            applyRouteFromTimeOfDay()
        }
    }

    /// 利用者の操作で現在地に合わせ直します。
    /// 手動で選んだ状態を解除してから、位置情報を取り直します。
    func useCurrentLocationForRoute() {
        hasManualRouteSelection = false
        // ウィジェット側も現在地から決め直すようにします。
        SharedAppData.manualRoute = nil
        checkLocationAndSetOrigin()
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
        // 取れなかった場合でも経路が決まるよう、時間帯から選び直します。
        applyRouteFromTimeOfDay()
    }
    
    private func stopForCurrentLocation(_ location: CLLocation) -> Stop? {
        BusSchedule.nearestStop(to: location)
    }

    /// 現在地に最も近い停留所から、次に利用できるルートを自動選択します。
    /// その停留所から本日これ以降の便がない場合は、自動選択せず案内を表示します。
    func updateOriginForCurrentLocation(_ location: CLLocation, at referenceDate: Date? = nil) {
        // 自分で選んだ経路は、位置情報で上書きしません。
        guard !hasManualRouteSelection else { return }

        let referenceDate = referenceDate ?? now()
        refreshRouteAvailability(at: referenceDate)

        guard let origin = stopForCurrentLocation(location) else {
            // 停留所から離れた場所では、時間帯から決めます。
            applyRouteFromTimeOfDay(at: referenceDate)
            return
        }
        guard let route = recommendedRoute(from: origin, at: referenceDate) else {
            if shouldLimitToRemainingRoutes {
                // 本日はまだ便があるのに、この停留所から出る便だけが終わっている場合です。
                // 次に乗れる便へ寄せたうえで、理由を伝えます。
                applyRouteFromTimeOfDay(at: referenceDate)
                routeAvailabilityMessage = origin == .yokado
                    ? L10n.Route.yokadoDepartureEnded
                    : L10n.Route.nearbyDepartureEnded
                return
            }

            // 運休日や本日の運行終了後は、現在地の停留所を活かした経路を組み立てます。
            guard let fallbackRoute = routeFromCurrentStop(origin) else { return }
            routeAvailabilityMessage = nil
            routeDecision = .automatic
            applyRoute(fallbackRoute)
            return
        }

        routeAvailabilityMessage = nil
        routeDecision = .automatic
        applyRoute(route)
    }

    // MARK: - 時間帯からの経路決定

    /// 位置情報が使えないときに、時間帯と前回の行き先から経路を決めます。
    func applyRouteFromTimeOfDay(at referenceDate: Date? = nil) {
        guard !hasManualRouteSelection else { return }

        let referenceDate = referenceDate ?? now()
        refreshRouteAvailability(at: referenceDate)

        guard let route = routeFromTimeOfDay(at: referenceDate) else { return }

        routeAvailabilityMessage = nil
        routeDecision = .timeOfDay
        applyRoute(route)
    }

    /// 時間帯で向きを決め、前回使った行き先を引き継いで経路を組み立てます。
    ///
    /// 朝と夕方では乗る向きが逆になるため、前回の経路をそのまま復元すると
    /// 半分の場面で外れます。そこで向きは時刻から決め、
    /// 「駅とヨーカドーのどちらを使うか」だけを前回から引き継ぎます。
    func routeFromTimeOfDay(at referenceDate: Date) -> Route? {
        let hour = Calendar.current.component(.hour, from: referenceDate)
        let isOutbound = hour < Self.outboundEndHour
        let partner = preferredPartnerStop

        let preferred = isOutbound
            ? Route.route(from: Self.homeStop, to: partner)
            : Route.route(from: partner, to: Self.homeStop)

        if let preferred, routeHasRemainingService(preferred, at: referenceDate) {
            return preferred
        }

        // 同じ向きのまま、本日の残便がある経路を探します。
        let sameDirection = Route.allCases.filter {
            isOutbound ? $0.origin == Self.homeStop : $0.destination == Self.homeStop
        }
        if let fallback = earliestRoute(among: sameDirection, at: referenceDate) {
            return fallback
        }

        // 向きを問わず、次に出る便のある経路へ寄せます。
        return earliestRoute(among: Route.allCases, at: referenceDate) ?? preferred
    }

    /// 本日の運行に関わらず、その停留所から出る経路を1つ選びます。
    /// 前回の行き先、次に自宅方面、の順に優先します。
    private func routeFromCurrentStop(_ origin: Stop) -> Route? {
        let candidates = Route.allCases.filter { $0.origin == origin }
        return candidates.first { $0.destination == preferredPartnerStop }
            ?? candidates.first { $0.destination == Self.homeStop }
            ?? candidates.first
    }

    /// 前回使った、自宅ではない側の停留所です。行き先の好みとして覚えておきます。
    private var preferredPartnerStop: Stop {
        guard let rawValue = defaults.string(forKey: Self.preferredPartnerStopKey),
              let stop = Stop(rawValue: rawValue),
              stop != Self.homeStop else {
            return .station
        }
        return stop
    }

    /// 経路から行き先の好みを取り出して保存します。
    /// ウィジェットも同じ行き先を使うので、共有の保存領域にも書きます。
    private func rememberPartnerStop(for route: Route) {
        let partner = route.origin == Self.homeStop ? route.destination : route.origin
        guard partner != Self.homeStop else { return }
        defaults.set(partner.rawValue, forKey: Self.preferredPartnerStopKey)
        SharedAppData.preferredPartnerStop = partner
    }

    /// 与えられた経路のうち、次の発車が最も早いものを返します。
    private func earliestRoute(among routes: [Route], at referenceDate: Date) -> Route? {
        routes
            .compactMap { route -> (route: Route, departure: Date)? in
                guard let departure = nextDepartureDate(for: route, at: referenceDate) else { return nil }
                return (route, departure)
            }
            .min { $0.departure < $1.departure }?
            .route
    }

    private var remainingRoutes: [Route] {
        Route.allCases.filter { routeHasRemainingService($0, at: availabilityReferenceDate) }
    }

    func routeHasRemainingService(_ route: Route, at referenceDate: Date) -> Bool {
        nextDepartureDate(for: route, at: referenceDate) != nil
    }

    func recommendedRoute(from origin: Stop, at referenceDate: Date) -> Route? {
        earliestRoute(among: Route.allCases.filter { $0.origin == origin }, at: referenceDate)
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

        // 「本日の残り便」に意味がない状況では、経路の差し替えも案内も行いません。
        // 運休であることは別のカードで伝えています。
        guard isRealtimeContext else {
            routeAvailabilityMessage = nil
            return
        }

        guard !routeHasRemainingService(selectedRoute, at: referenceDate) else { return }

        if let replacement = remainingRoutes.first(where: { $0.origin == selectedOrigin }) {
            let removedYokado = selectedRoute.destination == .yokado
            applyRoute(replacement)
            if removedYokado {
                routeAvailabilityMessage = L10n.Route.yokadoRemoved
            }
        } else if selectedOrigin == .yokado {
            routeAvailabilityMessage = L10n.Route.yokadoDepartureEnded
        } else if remainingRoutes.isEmpty {
            routeAvailabilityMessage = L10n.Route.allServicesEnded
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

    /// 選択肢を「本日の残り便」で絞ってよい状況かどうかです。
    ///
    /// 本日まだ乗れる便があるときは、終わった行き先を隠すほうが親切です。
    /// けれども運休日や、本日の運行がすべて終わったあとに同じ絞り込みを続けると、
    /// 平日ダイヤを調べたいだけの人が行き先を選べなくなってしまいます。
    private var shouldLimitToRemainingRoutes: Bool {
        isRealtimeContext && !remainingRoutes.isEmpty
    }

    /// 出発地・目的地の候補として出してよい経路です。
    private var selectableRoutes: [Route] {
        shouldLimitToRemainingRoutes ? remainingRoutes : Route.allCases
    }

    var availableOrigins: [Stop] {
        Stop.allCases.filter { origin in selectableRoutes.contains { $0.origin == origin } }
    }

    var availableDestinations: [Stop] {
        Stop.allCases.filter { destination in
            guard let route = Route.route(from: selectedOrigin, to: destination) else { return false }
            return selectableRoutes.contains(route)
        }
    }

    var canSwapEndpoints: Bool {
        guard let route = Route.route(from: selectedDestination, to: selectedOrigin) else { return false }
        return selectableRoutes.contains(route)
    }

    func selectOrigin(_ origin: Stop) {
        guard availableOrigins.contains(origin), origin != selectedOrigin else { return }
        selectedOrigin = origin

        if let route = Route.route(from: origin, to: selectedDestination),
           selectableRoutes.contains(route) {
            selectedRoute = route
        } else if let destination = availableDestinations.first,
                  let route = Route.route(from: origin, to: destination) {
            selectedDestination = destination
            selectedRoute = route
        }
        routeAvailabilityMessage = nil
        markManualRouteSelection()
    }

    func selectDestination(_ destination: Stop) {
        guard let route = Route.route(from: selectedOrigin, to: destination),
              selectableRoutes.contains(route) else { return }
        selectedDestination = destination
        selectedRoute = route
        routeAvailabilityMessage = nil
        markManualRouteSelection()
    }

    func swapEndpoints() {
        guard let route = Route.route(from: selectedDestination, to: selectedOrigin),
              selectableRoutes.contains(route) else { return }
        applyRoute(route)
        routeAvailabilityMessage = nil
        markManualRouteSelection()
    }

    /// ウィジェットから開かれたときに、その経路へ合わせます。
    ///
    /// ウィジェットで見ていた便をそのまま確かめられるようにします。
    /// 自分で選んだのと同じ扱いにするので、位置情報では上書きしません。
    func selectRouteFromWidget(_ route: Route) {
        guard selectableRoutes.contains(route) || routeHasRemainingService(route, at: now())
        else {
            // 本日その経路の便がもうない場合でも、経路自体は合わせます。
            // ウィジェットが出していた内容と画面が食い違うほうが分かりにくいためです。
            applyRoute(route)
            markManualRouteSelection()
            performSearch()
            return
        }

        applyRoute(route)
        routeAvailabilityMessage = nil
        markManualRouteSelection()
        performSearch()
    }

    /// 利用者が自分で経路を選んだことを記録します。
    /// 以降は位置情報で上書きせず、行き先の好みを次回に引き継ぎます。
    private func markManualRouteSelection() {
        hasManualRouteSelection = true
        routeDecision = .manual
        rememberPartnerStop(for: selectedRoute)
        // 自分で選んだ経路は、ウィジェットでも同じものを出します。
        SharedAppData.manualRoute = selectedRoute
    }

    private func applyRoute(_ route: Route) {
        selectedRoute = route
        selectedOrigin = route.origin
        selectedDestination = route.destination
    }
    
    // 時刻表はウィジェットとも共有するため、`BusSchedule` から受け取ります。
    private func setupTimetables() {
        allTimetables = BusSchedule.timetables
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

    /// 本日が運休かどうかです。運休日でも時刻は調べられますが、
    /// 残り時間や通知など「今日その便に乗る」ための機能は止めます。
    var isServiceSuspended: Bool {
        holidayMessage != nil
    }

    // 検索を実行するメインのメソッドです。
    func performSearch() {
        send(.searchStarted)
        // 運休かどうかを控えておきます。運休日でも平日の時刻を調べられるよう、
        // 検索そのものは止めずに続けます。
        checkHoliday()

        // 選択されているルートの時刻表を取得します。
        guard let currentTimetable = allTimetables[selectedRoute] else {
            send(.failed(L10n.Search.timetableLoadFailed))
            return
        }
        
        // 検索方法に応じて処理を分岐します。
        if searchType == .arrival {
            let results = findNextBusesByArrival(timetable: currentTimetable, arrivalTargetTime: searchTime)
            self.searchResults = results
            self.showsNextServiceDay = false
        } else {
            let found = findNextBusesByDeparture(
                timetable: currentTimetable,
                departureRefTime: departureSearchReference
            )
            self.searchResults = found.buses
            self.showsNextServiceDay = found.isNextServiceDay || shouldSkipToTodaysService
        }
        updateSearchCriteriaDescription() // 検索条件の表示を更新します。
        if searchResults.isEmpty {
            searchResultDescription = L10n.Search.noResults
        } else if !selectedDayHasService {
            searchResultDescription = L10n.Search.resultCountSuspended(searchResults.count)
        } else {
            searchResultDescription = L10n.Search.resultCount(searchResults.count, searchType.explanation)
        }
        send(.searchSucceeded(hasResults: !searchResults.isEmpty))
    }

    private func send(_ event: HomeEvent) {
        stateMachine.send(event)
        state = stateMachine.state
    }

    // 「出発時刻」でバスを探すロジックです。
    /// 「出発時刻」でバスを探すロジックです。
    ///
    /// 指定時刻より後の便がその運行日に残っていない場合は、次の運行日の始発から並べます。
    /// 運行日は午前4時区切りのため、たとえば深夜3時は前日の運行日に属します。
    /// そのまま打ち切ると「便がありません」となりますが、
    /// 利用者にとっての次のバスは同じ朝の始発なので、折り返して案内します。
    private func findNextBusesByDeparture(
        timetable: [Bus],
        departureRefTime: Date
    ) -> (buses: [Bus], isNextServiceDay: Bool) {
        let departureRefMinutes = shiftTime(timeToMinutes(departureRefTime))
        let sortedBuses = timetable.compactMap { bus -> (bus: Bus, sortKey: Int)? in
            guard let busDepartureDate = timeStringToDate(bus.departure) else { return nil }
            return (bus, shiftTime(timeToMinutes(busDepartureDate)))
        }
        .sorted { $0.sortKey < $1.sortKey }

        let upcomingBuses = sortedBuses.filter { $0.sortKey >= departureRefMinutes }
        let isNextServiceDay = upcomingBuses.isEmpty && !sortedBuses.isEmpty
        let candidates = isNextServiceDay ? sortedBuses : upcomingBuses

        return (
            candidates.map { $0.bus }.prefix(Self.maximumSearchResults).map { $0 },
            isNextServiceDay
        )
    }

    /// 画面に並べる検索結果の最大件数です。
    private static let maximumSearchResults = 2

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
        // 書式を固定すると、12時間制の地域でも24時間表記のままになります。
        // 端末の言語と時刻表示の設定に従わせます。
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let time = formatter.string(from: searchTime)
        if searchType == .arrival {
            searchCriteriaDescription = L10n.Search.criteriaArrival(
                selectedOrigin.rawValue,
                selectedDestination.rawValue,
                time
            )
        } else {
            searchCriteriaDescription = L10n.Search.criteriaDeparture(
                selectedOrigin.rawValue,
                selectedDestination.rawValue,
                time
            )
        }
    }

    func resultReason(for bus: Bus) -> String {
        let target = searchType == .arrival ? bus.arrival : bus.departure
        return searchType == .arrival
            ? L10n.Search.reasonArrival(target)
            : L10n.Search.reasonDeparture(target)
    }
    
    /// その日が運休になる理由です。運行日であればnilを返します。
    private func suspensionReason(for date: Date) -> String? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // 1が日曜, 7が土曜
        if weekday == 1 || weekday == 7 {
            return L10n.Holiday.weekend
        }

        // こちらは画面に出す文字ではなく、祝日の一覧と突き合わせる鍵です。
        // 地域の暦に左右されないよう、書式と暦を固定します。
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        if publicHolidays.contains(formatter.string(from: date)) {
            return L10n.Holiday.publicHoliday
        }
        return nil
    }

    /// 深夜0〜3時台に、暦の上での今日の始発から探し直すべきかどうかです。
    ///
    /// 運行日は午前4時区切りなので、月曜の0時台は日曜の運行日に属します。
    /// 日曜は運休なので、その運行日の便を出すと「走らない便」を案内してしまいます。
    /// 暦の上での今日に運行があるなら、その日の始発から探すのが利用者の期待に合います。
    private var shouldSkipToTodaysService: Bool {
        let currentDate = now()
        guard let serviceDay = BusNotificationTimeCalculator.serviceDayStart(for: currentDate) else {
            return false
        }
        return !BusServiceCalendar.isServiceDay(serviceDay)
            && BusServiceCalendar.isServiceDay(currentDate)
    }

    // 運休かどうかをチェックし、メッセージを設定します。
    private func checkHoliday() {
        // 前の運行日が運休でも、今日の始発から案内できる場合は運休扱いにしません。
        guard !shouldSkipToTodaysService else {
            holidayMessage = nil
            return
        }

        // 暦の日付ではなく運行日で判定します。
        // 土曜の0時台はまだ金曜の運行日なので、深夜便は走ります。
        let referenceDate = BusNotificationTimeCalculator.serviceDayStart(for: now()) ?? now()
        if let reason = suspensionReason(for: referenceDate) {
            holidayMessage = L10n.Holiday.message(reason)
        } else {
            holidayMessage = nil
        }
    }

    /// 検索の基準にする時刻です。
    /// 深夜に前の運行日が運休だった場合は、今日の始発（午前4時）から探します。
    private var departureSearchReference: Date {
        guard shouldSkipToTodaysService,
              let todaysServiceStart = Calendar.current.date(
                bySettingHour: BusNotificationTimeCalculator.serviceDayBoundaryHour,
                minute: 0,
                second: 0,
                of: now()
              ) else {
            return searchTime
        }
        return todaysServiceStart
    }

    // MARK: - 運行日

    /// 選んでいる運行日の日付です。
    /// 「他の平日」はどの平日でも時刻が同じなので、代表として次の運行日を使います。
    var selectedServiceDate: Date {
        switch serviceDay {
        case .today:
            return now()
        case .otherWeekday:
            return nextServiceDate()
        }
    }

    /// 明日から順に見て、最初に見つかった運行日を返します。
    private func nextServiceDate() -> Date {
        let calendar = Calendar.current
        let today = now()

        for offset in 1...Self.maximumDaysToFindNextServiceDay {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: today) else {
                continue
            }
            if suspensionReason(for: candidate) == nil {
                return candidate
            }
        }
        return today
    }

    /// 次の運行日を探すときに、何日先まで見るかです。
    /// 連休が続いても必ず見つかる長さにしています。
    private static let maximumDaysToFindNextServiceDay = 14

    /// 選んでいる運行日に運行があるかどうかです。
    var selectedDayHasService: Bool {
        suspensionReason(for: selectedServiceDate) == nil
    }

    /// 今日の便を見ているかどうかです。
    var isViewingToday: Bool {
        serviceDay == .today
    }

    /// 残り時間や通知など「今まさに乗る」ための表示を出してよい状況かどうかです。
    /// 先の日を見ているときや運休日には、これらは意味を持ちません。
    var isRealtimeContext: Bool {
        isViewingToday && selectedDayHasService
    }

    /// 選んでいる運行日が運休のときの案内です。
    /// 「他の平日」は必ず運行日なので、案内が出るのは今日を見ているときだけです。
    var serviceDayNotice: String? {
        guard let reason = suspensionReason(for: selectedServiceDate) else { return nil }
        return L10n.Holiday.serviceDayNotice(reason)
    }

    /// 結果カードに続けて並べる便の見出しです。
    ///
    /// 出発時間で探すと2件目は後の便になりますが、
    /// 到着時間で探すと「間に合う中で最も遅い便」から並ぶため、2件目は前の便になります。
    /// 並び順が逆になるので、見出しも合わせて変えます。
    var followingSectionTitle: String {
        searchType == .arrival ? L10n.Result.earlierTitle : L10n.Result.followingTitle
    }

    /// 結果カードの見出しです。
    var resultSectionTitle: String {
        isRealtimeContext ? L10n.Result.nextBus : L10n.Result.weekdayService
    }

    /// 通知を設定できない理由です。設定できるときはnilを返します。
    var notificationUnavailableReason: String? {
        if !selectedDayHasService {
            return L10n.Notify.unavailableSuspended
        }
        if !isViewingToday {
            return L10n.Notify.unavailableOtherDay
        }
        return nil
    }
    
    /// 残り時間を数えるときの出発日時です。
    ///
    /// 通常はその運行日の出発時刻を使います。出発済みの便を翌日へ繰り越さず、
    /// 「出発済み」と示すためです。
    /// 翌朝の便を出しているときだけ、実際に次に走る日時を使います。
    private func departureDateForCountdown(of bus: Bus, from now: Date) -> Date? {
        if showsNextServiceDay {
            return BusNotificationTimeCalculator.nextDepartureDate(for: bus.departure, from: now)
        }
        return BusNotificationTimeCalculator.departureDateForCurrentServiceDay(
            for: bus.departure,
            from: now
        )
    }

    /// 残り時間の数値表現で「出発済み」を表す値です。
    static let departedMinutesValue = -1
    /// 残り時間の数値表現で「まもなく出発」を表す値です。
    static let imminentMinutesValue = 0

    private func updateCountdown(at currentDate: Date? = nil) {
        // 今日の運行を見ているときだけ残り時間を出します。
        // 運休日や先の日の便に「あと◯分」と出すと、走らない便を待たせてしまいます。
        guard isRealtimeContext else {
            countdownMessages = [:]
            remainingMinutes = [:]
            return
        }

        // 検索結果がなければ何もしません。
        guard !searchResults.isEmpty else {
            countdownMessages = [:] // メッセージを空にする
            remainingMinutes = [:]
            return
        }

        var newMessages: [String: String] = [:]
        var newRemainingMinutes: [String: Int] = [:]
        let now = currentDate ?? self.now()

        for bus in searchResults {
            guard let departureDate = departureDateForCountdown(of: bus, from: now) else { continue }
            let remainingSeconds = departureDate.timeIntervalSince(now)
            
            var currentRemainingMinutes = 0
            var isDeparted = false
            
            if remainingSeconds <= 0 {
                newMessages[bus.id] = L10n.Countdown.departed
                newRemainingMinutes[bus.id] = Self.departedMinutesValue
                isDeparted = true
            } else if remainingSeconds < 60 {
                newMessages[bus.id] = L10n.Countdown.leavingSoon
                newRemainingMinutes[bus.id] = Self.imminentMinutesValue
                currentRemainingMinutes = 1
            } else {
                let minutesUntilDeparture = Int(ceil(remainingSeconds / 60))
                let h = minutesUntilDeparture / 60
                let m = minutesUntilDeparture % 60
                if h > 0 {
                    newMessages[bus.id] = m == 0
                        ? L10n.Countdown.hours(h)
                        : L10n.Countdown.hoursMinutes(h, m)
                } else {
                    newMessages[bus.id] = L10n.Countdown.minutes(m)
                }
                newRemainingMinutes[bus.id] = minutesUntilDeparture
                currentRemainingMinutes = minutesUntilDeparture
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
        self.remainingMinutes = newRemainingMinutes
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
            liveActivityError = L10n.LiveActivity.otherBusShowing
            return
        }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            liveActivityError = L10n.LiveActivity.notPermitted
            return
        }

        if trackedBusId == bus.id {
            liveActivityError = L10n.LiveActivity.alreadyShowing
            return
        }

        let now = Date()
        guard let departureDate = BusNotificationTimeCalculator.departureDateForCurrentServiceDay(
            for: bus.departure,
            from: now
        ) else {
            liveActivityError = L10n.LiveActivity.noDepartureTime
            return
        }

        guard departureDate > now else {
            liveActivityError = L10n.LiveActivity.alreadyDeparted
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
            liveActivityError = L10n.LiveActivity.startFailed
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
