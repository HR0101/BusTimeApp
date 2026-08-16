import Foundation

/// 画面に出る文言をまとめた入り口です。
///
/// 実際の文字は Localization/Localizable.xcstrings に置き、ここには意味の名前だけを残します。
/// 表示される言語は端末の設定に従います。日本語・英語・簡体字中国語を用意しています。
/// 停留所名などの固有名詞は現地の案内と一致させるため、日本語のままにしています。
///
/// このファイルはウィジェット拡張とも共有します。
/// String(localized:) は各バンドルのカタログを見るため、両方の成果物にカタログを含めています。
///
/// このファイルは Scripts/generate_l10n.py が作ります。直接編集しないでください。
public enum L10n {
  public enum Common {
    /// 閉じる
    public static var close: String { String(localized: "common.close") }
    /// 完了
    public static var done: String { String(localized: "common.done") }
  }

  public enum Tab {
    /// ホーム
    public static var home: String { String(localized: "tab.home") }
    /// 時刻表
    public static var timetable: String { String(localized: "tab.timetable") }
    /// ホームタブ
    public static var homeAccessibility: String { String(localized: "tab.homeAccessibility") }
    /// 時刻表タブ
    public static var timetableAccessibility: String { String(localized: "tab.timetableAccessibility") }
  }

  public enum Home {
    /// 設定した通知を確認
    public static var notificationsButton: String { String(localized: "home.notificationsButton") }
    /// 設定を開く
    public static var settingsButton: String { String(localized: "home.settingsButton") }
    /// 使い方を開く
    public static var tutorialButton: String { String(localized: "home.tutorialButton") }
    /// コロンブスシティ
    public static var brandName: String { String(localized: "home.brandName") }
  }

  public enum Route {
    /// 出発地
    public static var originLabel: String { String(localized: "route.originLabel") }
    /// 目的地
    public static var destinationLabel: String { String(localized: "route.destinationLabel") }
    /// 変更するには二回タップします
    public static var menuHint: String { String(localized: "route.menuHint") }
    /// 出発地と目的地を入れ替える
    public static var swapLabel: String { String(localized: "route.swapLabel") }
    /// 入れ替えます
    public static var swapHintAvailable: String { String(localized: "route.swapHintAvailable") }
    /// 逆向きの便は本日終了しているため使えません
    public static var swapHintUnavailable: String { String(localized: "route.swapHintUnavailable") }
    /// 現在地に合わせる
    public static var useCurrentLocation: String { String(localized: "route.useCurrentLocation") }
    /// 現在地から自動で選びました
    public static var decisionAutomatic: String { String(localized: "route.decisionAutomatic") }
    /// 時間帯と前回の行き先から選びました
    public static var decisionTimeOfDay: String { String(localized: "route.decisionTimeOfDay") }
    /// 自分で選んだ経路です
    public static var decisionManual: String { String(localized: "route.decisionManual") }
    /// 便によってヨーカドー前を経由します
    public static var guidanceViaYokado: String { String(localized: "route.guidanceViaYokado") }
    /// 海浜幕張駅を経由してヨーカドー前へ向かいます
    public static var guidanceToYokado: String { String(localized: "route.guidanceToYokado") }
    /// 選択した出発地から目的地まで運行します
    public static var guidanceDefault: String { String(localized: "route.guidanceDefault") }
    /// ヨーカドー前から出発する本日の便は終了しました
    public static var yokadoDepartureEnded: String { String(localized: "route.yokadoDepartureEnded") }
    /// 現在地付近から出発する本日の便は終了しました
    public static var nearbyDepartureEnded: String { String(localized: "route.nearbyDepartureEnded") }
    /// ヨーカドー前へ向かう本日の便は終了したため、候補から外しました
    public static var yokadoRemoved: String { String(localized: "route.yokadoRemoved") }
    /// 本日のバスはすべて終了しました
    public static var allServicesEnded: String { String(localized: "route.allServicesEnded") }
  }

  public enum When {
    /// いつのバス
    public static var title: String { String(localized: "when.title") }
    /// 今日
    public static var serviceDayToday: String { String(localized: "when.serviceDayToday") }
    /// 他の平日
    public static var serviceDayOtherWeekday: String { String(localized: "when.serviceDayOtherWeekday") }
    /// 出発時間
    public static var searchTypeDeparture: String { String(localized: "when.searchTypeDeparture") }
    /// 到着時間
    public static var searchTypeArrival: String { String(localized: "when.searchTypeArrival") }
    /// 出発する時刻から探す
    public static var searchTypeDepartureFull: String { String(localized: "when.searchTypeDepartureFull") }
    /// 到着したい時刻から探す
    public static var searchTypeArrivalFull: String { String(localized: "when.searchTypeArrivalFull") }
    /// この時刻以降に出発
    public static var departureTimeTitle: String { String(localized: "when.departureTimeTitle") }
    /// この時刻までに到着
    public static var arrivalTimeTitle: String { String(localized: "when.arrivalTimeTitle") }
    /// 指定した時刻以降に出発する便を、早い順に表示します
    public static var departureExplanation: String { String(localized: "when.departureExplanation") }
    /// 指定した時刻までに目的地へ着く便を、到着時刻が近い順に表示します
    public static var arrivalExplanation: String { String(localized: "when.arrivalExplanation") }
    /// 現在時刻
    public static var currentTime: String { String(localized: "when.currentTime") }
    /// 選択中の検索方法を変えずに現在時刻を入力します
    public static var currentTimeHint: String { String(localized: "when.currentTimeHint") }
    /// 今日
    public static var serviceDayTodayName: String { String(localized: "when.serviceDayTodayName") }
    /// 他の平日
    public static var serviceDayOtherWeekdayName: String { String(localized: "when.serviceDayOtherWeekdayName") }
  }

  public enum Result {
    /// つぎのバス
    public static var nextBus: String { String(localized: "result.nextBus") }
    /// 平日ダイヤの便
    public static var weekdayService: String { String(localized: "result.weekdayService") }
    /// このあとの便
    public static var followingTitle: String { String(localized: "result.followingTitle") }
    /// 計算中
    public static var calculating: String { String(localized: "result.calculating") }
    /// 出発済み
    public static var departed: String { String(localized: "result.departed") }
    /// まもなく出発
    public static var leavingSoon: String { String(localized: "result.leavingSoon") }
    /// あと
    public static var remainingPrefix: String { String(localized: "result.remainingPrefix") }
    /// 分
    public static var unitMinute: String { String(localized: "result.unitMinute") }
    /// 時間
    public static var unitHour: String { String(localized: "result.unitHour") }
    /// 発
    public static var departureSuffix: String { String(localized: "result.departureSuffix") }
    /// 着
    public static var arrivalSuffix: String { String(localized: "result.arrivalSuffix") }
    /// 残り時間を計算中
    public static var a11yCalculating: String { String(localized: "result.a11yCalculating") }
    /// この便は出発済みです
    public static var a11yDeparted: String { String(localized: "result.a11yDeparted") }
    /// まもなく出発します
    public static var a11yLeavingSoon: String { String(localized: "result.a11yLeavingSoon") }
    /// あと%lld分で出発します
    public static func a11yMinutes(_ arg0: Int) -> String {
      String(format: String(localized: "result.a11yMinutes"), arg0)
    }
    /// あと%lld時間で出発します
    public static func a11yHours(_ arg0: Int) -> String {
      String(format: String(localized: "result.a11yHours"), arg0)
    }
    /// あと%1$lld時間%2$lld分で出発します
    public static func a11yHoursMinutes(_ arg0: Int, _ arg1: Int) -> String {
      String(format: String(localized: "result.a11yHoursMinutes"), arg0, arg1)
    }
    /// %1$@、%2$@発です
    public static func a11yScheduledDeparture(_ arg0: String, _ arg1: String) -> String {
      String(format: String(localized: "result.a11yScheduledDeparture"), arg0, arg1)
    }
    /// %1$@発、%2$@着
    public static func a11yTimeRow(_ arg0: String, _ arg1: String) -> String {
      String(format: String(localized: "result.a11yTimeRow"), arg0, arg1)
    }
    /// 通知を設定済み
    public static var notifyScheduled: String { String(localized: "result.notifyScheduled") }
    /// 通知の内容を変更できます
    public static var notifyScheduledHint: String { String(localized: "result.notifyScheduledHint") }
    /// この便を通知する
    public static var notify: String { String(localized: "result.notify") }
    /// 出発前に通知する方法を選びます
    public static var notifyHint: String { String(localized: "result.notifyHint") }
    /// %1$@発 %2$@着
    public static func rowLabel(_ arg0: String, _ arg1: String) -> String {
      String(format: String(localized: "result.rowLabel"), arg0, arg1)
    }
    /// 、通知設定済み
    public static var rowLabelScheduled: String { String(localized: "result.rowLabelScheduled") }
    /// この便には通知を設定できません
    public static var rowHintCannotNotify: String { String(localized: "result.rowHintCannotNotify") }
    /// 条件に合うバスがありません
    public static var emptyTitle: String { String(localized: "result.emptyTitle") }
    /// 行き先または時刻を変えて検索してください
    public static var emptyMessage: String { String(localized: "result.emptyMessage") }
    /// 読み込みできませんでした
    public static var failedTitle: String { String(localized: "result.failedTitle") }
    /// 運行のお知らせ
    public static var serviceNoticeTitle: String { String(localized: "result.serviceNoticeTitle") }
    /// 平日のみ運行・時刻表は現地の案内を優先してください
    public static var footer: String { String(localized: "result.footer") }
    /// ひとつ前の便
    public static var earlierTitle: String { String(localized: "result.earlierTitle") }
  }

  public enum Search {
    /// 検索条件: まだ検索されていません
    public static var criteriaInitial: String { String(localized: "search.criteriaInitial") }
    /// 出発地・目的地と時刻を選んでください
    public static var resultInitial: String { String(localized: "search.resultInitial") }
    /// 条件に合う便がありません。時刻または目的地を変更してください
    public static var noResults: String { String(localized: "search.noResults") }
    /// %lld便見つかりました。運休日のため平日ダイヤの時刻です
    public static func resultCountSuspended(_ arg0: Int) -> String {
      String(format: String(localized: "search.resultCountSuspended"), arg0)
    }
    /// %1$lld便見つかりました。%2$@
    public static func resultCount(_ arg0: Int, _ arg1: String) -> String {
      String(format: String(localized: "search.resultCount"), arg0, arg1)
    }
    /// %1$@ → %2$@｜%3$@までに到着
    public static func criteriaArrival(_ arg0: String, _ arg1: String, _ arg2: String) -> String {
      String(format: String(localized: "search.criteriaArrival"), arg0, arg1, arg2)
    }
    /// %1$@ → %2$@｜%3$@以降に出発
    public static func criteriaDeparture(_ arg0: String, _ arg1: String, _ arg2: String) -> String {
      String(format: String(localized: "search.criteriaDeparture"), arg0, arg1, arg2)
    }
    /// 選択された路線の時刻表を読み込めませんでした。
    public static var timetableLoadFailed: String { String(localized: "search.timetableLoadFailed") }
    /// %@到着・希望時刻までに到着
    public static func reasonArrival(_ arg0: String) -> String {
      String(format: String(localized: "search.reasonArrival"), arg0)
    }
    /// %@出発・指定時刻以降
    public static func reasonDeparture(_ arg0: String) -> String {
      String(format: String(localized: "search.reasonDeparture"), arg0)
    }
  }

  public enum Holiday {
    /// 土日
    public static var weekend: String { String(localized: "holiday.weekend") }
    /// 祝日
    public static var publicHoliday: String { String(localized: "holiday.publicHoliday") }
    /// 本日は%@のため運休です。
    public static func message(_ arg0: String) -> String {
      String(format: String(localized: "holiday.message"), arg0)
    }
    /// 本日は%@のため運休です。以下は平日ダイヤの時刻です。
    public static func serviceDayNotice(_ arg0: String) -> String {
      String(format: String(localized: "holiday.serviceDayNotice"), arg0)
    }
  }

  public enum Notify {
    /// 運休日のため通知は設定できません。平日になると設定できます
    public static var unavailableSuspended: String { String(localized: "notify.unavailableSuspended") }
    /// 他の平日の時刻のため、通知は運行当日に設定してください
    public static var unavailableOtherDay: String { String(localized: "notify.unavailableOtherDay") }
    /// 通知設定
    public static var resultTitle: String { String(localized: "notify.resultTitle") }
    /// 通知を設定しました。\n\n%1$@\n%2$@にお知らせします。%3$@\n\n※時刻表の予定です。遅延・運休は反映されません。
    public static func scheduledMessage(_ arg0: String, _ arg1: String, _ arg2: String) -> String {
      String(format: String(localized: "notify.scheduledMessage"), arg0, arg1, arg2)
    }
    /// \nLive Activityも表示中です。
    public static var alsoLiveActivity: String { String(localized: "notify.alsoLiveActivity") }
    /// \n別の便をLive Activityで表示中のため、通常通知だけを設定しました。
    public static var onlyNormalNotification: String { String(localized: "notify.onlyNormalNotification") }
    /// \nLive Activityも開始しました。
    public static var liveActivityStarted: String { String(localized: "notify.liveActivityStarted") }
    /// \n通常通知は設定されましたが、Live Activityは開始できませんでした。
    public static var liveActivityFailed: String { String(localized: "notify.liveActivityFailed") }
    /// バスの時間をお知らせします
    public static var pushTitle: String { String(localized: "notify.pushTitle") }
    /// %1$@が、あと%2$lld分で出発します。\n※時刻表の予定です。遅延・運休は反映されません。
    public static func pushBody(_ arg0: String, _ arg1: Int) -> String {
      String(format: String(localized: "notify.pushBody"), arg0, arg1)
    }
    /// %1$@発｜%2$@
    public static func busDescription(_ arg0: String, _ arg1: String) -> String {
      String(format: String(localized: "notify.busDescription"), arg0, arg1)
    }
    /// %1$lld分前（%2$@）
    public static func minutesBefore(_ arg0: Int, _ arg1: String) -> String {
      String(format: String(localized: "notify.minutesBefore"), arg0, arg1)
    }
    /// M月d日(E) H:mm
    public static var dateFormat: String { String(localized: "notify.dateFormat") }
  }

  public enum Countdown {
    /// 出発済み
    public static var departed: String { String(localized: "countdown.departed") }
    /// まもなく出発
    public static var leavingSoon: String { String(localized: "countdown.leavingSoon") }
    /// あと%d時間
    public static func hours(_ arg0: Int) -> String {
      String(format: String(localized: "countdown.hours"), arg0)
    }
    /// あと%1$d時間%2$d分
    public static func hoursMinutes(_ arg0: Int, _ arg1: Int) -> String {
      String(format: String(localized: "countdown.hoursMinutes"), arg0, arg1)
    }
    /// あと%d分
    public static func minutes(_ arg0: Int) -> String {
      String(format: String(localized: "countdown.minutes"), arg0)
    }
  }

  public enum LiveActivity {
    /// 別の便のLive Activityを表示中です。先に「設定した通知」から表示を終了してください。
    public static var otherBusShowing: String { String(localized: "liveActivity.otherBusShowing") }
    /// Live Activityを開始できません。iPhoneの設定で、BusTimeのLive Activityを許可してください。
    public static var notPermitted: String { String(localized: "liveActivity.notPermitted") }
    /// この便はすでにLive Activityで表示中です。
    public static var alreadyShowing: String { String(localized: "liveActivity.alreadyShowing") }
    /// 出発時刻を確認できないため、Live Activityを開始できません。
    public static var noDepartureTime: String { String(localized: "liveActivity.noDepartureTime") }
    /// この便はすでに出発しています。別の便を選んでください。
    public static var alreadyDeparted: String { String(localized: "liveActivity.alreadyDeparted") }
    /// Live Activityを開始できませんでした。iPhoneの設定を確認して、もう一度お試しください。
    public static var startFailed: String { String(localized: "liveActivity.startFailed") }
    /// Live Activityでエラーが発生しました。
    public static var genericError: String { String(localized: "liveActivity.genericError") }
    /// Live Activityエラー
    public static var errorTitle: String { String(localized: "liveActivity.errorTitle") }
    /// 設定を確認
    public static var openSettings: String { String(localized: "liveActivity.openSettings") }
  }

  public enum Permission {
    /// まだ確認していません
    public static var notDetermined: String { String(localized: "permission.notDetermined") }
    /// 通知は許可されています
    public static var authorized: String { String(localized: "permission.authorized") }
    /// 通知が許可されていません
    public static var denied: String { String(localized: "permission.denied") }
  }

  public enum ScheduleError {
    /// 通知が許可されていません。iPhoneの設定で「BusTime」の通知をオンにしてください。
    public static var notPermitted: String { String(localized: "scheduleError.notPermitted") }
    /// バスの出発時刻を確認できませんでした。別の便を選んでください。
    public static var noDeparture: String { String(localized: "scheduleError.noDeparture") }
    /// この便は通知時刻がすでに過ぎています。もう少し先の便を選んでください。
    public static var tooLate: String { String(localized: "scheduleError.tooLate") }
    /// 通知を設定できませんでした。もう一度お試しください。
    public static var unknown: String { String(localized: "scheduleError.unknown") }
  }

  public enum Manage {
    /// 設定した通知
    public static var title: String { String(localized: "manage.title") }
    /// 通常の通知を受け取るには、iPhoneの通知許可が必要です。
    public static var permissionMessage: String { String(localized: "manage.permissionMessage") }
    /// 通知の設定を開く
    public static var openNotificationSettings: String { String(localized: "manage.openNotificationSettings") }
    /// ロック画面にバスの出発時間を表示しています。
    public static var liveActivityShowing: String { String(localized: "manage.liveActivityShowing") }
    /// Live Activityを終了
    public static var endLiveActivity: String { String(localized: "manage.endLiveActivity") }
    /// 表示中のLive Activityはありません。便を選ぶと開始できます。
    public static var noLiveActivity: String { String(localized: "manage.noLiveActivity") }
    /// 通常の通知
    public static var standardSection: String { String(localized: "manage.standardSection") }
    /// すべて解除
    public static var clearAll: String { String(localized: "manage.clearAll") }
    /// 設定されている通知はありません。
    public static var empty: String { String(localized: "manage.empty") }
    /// 通知：%@
    public static func notificationRow(_ arg0: String) -> String {
      String(format: String(localized: "manage.notificationRow"), arg0)
    }
    /// この通知を解除
    public static var cancelOne: String { String(localized: "manage.cancelOne") }
  }

  public enum Options {
    /// この便をお知らせ
    public static var title: String { String(localized: "options.title") }
    /// 対象のバス
    public static var targetSection: String { String(localized: "options.targetSection") }
    /// 途中停車：%@
    public static func intermediateStops(_ arg0: String) -> String {
      String(format: String(localized: "options.intermediateStops"), arg0)
    }
    /// 通常の通知
    public static var standardSection: String { String(localized: "options.standardSection") }
    /// 現在の設定：%@
    public static func currentSetting(_ arg0: String) -> String {
      String(format: String(localized: "options.currentSetting"), arg0)
    }
    /// 同じ便の通知は1件だけ設定できます。選び直すと通知時刻が変更されます。
    public static var onlyOnePerBus: String { String(localized: "options.onlyOnePerBus") }
    /// 通知が許可されていません。
    public static var notPermitted: String { String(localized: "options.notPermitted") }
    /// iPhoneの設定で通知を許可する
    public static var allowInSettings: String { String(localized: "options.allowInSettings") }
    /// この通知は時刻表の予定時刻を基準にしています。遅延や運休は自動では反映されません。
    public static var timetableCaveat: String { String(localized: "options.timetableCaveat") }
    /// %lld分前に通知
    public static func minutesBefore(_ arg0: Int) -> String {
      String(format: String(localized: "options.minutesBefore"), arg0)
    }
    /// 通知時刻：%@
    public static func notificationTime(_ arg0: String) -> String {
      String(format: String(localized: "options.notificationTime"), arg0)
    }
    /// この便では設定できません
    public static var notAvailable: String { String(localized: "options.notAvailable") }
    /// ロック画面やDynamic Islandで、出発までの時間を確認できます。
    public static var liveActivityDescription: String { String(localized: "options.liveActivityDescription") }
    /// この端末では利用できないか、iPhoneの設定でLive Activityがオフになっています。
    public static var liveActivityUnavailable: String { String(localized: "options.liveActivityUnavailable") }
    /// アプリの設定で自動表示がオフです。必要なときは下のボタンから開始できます。
    public static var autoStartOff: String { String(localized: "options.autoStartOff") }
    /// 設定済みの%lld分前通知も、そのまま届きます。
    public static func existingAlertKept(_ arg0: Int) -> String {
      String(format: String(localized: "options.existingAlertKept"), arg0)
    }
    /// 通常の通知を設定すると、Live Activityも自動で開始します。下のボタンから始める場合は5分前通知も一緒に設定します。
    public static var autoStartDescription: String { String(localized: "options.autoStartDescription") }
    /// この便の表示を終了
    public static var endThisDisplay: String { String(localized: "options.endThisDisplay") }
    /// 5分前通知とLive Activityを開始
    public static var startWithAlert: String { String(localized: "options.startWithAlert") }
    /// Live Activityを開始（通知は継続）
    public static var startKeepingAlert: String { String(localized: "options.startKeepingAlert") }
    /// 別の便をLive Activityで表示中です。先に管理画面から終了してください。
    public static var otherBusShowing: String { String(localized: "options.otherBusShowing") }
  }

  public enum Timetable {
    /// 時刻表
    public static var title: String { String(localized: "timetable.title") }
    /// 本日の運行
    public static var serviceNoticeTitle: String { String(localized: "timetable.serviceNoticeTitle") }
    /// 時刻表がありません
    public static var emptyTitle: String { String(localized: "timetable.emptyTitle") }
    /// ホームタブで出発地と目的地を選び直してください
    public static var emptyMessage: String { String(localized: "timetable.emptyMessage") }
    /// %lld便
    public static func serviceCount(_ arg0: Int) -> String {
      String(format: String(localized: "timetable.serviceCount"), arg0)
    }
    /// 経路を変えるときは、ホームタブで出発地と目的地を選んでください
    public static var routeHint: String { String(localized: "timetable.routeHint") }
    /// 時刻をタップすると通知できます
    public static var notificationHintTitle: String { String(localized: "timetable.notificationHintTitle") }
    /// 選んだ便が出発する前にお知らせします。設定した時刻は色が変わります。
    public static var notificationHintBody: String { String(localized: "timetable.notificationHintBody") }
    /// %lld時台
    public static func hourAccessibility(_ arg0: Int) -> String {
      String(format: String(localized: "timetable.hourAccessibility"), arg0)
    }
    /// 色のついた時刻は通知を設定済みです
    public static var legendScheduled: String { String(localized: "timetable.legendScheduled") }
    /// 点の付いた便はお買い物便や経由便です
    public static var legendNote: String { String(localized: "timetable.legendNote") }
    /// %1$@発、%2$@着
    public static func cellAccessibility(_ arg0: String, _ arg1: String) -> String {
      String(format: String(localized: "timetable.cellAccessibility"), arg0, arg1)
    }
    /// 、通知設定済み
    public static var cellScheduled: String { String(localized: "timetable.cellScheduled") }
    /// 、出発済み
    public static var cellDeparted: String { String(localized: "timetable.cellDeparted") }
    /// 運休日のため通知は設定できません
    public static var cannotNotifyHint: String { String(localized: "timetable.cannotNotifyHint") }
    /// ベルの印が付いた時刻は通知を設定済みです
    public static var legendScheduledMark: String { String(localized: "timetable.legendScheduledMark") }
    /// 破線で囲まれた便は検索条件に合う便です
    public static var legendRecommendedMark: String { String(localized: "timetable.legendRecommendedMark") }
  }

  public enum Settings {
    /// 設定
    public static var title: String { String(localized: "settings.title") }
    /// 画面の色
    public static var appearanceSection: String { String(localized: "settings.appearanceSection") }
    /// 時刻に合わせて変わります
    public static var appearanceTitle: String { String(localized: "settings.appearanceTitle") }
    /// 朝は明るい空、夕方は夕焼け、夜は星空へと背景がゆっくり変化します。太陽と月の位置も現在時刻に合わせて動きます。
    public static var appearanceDescription: String { String(localized: "settings.appearanceDescription") }
    /// 海浜幕張駅の周辺で雨が降っているときは、背景にも雨が降ります。天気の情報は Open-Meteo から取得しています。
    public static var weatherNotice: String { String(localized: "settings.weatherNotice") }
    /// 朝
    public static var previewMorning: String { String(localized: "settings.previewMorning") }
    /// 昼
    public static var previewNoon: String { String(localized: "settings.previewNoon") }
    /// 夕
    public static var previewEvening: String { String(localized: "settings.previewEvening") }
    /// 夜
    public static var previewNight: String { String(localized: "settings.previewNight") }
    /// 朝、昼、夕方、夜の背景の見本
    public static var previewAccessibility: String { String(localized: "settings.previewAccessibility") }
    /// カードの濃さ
    public static var cardOpacitySection: String { String(localized: "settings.cardOpacitySection") }
    /// 背景の風景がどれだけ透けるかを選べます。
    public static var cardOpacityDescription: String { String(localized: "settings.cardOpacityDescription") }
    /// うすい
    public static var cardOpacityLight: String { String(localized: "settings.cardOpacityLight") }
    /// こい
    public static var cardOpacityDense: String { String(localized: "settings.cardOpacityDense") }
    /// 時刻表のように文字が詰まった画面は、ここより少し濃く表示されます
    public static var cardOpacityNotice: String { String(localized: "settings.cardOpacityNotice") }
    /// バスのお知らせ
    public static var notificationsSection: String { String(localized: "settings.notificationsSection") }
    /// Live Activityを使う
    public static var liveActivityToggle: String { String(localized: "settings.liveActivityToggle") }
    /// 通常の通知と一緒に、ロック画面やDynamic Islandへ残り時間を表示します。
    public static var liveActivityDescription: String { String(localized: "settings.liveActivityDescription") }
    /// 対応端末では最初からオンです。ここでいつでも変更できます。
    public static var liveActivityAvailable: String { String(localized: "settings.liveActivityAvailable") }
  }

  public enum Tutorial {
    /// はじめに
    public static var section: String { String(localized: "tutorial.section") }
    /// 使い方を閉じる
    public static var closeAccessibility: String { String(localized: "tutorial.closeAccessibility") }
    /// はじめる
    public static var start: String { String(localized: "tutorial.start") }
    /// 次へ
    public static var next: String { String(localized: "tutorial.next") }
    /// バスの時間を、\nもっと気持ちよく
    public static var page1Title: String { String(localized: "tutorial.page1Title") }
    /// 必要な便だけを、見やすいカードで確認できます。
    public static var page1Description: String { String(localized: "tutorial.page1Description") }
    /// 今すぐ乗れる便を\nすばやく検索
    public static var page2Title: String { String(localized: "tutorial.page2Title") }
    /// ルートと時刻を選んで、次のバスを見つけましょう。
    public static var page2Description: String { String(localized: "tutorial.page2Description") }
    /// 乗り遅れを\nそっと防止
    public static var page3Title: String { String(localized: "tutorial.page3Title") }
    /// ベルから通知やLive Activityを設定できます。
    public static var page3Description: String { String(localized: "tutorial.page3Description") }
  }

  public enum Weather {
    /// 天気情報の取得先を組み立てられませんでした。
    public static var invalidURL: String { String(localized: "weather.invalidURL") }
    /// 天気情報を取得できませんでした。通信状態を確認してください。
    public static var requestFailed: String { String(localized: "weather.requestFailed") }
    /// 天気情報の形式を解釈できませんでした。
    public static var decodingFailed: String { String(localized: "weather.decodingFailed") }
  }

  public enum Remaining {
    /// 出発済み
    public static var departed: String { String(localized: "remaining.departed") }
    /// 1分未満
    public static var lessThanMinute: String { String(localized: "remaining.lessThanMinute") }
    /// %lld分
    public static func minutes(_ arg0: Int) -> String {
      String(format: String(localized: "remaining.minutes"), arg0)
    }
    /// %lld時間
    public static func hours(_ arg0: Int) -> String {
      String(format: String(localized: "remaining.hours"), arg0)
    }
    /// %1$lld時間%2$lld分
    public static func hoursMinutes(_ arg0: Int, _ arg1: Int) -> String {
      String(format: String(localized: "remaining.hoursMinutes"), arg0, arg1)
    }
  }

  public enum Widget {
    /// 出発まで
    public static var untilDeparture: String { String(localized: "widget.untilDeparture") }
    /// 出発済
    public static var departedShort: String { String(localized: "widget.departedShort") }
  }

  public enum BusNote {
    /// お買い物便
    public static var shopping: String { String(localized: "busNote.shopping") }
    /// ヨーカドー経由
    public static var viaYokado: String { String(localized: "busNote.viaYokado") }
    /// 海浜幕張駅経由
    public static var viaStation: String { String(localized: "busNote.viaStation") }
  }

}