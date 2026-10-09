# hr0101.devの時刻表API配備

公開先: `https://bus-api.hr0101.dev/api/v1`。既存ポートフォリオはCloudFrontのまま、APIだけ別のLightsailインスタンスに配備する。

## 想定構成

シドニー（ap-southeast-2）のUbuntu 24.04、512MB、IPv6専用Lightsailを使用する。2026-10-09確認時の基本料金は月額3.50米ドル（税・バックアップ・転送超過は別）。CloudflareでAPIのAAAAレコードをプロキシ有効にし、利用者のIPv4/IPv6接続を受ける。配布ファイルは非公開S3バケットから期限付きURLで取得する。S3保存・リクエストには少額の従量料金がかかる。

- APIは1 workerのFastAPI + SQLite。DBとCaddyの証明書を名前付きボリュームに保存。
- Caddyが80/443で受け、HTTPS証明書を自動取得・更新。APIの8000番は外部に公開しない。Caddy側のgzipはETagを変えるため使用せず、304応答を実際の公開URLで検証する。
- コンテナにメモリ上限・ログ容量上限を設ける。512MBなのでDockerビルド時は1GBのswapを用意する。
- 管理者キーをアプリ、Git、Lightsailのuser-dataには入れない。

## ホスト準備

UbuntuにDocker EngineとCompose pluginをインストールする。インスタンスのファイアウォールでIPv6のTCP 80/443を許可し、IPv6専用インスタンスでブラウザSSHを使用するには、AWSの仕様によりSSHの接続元を「Any IPv6 address」にする必要がある。SSHは鍵認証を使用する。IPv4付きプランを使う場合はAレコードと固定IPを使用する。

IPv6専用ホストからDocker Hub、GitHub、パッケージ取得先に到達できるかを確認する。到達できない場合はAWS側のIPv6接続設定を確認し、解決するまで配備を進めない。

このcomposeではLinuxのhostネットワークを使用し、APIを127.0.0.1:8000に限定する。Dockerビルドもhostネットワークを使用する。CaddyのACME接続とDockerビルド中のpip取得を確認する。GitHub等にIPv6で到達できない場合は、手元でBackendをtar.gzにし、非公開S3にアップロードしてdualstackエンドポイントの署名付きURLで転送する。

SSH先でリポジトリを配置し、リポジトリのルートディレクトリから実行:

```sh
cp Backend/deploy/.env.example Backend/deploy/.env
chmod 600 Backend/deploy/.env
python3 - <<'PY'
from pathlib import Path
import secrets
p = Path('Backend/deploy/.env')
s = p.read_text()
assert '\nADMIN_API_KEY=\n' in s
p.write_text(s.replace('\nADMIN_API_KEY=\n', '\nADMIN_API_KEY=' + secrets.token_urlsafe(48) + '\n'))
PY
# docker composeへ渡す環境変数とAPIコンテナ内のキーは同じ.envから読む。
docker compose --env-file Backend/deploy/.env -f Backend/deploy/compose.yaml up -d --build
```

キーは`.env`内でのみ生成・保存する。必要時にSSHで取得してパスワードマネージャーに登録する。

## Cloudflare DNSとTLS

1. AAAAレコード `bus-api` にLightsailのIPv6アドレスを指定し、プロキシを有効にする。CaddyのHTTP認証チャレンジにはTCP 80も必要。
2. Caddyの証明書取得完了をログで確認する。既存の`@`、ACM検証レコードは変更しない。
3. CloudflareのSSL/TLSはFull (strict)とする。ドメイン全体の既存設定に影響する場合はAPIホストに限定した設定を使用する。
4. APIや管理画面にCache Everything等の独自キャッシュ規則を適用しない。APIのETag再検証・予約公開を維持する。
5. IPv4とIPv6の双方からhealthとroutesが200になることを確認する。

```sh
curl -fsS https://bus-api.hr0101.dev/health
curl -fsS https://bus-api.hr0101.dev/api/v1/routes
```

管理画面は`https://bus-api.hr0101.dev/admin`。ページの閲覧は公開、データの変更は`X-Admin-Key`認証。追加のアクセス制限をCloudflare Access等で設ける場合は、アプリが使うGET APIを対話ログインの対象にしない。

## 更新・バックアップ

コード更新後に同じcomposeの`up -d --build`を実行する。DBボリュームは保持する。`down -v`はDBと証明書を削除するため実行しない。

DBのバックアップはSQLite backup APIを使う。例えばホストにバックアップ用フォルダを作り、稼働中のコンテナで以下を実行してからファイルをホストへコピーする:

```sh
mkdir -p backups
chmod 700 backups
docker compose --env-file Backend/deploy/.env -f Backend/deploy/compose.yaml exec -T api python -c "import sqlite3; src=sqlite3.connect('/data/timetable.sqlite3'); dst=sqlite3.connect('/data/backup.sqlite3'); src.backup(dst); dst.close(); src.close()"
docker compose --env-file Backend/deploy/.env -f Backend/deploy/compose.yaml cp api:/data/backup.sqlite3 backups/timetable.sqlite3
```

単一のDBファイルを稼働中に直接コピーするとWALを取りこぼす。`backup.sh`をrootのcronで毎日実行し、7日分をホストに保持する。ホスト内バックアップはインスタンス障害・削除に備えられないため、更新前などに非公開S3へ手動退避する。インスタンスのsnapshotも有料のため予算に含める。

## アプリ設定

HTTPSでの公開確認後に`BusTimeApp-Info.plist`の`TimetableAPIBaseURL`を`https://bus-api.hr0101.dev/api/v1`へ変更する。サーバー未稼働の段階では既定値を変更しない。

参考:
- https://aws.amazon.com/lightsail/pricing/
- https://developers.cloudflare.com/network/ipv6-compatibility/
- https://caddyserver.com/docs/automatic-https

日次バックアップ設定（ホスト上）:

```sh
chmod 700 /opt/bustime/Backend/deploy/backup.sh
printf "%s\n" "17 18 * * * root /opt/bustime/Backend/deploy/backup.sh >> /var/log/bustime-backup.log 2>&1" > /etc/cron.d/bustime-backup
```

2026-10-09の配備確認: Lightsail `bustime-api`、5路線・115便、health 200、ETag条件付きGET 304、管理APIの認証なしアクセス401。バックアップはホスト内7日保持。
