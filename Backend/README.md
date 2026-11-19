# 時刻表DB・API・管理画面

SQLiteの永続DBとFastAPIで5経路・115便を管理します。初回起動時だけ`seed.json`を取り込みます。再起動時は既存DBを維持します。アプリ内の元ダイヤはAPI未設定・取得失敗時の初期フォールバックとして残します。

## ローカルで起動

リポジトリのルートで実行します。Python 3.12を使用します。

```sh
python3 -m venv .venv
.venv/bin/pip install -r Backend/requirements.lock
# ランダムな管理者キーを生成し、同じターミナルで起動。キーはログに出しません。
export ADMIN_API_KEY="$(.venv/bin/python -c 'import secrets; print(secrets.token_urlsafe(48))')"
export TIMETABLE_DB_PATH="$PWD/data/timetable.sqlite3"
.venv/bin/uvicorn Backend.main:app --host 127.0.0.1 --port 8000
```

`http://localhost:8000/admin`を開き、生成したキーを入力します。キーはパスワードマネージャーなどで管理してください。キー未設定では読み取りだけが有効で、全変更APIは503を返します。設定するキーは32文字以上が必要です。`/docs`、`/redoc`、`/openapi.json`は公開しません。

管理画面では経路とダイヤを選び、便を追加・編集・削除できます。変更内容を確認して即時公開または日時指定で予約公開します。運休・臨時運行は「運行日・臨時ダイヤ・運休」で設定します。指定日のダイヤが通常ダイヤに優先し、同じ種類では優先度が高い設定を使用します。有効期間は両端を含みます。指定日に運休を設定すれば通常便も運休になります。予約公開は公開日時以降の最初の読み取りで適用されます。予約後にデータが変わり適用できなくなった場合は予約一覧に失敗を表示し、他の予約の処理は続行します。

CSV書き出しは全便、取り込みはIDによる追加・更新です。CSVから消した便は削除されません。時刻は4:00〜翌4:00の運行日内で増加する必要があります。停留所の順番と出発・到着を含めて検証します。取り込み・一括編集は全件成功時だけ確定します。

## アプリへの接続

`BusTimeApp-Info.plist`の`TimetableAPIBaseURL`に、運用するHTTPSのAPIルート（例 `https://bus.example.jp/api/v1`）を設定してビルドします。空欄のままなら元の同梱ダイヤを使用します。管理者キーをアプリへ組み込む必要はありません。

DebugビルドのシミュレーターではLaunch Argumentsに次の2項目を指定できます。

```
TimetableAPIBaseURL
http://localhost:8000/api/v1
```

本番ビルドはHTTPSのみを受け付けます。ローカル接続のATS許可はローカルホストに限定しています。起動・フォアグラウンド復帰時、アプリは経路一覧をETag付きで再確認し、変更された経路のみ差分を取得します。削除された便も反映し、全経路の検証が成功してから画面へ適用します。臨時ダイヤを翌日へ繰り返しません。APIを接続したアプリ本体が対象で、ウィジェット・ショートカットは同梱ダイヤを使います。永続キャッシュ・接続状態表示については下の「iOSのオフラインキャッシュ」を参照してください。

公開エンドポイントは読み取り専用です。

| Method / path (`/api/v1`配下) | 内容 |
|---|---|
| GET `/routes`, `/stops` | 経路・停留所一覧 |
| GET `/timetables/{route_id}` | 全便・ダイヤ・版番号 |
| GET `/timetables/{route_id}/changes?since_version=1` | 更新便・削除ID・ダイヤ設定 |
| POST `/timetables` | 便を追加 |
| PUT / DELETE `/timetables/{id}` | 便の変更・削除 |
| PUT `/schedules/{id}` | 運行日設定を追加・変更 |
| POST `/admin/preview`, `/admin/batch` | 一括変更のプレビュー・確定 |
| GET / POST `/admin/publications` | 予約一覧・予約登録 |
| GET `/admin/export.csv` | 全便を書き出し |
| POST `/admin/import.csv?preview=true` | CSVプレビュー（falseで確定） |

変更APIと`/admin`配下のデータAPIには`X-Admin-Key`が必要です。公開レスポンスは`schema_version=1`と経路単位の`version`を持ちます。ETag一致なら304で本文を省略します。差分は最終状態へ集約し、`upserts`と`deleted_ids`で返します。ダイヤ設定は小さいため常に全件を返します。`since_version=0`は全現存便を返します。サーバーより先の版を要求した場合は422になるため全取得してください。

## Dockerで運用

```sh
docker build -f Backend/Dockerfile -t bustime-api .
docker volume create bustime-data
docker run -d --name bustime-api --restart unless-stopped \
  --env ADMIN_API_KEY --mount source=bustime-data,target=/data \
  -p 127.0.0.1:8000:8000 bustime-api
```

永続ボリュームはUID 10001で読み書き可能にします（名前付きボリュームは初回のコンテナ所有権を引き継ぎます）。HTTPS終端のリバースプロキシ経由で公開し、管理画面には管理者だけがアクセスできるように運用します。1つのDBは同一ホストのローカルディスク上で使用します。複数ホストでSQLiteファイルを共有しません。DBの定期バックアップにはSQLiteのbackup APIを使ってください。稼働中の`.sqlite3`だけをコピーするとWALの内容を取りこぼします。DBを復元して版が巻き戻った場合、アプリは版の差を検知して全件再取得します。管理者キー変更は環境変数を更新して再起動します。

公開先は`https://bus-api.hr0101.dev/api/v1`です。Info.plistもこのURLを使用します。

## 検証

```sh
.venv/bin/pytest Backend/test_api.py Backend/test_security.py -q
python3 Backend/generate_seed.py
git diff --exit-code Backend/seed.json
```

APIテストは認証、入力検証、CRUD、削除差分、ETag、トランザクション、予約公開、運休、CSV、再起動後の永続性に加え、本文解析前の認証・サイズ制限・回数制限・保護ヘッダーを確認します。iOSの`TimetableRepositoryTests`では初期115便が同梱ダイヤと一致すること、ETag・変更経路だけの取得・削除・画面反映・臨時運休を検証します。

## iOSのオフラインキャッシュ

APIに接続したアプリは、Application Supportの`Timetables/cache-v1.json`へ検証済みデータを原子的に保存します。iOS 16対応のJSONファイル形式で、経路ごとの版番号・名前、運行日設定、便と停留所ID・名前・時刻、ETag、最終確認時刻を1つの版付きエンベロープに保持します。停留所の位置と経路の選択肢は引き続きアプリ内の定義を使用します。再取得できるデータなので端末バックアップからは除外します。

次回起動時は保存したダイヤを即座に表示し、裏でETagと版番号を確認します。ネットワーク未接続時は保存データを使い、通信復帰を`NWPathMonitor`で検出したら同期を再開します。API障害や不正なレスポンスでは正常なキャッシュを維持します。キャッシュの破損・未対応形式・接続先の変更を検出した場合は同梱ダイヤへ戻り、次回同期で全件を取り直します。

ホームと時刻表の両方で接続状態と最終更新を表示し、下へ引くか更新ボタンで手動確認できます。3日以上確認できていない場合は注意を表示します。変更なしの304応答でも正常に最新状態を確認できたため、最終更新時刻を更新します。新しい版を受け取った場合は画面で更新を通知します。初回取得前に通信できない場合は同梱ダイヤを表示し、その旨を案内します。

Debugのシミュレーター検証では`-UITestTimetableOffline`を追加するとネットワーク未接続状態を再現できます。一度APIから取得したあと、同じ接続先でアプリを終了・再起動すれば、保存した便とオフライン表示を確認できます。実機の機内モードでは追加の設定は不要です。

## hr0101.devへの配備準備

Lightsail + Cloudflareで`bus-api.hr0101.dev`を公開するCompose設定と運用・セキュリティ手順は[deploy/README.md](deploy/README.md)を参照してください。
