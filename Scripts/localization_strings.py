"""アプリの文言の対訳表です。

この表が唯一の原本です。文言を足す・直すときはここを編集し、
Scripts/generate_l10n.py を実行して次の2つを作り直してください。

  - BusTimeApp/Localization/Localizable.xcstrings（実際の文字）
  - BusTimeApp/Localization/L10n.swift（コードから呼ぶ名前）

1件の形式は (キー, 日本語, 英語, 簡体字中国語, 引数の型) です。
キーは「区分.名前」で、区分がSwiftの列挙型、名前がその要素になります。
引数がある場合は %@ や %lld を含め、2つ以上なら %1$@ のように順番を明示します。
"""

ENTRIES = [

    # ---- 共通 ----
    ('common.close', '閉じる', 'Close', '关闭', []),
    ('common.done', '完了', 'Done', '完成', []),
    ('common.ok', 'OK', 'OK', '好', []),

    # ---- タブ ----
    ('tab.home', 'ホーム', 'Home', '首页', []),
    ('tab.timetable', '時刻表', 'Timetable', '时刻表', []),
    ('tab.homeAccessibility', 'ホームタブ', 'Home tab', '首页标签页', []),
    ('tab.timetableAccessibility', '時刻表タブ', 'Timetable tab', '时刻表标签页', []),

    # ---- ホーム画面のヘッダー ----
    ('home.notificationsButton', '設定した通知を確認', 'Check scheduled alerts', '查看已设置的提醒', []),
    ('home.settingsButton', '設定を開く', 'Open settings', '打开设置', []),
    ('home.tutorialButton', '使い方を開く', 'Open the guide', '打开使用说明', []),

    # ---- 経路の帯 ----
    ('route.originLabel', '出発地', 'From', '出发地', []),
    ('route.destinationLabel', '目的地', 'To', '目的地', []),
    ('route.menuHint', '変更するには二回タップします', 'Double tap to change', '轻点两下即可更改', []),
    ('route.stopAccessibility', '%1$@、%2$@', '%1$@, %2$@', '%1$@，%2$@', ['String', 'String']),
    ('route.swapLabel', '出発地と目的地を入れ替える', 'Swap origin and destination', '交换出发地和目的地', []),
    ('route.swapHintAvailable', '入れ替えます', 'Swaps them', '进行交换', []),
    ('route.swapHintUnavailable', '逆向きの便は本日終了しているため使えません', 'There is no return service left today', '反方向班次今日已结束', []),
    ('route.useCurrentLocation', '現在地に合わせる', 'Use current location', '使用当前位置', []),
    ('route.decisionAutomatic', '現在地から自動で選びました', 'Chosen from your location', '已根据当前位置选择', []),
    ('route.decisionTimeOfDay', '時間帯と前回の行き先から選びました', 'Chosen from the time of day and your last destination', '已根据时段和上次的目的地选择', []),
    ('route.decisionManual', '自分で選んだ経路です', 'You chose this route', '这是您选择的路线', []),
    ('route.guidanceViaYokado', '便によってヨーカドー前を経由します', 'Some services stop at ヨーカドー前', '部分班次经停ヨーカドー前', []),
    ('route.guidanceToYokado', '海浜幕張駅を経由してヨーカドー前へ向かいます', 'Runs to ヨーカドー前 via 海浜幕張駅', '经由海浜幕張駅前往ヨーカドー前', []),
    ('route.guidanceDefault', '選択した出発地から目的地まで運行します', 'Runs from the selected origin to the destination', '从所选出发地开往目的地', []),
    ('route.yokadoDepartureEnded', 'ヨーカドー前から出発する本日の便は終了しました', "Today's services from ヨーカドー前 have finished", '今日从ヨーカドー前出发的班次已结束', []),
    ('route.nearbyDepartureEnded', '現在地付近から出発する本日の便は終了しました', "Today's services from near you have finished", '今日从您附近出发的班次已结束', []),
    ('route.yokadoRemoved', 'ヨーカドー前へ向かう本日の便は終了したため、候補から外しました', "Today's services to ヨーカドー前 have finished, so it was removed from the choices", '今日前往ヨーカドー前的班次已结束，已从候选中移除', []),
    ('route.allServicesEnded', '本日のバスはすべて終了しました', 'All services have finished for today', '今日所有班次均已结束', []),

    # ---- いつのバス（運行日と時刻） ----
    ('when.title', 'いつのバス', 'When', '何时的班次', []),
    ('when.serviceDayToday', '今日', 'Today', '今天', []),
    ('when.serviceDayOtherWeekday', '他の平日', 'Other weekday', '其他工作日', []),
    ('when.searchTypeDeparture', '出発時間', 'Departure', '出发时间', []),
    ('when.searchTypeArrival', '到着時間', 'Arrival', '到达时间', []),
    ('when.searchTypeDepartureFull', '出発する時刻から探す', 'Search by departure time', '按出发时间查找', []),
    ('when.searchTypeArrivalFull', '到着したい時刻から探す', 'Search by arrival time', '按到达时间查找', []),
    ('when.departureTimeTitle', 'この時刻以降に出発', 'Departing after', '在此时间之后出发', []),
    ('when.arrivalTimeTitle', 'この時刻までに到着', 'Arriving by', '在此时间之前到达', []),
    ('when.departureExplanation', '指定した時刻以降に出発する便を、早い順に表示します', 'Shows services departing after the time you set, earliest first', '按最早顺序显示在指定时间之后出发的班次', []),
    ('when.arrivalExplanation', '指定した時刻までに目的地へ着く便を、到着時刻が近い順に表示します', 'Shows services arriving by the time you set, closest arrival first', '按到达时间由近及远显示能在指定时间前抵达的班次', []),
    ('when.currentTime', '現在時刻', 'Now', '当前时间', []),
    ('when.currentTimeHint', '選択中の検索方法を変えずに現在時刻を入力します', 'Fills in the current time without changing the search type', '在不更改搜索方式的情况下填入当前时间', []),

    # ---- 便の表示 ----
    ('result.nextBus', 'つぎのバス', 'Next bus', '下一班车', []),
    ('result.weekdayService', '平日ダイヤの便', 'Weekday timetable', '工作日时刻表班次', []),
    ('result.followingTitle', 'このあとの便', 'Later services', '之后的班次', []),
    ('result.calculating', '計算中', 'Calculating', '计算中', []),
    ('result.departed', '出発済み', 'Departed', '已出发', []),
    ('result.leavingSoon', 'まもなく出発', 'Leaving soon', '即将出发', []),
    ('result.remainingPrefix', 'あと', 'in', '还有', []),
    ('result.unitMinute', '分', 'min', '分钟', []),
    ('result.unitHour', '時間', 'hr', '小时', []),
    ('result.departureSuffix', '発', 'dep.', '出发', []),
    ('result.arrivalSuffix', '着', 'arr.', '到达', []),
    ('result.a11yCalculating', '残り時間を計算中', 'Calculating the time remaining', '正在计算剩余时间', []),
    ('result.a11yDeparted', 'この便は出発済みです', 'This service has departed', '该班次已出发', []),
    ('result.a11yLeavingSoon', 'まもなく出発します', 'Leaving soon', '即将出发', []),
    ('result.a11yMinutes', 'あと%lld分で出発します', 'Departing in %lld minutes', '%lld分钟后出发', ['Int']),
    ('result.a11yHours', 'あと%lld時間で出発します', 'Departing in %lld hours', '%lld小时后出发', ['Int']),
    ('result.a11yHoursMinutes', 'あと%1$lld時間%2$lld分で出発します', 'Departing in %1$lld hours %2$lld minutes', '%1$lld小时%2$lld分钟后出发', ['Int', 'Int']),
    ('result.a11yScheduledDeparture', '%1$@、%2$@発です', '%1$@, departing at %2$@', '%1$@，%2$@出发', ['String', 'String']),
    ('result.a11yTimeRow', '%1$@発、%2$@着', 'Departs %1$@, arrives %2$@', '%1$@出发，%2$@到达', ['String', 'String']),
    ('result.notifyScheduled', '通知を設定済み', 'Alert set', '已设置提醒', []),
    ('result.notifyScheduledHint', '通知の内容を変更できます', 'You can change the alert', '可以更改提醒内容', []),
    ('result.notify', 'この便を通知する', 'Notify me for this service', '提醒我这班车', []),
    ('result.notifyHint', '出発前に通知する方法を選びます', 'Choose how to be alerted before departure', '选择出发前的提醒方式', []),
    ('result.rowLabel', '%1$@発 %2$@着', 'Departs %1$@, arrives %2$@', '%1$@出发，%2$@到达', ['String', 'String']),
    ('result.rowLabelScheduled', '、通知設定済み', ', alert set', '，已设置提醒', []),
    ('result.rowHintCannotNotify', 'この便には通知を設定できません', 'You cannot set an alert for this service', '无法为该班次设置提醒', []),
    ('result.emptyTitle', '条件に合うバスがありません', 'No services match', '没有符合条件的班次', []),
    ('result.emptyMessage', '行き先または時刻を変えて検索してください', 'Change the destination or the time', '请更改目的地或时间', []),
    ('result.failedTitle', '読み込みできませんでした', 'Could not load', '无法加载', []),
    ('result.serviceNoticeTitle', '運行のお知らせ', 'Service notice', '运行通知', []),
    ('result.footer', '平日のみ運行・時刻表は現地の案内を優先してください', 'Weekdays only. Please follow the notices at the stop.', '仅工作日运行。请以现场公告为准。', []),

    # ---- 検索の説明 ----
    ('search.criteriaInitial', '検索条件: まだ検索されていません', 'Search: not run yet', '搜索条件：尚未搜索', []),
    ('search.resultInitial', '出発地・目的地と時刻を選んでください', 'Choose the stops and the time', '请选择站点和时间', []),
    ('search.noResults', '条件に合う便がありません。時刻または目的地を変更してください', 'No services match. Change the time or the destination.', '没有符合条件的班次。请更改时间或目的地。', []),
    ('search.resultCountSuspended', '%lld便見つかりました。運休日のため平日ダイヤの時刻です', 'Found %lld services. There is no service today, so these are weekday times.', '找到%lld个班次。今日停运，显示的是工作日时刻。', ['Int']),
    ('search.resultCount', '%1$lld便見つかりました。%2$@', 'Found %1$lld services. %2$@', '找到%1$lld个班次。%2$@', ['Int', 'String']),
    ('search.criteriaArrival', '%1$@ → %2$@｜%3$@までに到着', '%1$@ → %2$@ | arriving by %3$@', '%1$@ → %2$@｜%3$@前到达', ['String', 'String', 'String']),
    ('search.criteriaDeparture', '%1$@ → %2$@｜%3$@以降に出発', '%1$@ → %2$@ | departing after %3$@', '%1$@ → %2$@｜%3$@后出发', ['String', 'String', 'String']),
    ('search.timetableLoadFailed', '選択された路線の時刻表を読み込めませんでした。', 'Could not load the timetable for the selected route.', '无法加载所选路线的时刻表。', []),
    ('search.reasonArrival', '%@到着・希望時刻までに到着', 'Arrives %@, within your target time', '%@到达，在期望时间之内', ['String']),
    ('search.reasonDeparture', '%@出発・指定時刻以降', 'Departs %@, after the time you set', '%@出发，在指定时间之后', ['String']),

    # ---- 運休の案内 ----
    ('holiday.weekend', '土日', 'the weekend', '周末', []),
    ('holiday.publicHoliday', '祝日', 'a public holiday', '节假日', []),
    ('holiday.message', '本日は%@のため運休です。', 'There is no service today (%@).', '今日因%@停运。', ['String']),
    ('holiday.serviceDayNotice', '本日は%@のため運休です。以下は平日ダイヤの時刻です。', 'There is no service today (%@). The times below are from the weekday timetable.', '今日因%@停运。以下为工作日时刻表。', ['String']),

    # ---- 通知 ----
    ('notify.unavailableSuspended', '運休日のため通知は設定できません。平日になると設定できます', 'No service today, so alerts cannot be set. You can set them on a weekday.', '今日停运，无法设置提醒。工作日可以设置。', []),
    ('notify.unavailableOtherDay', '他の平日の時刻のため、通知は運行当日に設定してください', 'These are times for another weekday. Please set the alert on the day of travel.', '这是其他工作日的时刻，请在乘车当天设置提醒。', []),

    # ---- カウントダウン ----
    ('countdown.departed', '出発済み', 'Departed', '已出发', []),
    ('countdown.leavingSoon', 'まもなく出発', 'Leaving soon', '即将出发', []),
    ('countdown.hours', 'あと%d時間', '%d hr left', '还有%d小时', ['Int']),
    ('countdown.hoursMinutes', 'あと%1$d時間%2$d分', '%1$d hr %2$d min left', '还有%1$d小时%2$d分钟', ['Int', 'Int']),
    ('countdown.minutes', 'あと%d分', '%d min left', '还有%d分钟', ['Int']),

    # ---- Live Activity ----
    ('liveActivity.otherBusShowing', '別の便のLive Activityを表示中です。先に「設定した通知」から表示を終了してください。', 'A Live Activity for another service is showing. Please end it from “Scheduled alerts” first.', '正在显示其他班次的实时活动。请先从“已设置的提醒”结束显示。', []),
    ('liveActivity.notPermitted', 'Live Activityを開始できません。iPhoneの設定で、BusTimeのLive Activityを許可してください。', 'Live Activities cannot start. Please allow Live Activities for BusTime in iPhone Settings.', '无法启动实时活动。请在 iPhone 设置中允许 BusTime 使用实时活动。', []),
    ('liveActivity.alreadyShowing', 'この便はすでにLive Activityで表示中です。', 'This service is already showing as a Live Activity.', '该班次已在实时活动中显示。', []),
    ('liveActivity.noDepartureTime', '出発時刻を確認できないため、Live Activityを開始できません。', 'The departure time could not be confirmed, so the Live Activity cannot start.', '无法确认出发时间，因此无法启动实时活动。', []),
    ('liveActivity.alreadyDeparted', 'この便はすでに出発しています。別の便を選んでください。', 'This service has already departed. Please choose another one.', '该班次已经出发。请选择其他班次。', []),
    ('liveActivity.startFailed', 'Live Activityを開始できませんでした。iPhoneの設定を確認して、もう一度お試しください。', 'The Live Activity could not start. Please check iPhone Settings and try again.', '无法启动实时活动。请检查 iPhone 设置后重试。', []),
    ('liveActivity.genericError', 'Live Activityでエラーが発生しました。', 'A Live Activity error occurred.', '实时活动发生错误。', []),
    ('liveActivity.errorTitle', 'Live Activityエラー', 'Live Activity error', '实时活动错误', []),
    ('liveActivity.openSettings', '設定を確認', 'Check settings', '查看设置', []),

    # ---- 通知 ----
    ('notify.resultTitle', '通知設定', 'Alert', '提醒设置', []),
    ('notify.scheduledMessage', '通知を設定しました。\n\n%1$@\n%2$@にお知らせします。%3$@\n\n※時刻表の予定です。遅延・運休は反映されません。', 'The alert is set.\n\n%1$@\nYou will be notified %2$@.%3$@\n\n* Based on the published timetable. Delays and cancellations are not reflected.', '已设置提醒。\n\n%1$@\n将于%2$@通知您。%3$@\n\n※以时刻表为准，不反映延误和停运。', ['String', 'String', 'String']),
    ('notify.alsoLiveActivity', '\nLive Activityも表示中です。', '\nA Live Activity is also showing.', '\n同时正在显示实时活动。', []),
    ('notify.onlyNormalNotification', '\n別の便をLive Activityで表示中のため、通常通知だけを設定しました。', '\nA Live Activity for another service is showing, so only the standard alert was set.', '\n因正在显示其他班次的实时活动，仅设置了普通提醒。', []),
    ('notify.liveActivityStarted', '\nLive Activityも開始しました。', '\nA Live Activity has also started.', '\n同时已启动实时活动。', []),
    ('notify.liveActivityFailed', '\n通常通知は設定されましたが、Live Activityは開始できませんでした。', '\nThe standard alert was set, but the Live Activity could not start.', '\n已设置普通提醒，但无法启动实时活动。', []),
    ('notify.pushTitle', 'バスの時間をお知らせします', 'Your bus is coming', '为您提醒巴士时间', []),
    ('notify.pushBody', '%1$@が、あと%2$lld分で出発します。\n※時刻表の予定です。遅延・運休は反映されません。', '%1$@ departs in %2$lld minutes.\n* Based on the published timetable. Delays and cancellations are not reflected.', '%1$@将在%2$lld分钟后出发。\n※以时刻表为准，不反映延误和停运。', ['String', 'Int']),

    # ---- 通知の許可状態 ----
    ('permission.notDetermined', 'まだ確認していません', 'Not asked yet', '尚未确认', []),
    ('permission.authorized', '通知は許可されています', 'Notifications are allowed', '已允许通知', []),
    ('permission.denied', '通知が許可されていません', 'Notifications are not allowed', '未允许通知', []),

    # ---- 通知の設定エラー ----
    ('scheduleError.notPermitted', '通知が許可されていません。iPhoneの設定で「BusTime」の通知をオンにしてください。', 'Notifications are not allowed. Please turn on notifications for “BusTime” in iPhone Settings.', '未允许通知。请在 iPhone 设置中开启“BusTime”的通知。', []),
    ('scheduleError.noDeparture', 'バスの出発時刻を確認できませんでした。別の便を選んでください。', 'The departure time could not be confirmed. Please choose another service.', '无法确认巴士出发时间。请选择其他班次。', []),
    ('scheduleError.tooLate', 'この便は通知時刻がすでに過ぎています。もう少し先の便を選んでください。', 'The alert time for this service has already passed. Please choose a later service.', '该班次的提醒时间已过。请选择更晚的班次。', []),
    ('scheduleError.unknown', '通知を設定できませんでした。もう一度お試しください。', 'The alert could not be set. Please try again.', '无法设置提醒。请重试。', []),

    # ---- 通知 ----
    ('notify.busDescription', '%1$@発｜%2$@', '%1$@ dep. | %2$@', '%1$@出发｜%2$@', ['String', 'String']),
    ('notify.minutesBefore', '%1$lld分前（%2$@）', '%1$lld min before (%2$@)', '提前%1$lld分钟（%2$@）', ['Int', 'String']),
    ('notify.dateFormat', 'M月d日(E) H:mm', 'MMM d (E) H:mm', 'M月d日(E) H:mm', []),

    # ---- 通知の管理画面 ----
    ('manage.title', '設定した通知', 'Scheduled alerts', '已设置的提醒', []),
    ('manage.permissionMessage', '通常の通知を受け取るには、iPhoneの通知許可が必要です。', 'You need to allow notifications in iPhone Settings to receive standard alerts.', '要接收普通提醒，需要在 iPhone 设置中允许通知。', []),
    ('manage.openNotificationSettings', '通知の設定を開く', 'Open notification settings', '打开通知设置', []),
    ('manage.liveActivityShowing', 'ロック画面にバスの出発時間を表示しています。', 'The departure time is showing on the Lock Screen.', '正在锁定屏幕上显示巴士出发时间。', []),
    ('manage.endLiveActivity', 'Live Activityを終了', 'End Live Activity', '结束实时活动', []),
    ('manage.noLiveActivity', '表示中のLive Activityはありません。便を選ぶと開始できます。', 'No Live Activity is showing. Choose a service to start one.', '当前没有显示实时活动。选择班次即可开始。', []),
    ('manage.standardSection', '通常の通知', 'Standard alerts', '普通提醒', []),
    ('manage.clearAll', 'すべて解除', 'Clear all', '全部取消', []),
    ('manage.empty', '設定されている通知はありません。', 'No alerts are set.', '没有已设置的提醒。', []),
    ('manage.notificationRow', '通知：%@', 'Alert: %@', '提醒：%@', ['String']),
    ('manage.cancelOne', 'この通知を解除', 'Cancel this alert', '取消该提醒', []),

    # ---- 通知の設定画面 ----
    ('options.title', 'この便をお知らせ', 'Alert for this service', '为该班次提醒', []),
    ('options.targetSection', '対象のバス', 'Selected service', '所选班次', []),
    ('options.intermediateStops', '途中停車：%@', 'Stops at: %@', '途经站点：%@', ['String']),
    ('options.standardSection', '通常の通知', 'Standard alert', '普通提醒', []),
    ('options.currentSetting', '現在の設定：%@', 'Current setting: %@', '当前设置：%@', ['String']),
    ('options.onlyOnePerBus', '同じ便の通知は1件だけ設定できます。選び直すと通知時刻が変更されます。', 'Only one alert can be set per service. Choosing again changes the alert time.', '同一班次只能设置一个提醒。重新选择将更改提醒时间。', []),
    ('options.notPermitted', '通知が許可されていません。', 'Notifications are not allowed.', '未允许通知。', []),
    ('options.allowInSettings', 'iPhoneの設定で通知を許可する', 'Allow notifications in iPhone Settings', '在 iPhone 设置中允许通知', []),
    ('options.timetableCaveat', 'この通知は時刻表の予定時刻を基準にしています。遅延や運休は自動では反映されません。', 'This alert is based on the published timetable. Delays and cancellations are not reflected automatically.', '该提醒以时刻表的预定时间为准，不会自动反映延误和停运。', []),
    ('options.minutesBefore', '%lld分前に通知', '%lld min before', '提前%lld分钟提醒', ['Int']),
    ('options.notificationTime', '通知時刻：%@', 'Alert time: %@', '提醒时间：%@', ['String']),
    ('options.notAvailable', 'この便では設定できません', 'Not available for this service', '该班次无法设置', []),
    ('options.liveActivityDescription', 'ロック画面やDynamic Islandで、出発までの時間を確認できます。', 'See the time until departure on the Lock Screen and Dynamic Island.', '可在锁定屏幕和灵动岛上查看距离出发的时间。', []),
    ('options.liveActivityUnavailable', 'この端末では利用できないか、iPhoneの設定でLive Activityがオフになっています。', 'Not available on this device, or Live Activities are turned off in iPhone Settings.', '本设备不支持，或已在 iPhone 设置中关闭实时活动。', []),
    ('options.autoStartOff', 'アプリの設定で自動表示がオフです。必要なときは下のボタンから開始できます。', 'Automatic display is off in the app settings. You can start it with the button below.', '已在应用设置中关闭自动显示。需要时可通过下方按钮启动。', []),
    ('options.existingAlertKept', '設定済みの%lld分前通知も、そのまま届きます。', 'Your existing %lld-minute alert will still arrive.', '已设置的提前%lld分钟提醒仍会送达。', ['Int']),
    ('options.autoStartDescription', '通常の通知を設定すると、Live Activityも自動で開始します。下のボタンから始める場合は5分前通知も一緒に設定します。', 'Setting a standard alert also starts a Live Activity. Using the button below also sets a 5-minute alert.', '设置普通提醒时会自动启动实时活动。通过下方按钮启动时会同时设置提前5分钟的提醒。', []),
    ('options.endThisDisplay', 'この便の表示を終了', 'End display for this service', '结束该班次的显示', []),
    ('options.startWithAlert', '5分前通知とLive Activityを開始', 'Start a 5-minute alert and Live Activity', '设置提前5分钟提醒并启动实时活动', []),
    ('options.startKeepingAlert', 'Live Activityを開始（通知は継続）', 'Start Live Activity (keep the alert)', '启动实时活动（保留提醒）', []),
    ('options.otherBusShowing', '別の便をLive Activityで表示中です。先に管理画面から終了してください。', 'A Live Activity for another service is showing. Please end it from the management screen first.', '正在显示其他班次的实时活动。请先在管理界面结束。', []),

    # ---- 時刻表タブ ----
    ('timetable.title', '時刻表', 'Timetable', '时刻表', []),
    ('timetable.serviceNoticeTitle', '本日の運行', "Today's service", '今日运行', []),
    ('timetable.emptyTitle', '時刻表がありません', 'No timetable', '没有时刻表', []),
    ('timetable.emptyMessage', 'ホームタブで出発地と目的地を選び直してください', 'Choose the stops again on the Home tab', '请在首页标签页重新选择出发地和目的地', []),
    ('timetable.serviceCount', '%lld便', '%lld services', '%lld个班次', ['Int']),
    ('timetable.routeHint', '経路を変えるときは、ホームタブで出発地と目的地を選んでください', 'To change the route, choose the stops on the Home tab', '要更改路线，请在首页标签页选择出发地和目的地', []),
    ('timetable.notificationHintTitle', '時刻をタップすると通知できます', 'Tap a time to set an alert', '轻点时刻即可设置提醒', []),
    ('timetable.notificationHintBody', '選んだ便が出発する前にお知らせします。設定した時刻は色が変わります。', 'You will be alerted before the service departs. Times with an alert change colour.', '将在所选班次出发前通知您。已设置的时刻会变色。', []),
    ('timetable.hourAccessibility', '%lld時台', "%lld o'clock", '%lld点时段', ['Int']),
    ('timetable.legendScheduled', '色のついた時刻は通知を設定済みです', 'Coloured times have an alert set', '带颜色的时刻已设置提醒', []),
    ('timetable.legendNote', '点の付いた便はお買い物便や経由便です', 'A dot marks a shopping service or a service with a detour', '带点的班次为购物班次或经由班次', []),
    ('timetable.cellAccessibility', '%1$@発、%2$@着', 'Departs %1$@, arrives %2$@', '%1$@出发，%2$@到达', ['String', 'String']),
    ('timetable.cellScheduled', '、通知設定済み', ', alert set', '，已设置提醒', []),
    ('timetable.cellDeparted', '、出発済み', ', departed', '，已出发', []),

    # ---- 設定画面 ----
    ('settings.title', '設定', 'Settings', '设置', []),
    ('settings.appearanceSection', '画面の色', 'Appearance', '界面颜色', []),
    ('settings.appearanceTitle', '時刻に合わせて変わります', 'Changes with the time of day', '随时间变化', []),
    ('settings.appearanceDescription', '朝は明るい空、夕方は夕焼け、夜は星空へと背景がゆっくり変化します。太陽と月の位置も現在時刻に合わせて動きます。', 'The background shifts slowly from a bright morning sky to sunset and then a starry night. The sun and moon move with the current time too.', '背景会从明亮的清晨天空缓缓变为晚霞，再变为星空。太阳和月亮的位置也随当前时间移动。', []),
    ('settings.weatherNotice', '海浜幕張駅の周辺で雨が降っているときは、背景にも雨が降ります。天気の情報は Open-Meteo から取得しています。', 'When it is raining near 海浜幕張駅, rain appears in the background too. Weather data comes from Open-Meteo.', '当海浜幕張駅附近下雨时，背景中也会下雨。天气信息来自 Open-Meteo。', []),
    ('settings.previewMorning', '朝', 'Morning', '早晨', []),
    ('settings.previewNoon', '昼', 'Midday', '白天', []),
    ('settings.previewEvening', '夕', 'Evening', '傍晚', []),
    ('settings.previewNight', '夜', 'Night', '夜晚', []),
    ('settings.previewAccessibility', '朝、昼、夕方、夜の背景の見本', 'Samples of the morning, midday, evening and night backgrounds', '早晨、白天、傍晚和夜晚的背景示例', []),
    ('settings.cardOpacitySection', 'カードの濃さ', 'Card opacity', '卡片浓度', []),
    ('settings.cardOpacityDescription', '背景の風景がどれだけ透けるかを選べます。', 'Choose how much of the background shows through.', '可以选择背景景色的透出程度。', []),
    ('settings.cardOpacityLight', 'うすい', 'Light', '浅', []),
    ('settings.cardOpacityDense', 'こい', 'Dense', '浓', []),
    ('settings.cardOpacityNotice', '時刻表のように文字が詰まった画面は、ここより少し濃く表示されます', 'Dense screens such as the timetable are shown a little darker than this', '像时刻表这样文字密集的界面会比此处稍浓一些', []),
    ('settings.notificationsSection', 'バスのお知らせ', 'Bus alerts', '巴士提醒', []),
    ('settings.liveActivityToggle', 'Live Activityを使う', 'Use Live Activities', '使用实时活动', []),
    ('settings.liveActivityDescription', '通常の通知と一緒に、ロック画面やDynamic Islandへ残り時間を表示します。', 'Shows the time remaining on the Lock Screen and Dynamic Island alongside the standard alert.', '在普通提醒之外，于锁定屏幕和灵动岛上显示剩余时间。', []),
    ('settings.liveActivityAvailable', '対応端末では最初からオンです。ここでいつでも変更できます。', 'On supported devices this is on by default. You can change it here at any time.', '在支持的设备上默认开启。可随时在此更改。', []),

    # ---- チュートリアル ----
    ('tutorial.section', 'はじめに', 'Getting started', '开始使用', []),
    ('tutorial.closeAccessibility', '使い方を閉じる', 'Close the guide', '关闭使用说明', []),
    ('tutorial.start', 'はじめる', 'Get started', '开始使用', []),
    ('tutorial.next', '次へ', 'Next', '下一步', []),
    ('tutorial.page1Title', 'バスの時間を、\nもっと気持ちよく', 'A nicer way to\ncatch your bus', '让乘车时间\n更加舒心', []),
    ('tutorial.page1Description', '必要な便だけを、見やすいカードで確認できます。', 'See just the services you need on clear, readable cards.', '只需在清晰易读的卡片上查看所需班次。', []),
    ('tutorial.page2Title', '今すぐ乗れる便を\nすばやく検索', 'Find the next\nservice quickly', '快速查找\n现在能乘坐的班次', []),
    ('tutorial.page2Description', 'ルートと時刻を選んで、次のバスを見つけましょう。', 'Choose a route and a time to find your next bus.', '选择路线和时间，找到下一班车。', []),
    ('tutorial.page3Title', '乗り遅れを\nそっと防止', "A gentle nudge\nso you don't miss it", '轻声提醒\n避免错过', []),
    ('tutorial.page3Description', 'ベルから通知やLive Activityを設定できます。', 'Use the bell to set an alert or a Live Activity.', '可通过铃铛设置提醒或实时活动。', []),

    # ---- 天気 ----
    ('weather.invalidURL', '天気情報の取得先を組み立てられませんでした。', 'The weather request could not be built.', '无法构建天气信息的请求地址。', []),
    ('weather.requestFailed', '天気情報を取得できませんでした。通信状態を確認してください。', 'The weather could not be fetched. Please check your connection.', '无法获取天气信息。请检查网络连接。', []),
    ('weather.decodingFailed', '天気情報の形式を解釈できませんでした。', 'The weather response could not be read.', '无法解析天气信息的格式。', []),

    # ---- 時刻表タブ ----
    ('timetable.cannotNotifyHint', '運休日のため通知は設定できません', 'No service today, so alerts cannot be set', '今日停运，无法设置提醒', []),

    # ---- いつのバス（運行日と時刻） ----
    ('when.serviceDayTodayName', '今日', 'Today', '今天', []),
    ('when.serviceDayOtherWeekdayName', '他の平日', 'Other weekday', '其他工作日', []),

    # ---- ホーム画面のヘッダー ----
    ('home.brandName', 'コロンブスシティ', 'コロンブスシティ', 'コロンブスシティ', []),

    # ---- Live Activityの残り時間 ----
    ('remaining.departed', '出発済み', 'Departed', '已出发', []),
    ('remaining.lessThanMinute', '1分未満', 'Under 1 min', '不到1分钟', []),
    ('remaining.minutes', '%lld分', '%lld min', '%lld分钟', ['Int']),
    ('remaining.hours', '%lld時間', '%lld hr', '%lld小时', ['Int']),
    ('remaining.hoursMinutes', '%1$lld時間%2$lld分', '%1$lld hr %2$lld min', '%1$lld小时%2$lld分钟', ['Int', 'Int']),

    # ---- ウィジェット ----
    ('widget.untilDeparture', '出発まで', 'Until departure', '距出发', []),
    ('widget.departedShort', '出発済', 'Departed', '已出发', []),
    ('widget.displayName', '次のバス', 'Next Bus', '下一班车', []),
    ('widget.description', '次とその次のバスを表示します', 'Shows the next two departures', '显示接下来两班车', []),
    ('widget.nextLabel', '次', 'Next', '下一班', []),
    ('widget.followingLabel', 'その次', 'Then', '再下一班', []),
    ('widget.noService', '便が見つかりません', 'No departures found', '未找到班次', []),

    # ---- バスの備考 ----
    ('busNote.shopping', 'お買い物便', 'Shopping service', '购物班次', []),
    ('busNote.viaYokado', 'ヨーカドー経由', 'Via ヨーカドー前', '经由ヨーカドー前', []),
    ('busNote.viaStation', '海浜幕張駅経由', 'Via 海浜幕張駅', '经由海浜幕張駅', []),
]

ENTRIES += [
    ("timetable.legendScheduledMark", "ベルの印が付いた時刻は通知を設定済みです", "Times marked with a bell have an alert set", "带铃铛标记的时刻已设置提醒", []),
    ("timetable.legendRecommendedMark", "破線で囲まれた便は検索条件に合う便です", "Services with a dashed outline match your search", "虚线框内的班次符合搜索条件", []),
]

ENTRIES += [
    ("result.earlierTitle", "ひとつ前の便", "Earlier service", "更早的班次", []),
]
