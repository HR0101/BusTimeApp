# hr0101.devの時刻表API配備

公開先: `https://bus-api.hr0101.dev/api/v1`。既存ポートフォリオはCloudFrontのまま、APIだけ別のLightsailインスタンスに配備する。

## 想定構成

シドニー（ap-southeast-2）のUbuntu 24.04、512MB、IPv6専用Lightsailを使用する。2026-10-09確認時の基本料金は月額3.50米ドル（税・バックアップ・転送超過は別）。CloudflareでAPIのAAAAレコードをプロキシ有効にし、利用者のIPv4/IPv6接続を受ける。配布ファイルは非公開S3バケットから期限付きURLで取得する。S3保存・リクエストには少額の従量料金がかかる。

- APIは1 workerのFastAPI + SQLite。DBとCaddyの証明書を名前付きボリュームに保存。
- Caddyが80/443で受け、HTTPS証明書を自動取得・更新。APIの8000番は外部に公開しない。Caddy側のgzipはETagを変えるため使用せず、304応答を実際の公開URLで検証する。
- コンテナにメモリ上限・ログ容量上限を設ける。512MBなのでDockerビルド時は1GBのswapを用意する。
- 管理者キーをアプリ、Git、Lightsailのuser-dataには入れない。

## ホスト準備

UbuntuにDocker EngineとCompose pluginをインストールする。IPv6のTCP 80/443は[Cloudflareの公開IP範囲](https://www.cloudflare.com/ips-v6/)だけに許可する。IPv6専用インスタンスでブラウザSSHを使用するには、AWSの仕様により作業中だけSSHの接続元を「Any IPv6 address」にする必要がある。SSHは鍵認証を使用し、通常時は22番を閉じる。IPv4付きプランを使う場合はIPv4側にもCloudflareの制限を設ける。

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

コード更新後に同じcomposeの`up -d --build`を実行する。Caddyfileを置き換えた場合は単一ファイルのbind mountを更新するため`up -d --force-recreate caddy`も実行する。DBボリュームは保持する。`down -v`はDBと証明書を削除するため実行しない。

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

## セキュリティ設定と保守

APIはlocalhost限定、80/443はCloudflareからだけ受ける。Cloudflare Full (strict)でオリジンまでHTTPSを検証する。Caddyは信頼済みCloudflare接続の`CF-Connecting-IP`を使い、Uvicornは127.0.0.1のプロキシだけを信頼する。クライアントが送ったIPヘッダーだけで回数制限を回避できない。HTTP-01をCloudflare経由で使用するため80番も維持し、TLS-ALPN-01は無効にする。

本文解析より先に管理キーを確認する。1 IPあたり60秒間で公開リクエスト300件、認証済み管理リクエスト60件、認証失敗10件まで許可し、超過時は`429`と`Retry-After`を返す。認証失敗が上限に達しても正しいキーは使用できる。カウンターはメモリ内で最大2,048 IPずつ保持し、1 workerで運用する。再起動・古いIPの追い出しでカウンターはリセットされる。これは継続的なDDoSや分散攻撃の完全な防御ではない。多数の端末が同じIPを共有する環境では、利用実績を見て上限を調整する。

JSON/CSV本文は2,000,000バイト、ヘッダーは32KBまで。Caddyに読み取りタイムアウトを設定し、API側もContent-Lengthのない本文を制限する。管理画面はCSP、全APIはnosniff・フレーム埋め込み禁止等を使用する。管理データ・エラーは保存しない。HSTSはAPIホストだけに設定する。

APIはUID 10001、read-only root filesystem、Linux capabilitiesを全削除し、権限昇格を禁止する。Caddyもread-onlyとし、bind用の権限だけを残す。必要な書き込みはDB・証明書のボリュームと容量制限付きtmpfsで行う。管理キーは既存のroot所有600の`.env`を使う。Docker/Composeを操作できる管理者はキーへアクセスできるため、ホスト管理権限は限定する。

ホストで`sudo sh /opt/bustime/Backend/deploy/harden-host.sh`を実行し、rootログイン・パスワード認証を無効にする。Ubuntu既定のsecurity対象のunattended-upgradesを毎日有効にする。カーネル等が再起動を要求した場合は`/var/run/reboot-required`を確認して保守時間に再起動する。Dockerイメージも定期的にpull/rebuildする。

S3はBlock Public Accessの全項目とSSE-S3を維持し、[artifacts-bucket-policy.json](artifacts-bucket-policy.json)で非HTTPSを拒否する。AWSサービス自身はネットワーク情報が省略される場合があるため拒否条件から除外する。このポリシーはアクセス権を新しく付与しない。

通常のファイアウォール設定（SSHを閉じる）:

```sh
aws lightsail put-instance-public-ports --instance-name bustime-api \
  --port-infos file://Backend/deploy/cloudflare-ports.json \
  --profile bustime --region ap-southeast-2
```

ブラウザSSHで保守する間だけ次を実行し、完了後に上の設定で閉じる:

```sh
aws lightsail open-instance-public-ports --instance-name bustime-api \
  --port-info '{"fromPort":22,"toPort":22,"protocol":"tcp","cidrs":[],"ipv6Cidrs":["::/0"]}' \
  --profile bustime --region ap-southeast-2
```

CloudflareのIP範囲に変更があれば、Caddyfileとcloudflare-ports.jsonの両方を更新する。接続障害時はファイアウォールだけを全開放する前に、DNSのプロキシ状態・証明書・IP範囲を確認する。これらの強化による追加の月額固定料金は発生しない。
