# hr0101.devの時刻表API配備

公開先: `https://bus-api.hr0101.dev/api/v1`。既存ポートフォリオはCloudFrontのまま、APIだけ別のLightsailインスタンスに配備する。

## 想定構成

東京リージョンのUbuntu、512MB、IPv6専用Lightsailを第一候補とする。2026-10-09確認時の基本料金は月額3.50米ドル（税・バックアップ・転送超過は別）。CloudflareでAPIのAAAAレコードをプロキシ有効にし、利用者のIPv4/IPv6接続を受ける。IPv6専用インスタンスの作成可否・外向き通信・512MBでの実行は実機で検証してから公開完了とする。

- APIは1 workerのFastAPI + SQLite。DBとCaddyの証明書を名前付きボリュームに保存。
- Caddyが80/443で受け、HTTPS証明書を自動取得・更新。APIの8000番は外部に公開しない。
- コンテナにメモリ上限・ログ容量上限を設ける。512MBなのでDockerビルド時は1GBのswapを用意する。
- 管理者キーをアプリ、Git、Lightsailのuser-dataには入れない。

## ホスト準備

UbuntuにDocker EngineとCompose pluginをインストールする。インスタンスのファイアウォールでIPv6のTCP 80/443を許可し、SSHは管理用の接続元に限定する。IPv4付きプランを使う場合はAレコードと固定IPを使用する。

IPv6専用ホストからDocker Hub、GitHub、パッケージ取得先に到達できるかを確認する。到達できない場合はAWS側のIPv6接続設定を確認し、解決するまで配備を進めない。

IPv6専用の場合、DockerのコンテナからもIPv6で外向き通信できるようにネットワークを設定する。CaddyのACME接続とDockerビルド中のpip取得を確認する。GitHub等にIPv6で到達できない場合は、手元でソースを取得してSSHで転送する。

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

1. AAAAレコード `bus-api` にLightsailのIPv6アドレスを指定。証明書の初回取得時はDNS onlyにして疎通確認する。この段階の確認端末はIPv6接続が必要。
2. Caddyの証明書取得完了後、`bus-api`のみプロキシを有効化する。既存の`@`、`www`、ACM検証レコードは変更しない。
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

単一のDBファイルを稼働中に直接コピーするとWALを取りこぼす。定期実行と別の保存先への退避を公開時に設定する。インスタンスのsnapshotも有料のため予算に含める。

## アプリ設定

HTTPSでの公開確認後に`BusTimeApp-Info.plist`の`TimetableAPIBaseURL`を`https://bus-api.hr0101.dev/api/v1`へ変更する。サーバー未稼働の段階では既定値を変更しない。

参考:
- https://aws.amazon.com/lightsail/pricing/
- https://developers.cloudflare.com/network/ipv6-compatibility/
- https://caddyserver.com/docs/automatic-https
