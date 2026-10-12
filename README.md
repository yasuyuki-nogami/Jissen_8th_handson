# 第8回ハンズオン：セキュア通信・ネットワーク

このディレクトリは、第8回（6時間）のハンズオンを
**上から順にコマンドを実行すればなぞれる**ように作成したコマンド集です。

## ファイル構成

```
第8回ハンズオン/
├── README.md               … このファイル
├── 01_通信を見る.md
├── 02_暗号化通信を見る.md
├── 03_SSHトンネル.md
├── 04_SSHトンネル応用.md
├── 05_VPNの考え方.md
├── 06_WireGuardデモ.md
└── files/
    └── wireguard/
        ├── docker-compose.yml  … WireGuardデモ用の2コンテナ
        ├── setup-keys.sh       … 鍵生成と設定ファイル作成（初回1回）
        ├── server/             … サーバー側 wg0.conf（setup-keys.shが生成）
        ├── client/             … クライアント側 wg0.conf（同上）
        └── internal/index.html … VPN内側のWebコンテンツ
```

## 前提環境

- Ubuntu 22.04 / 24.04 の Linux VM（一般ユーザー + sudo可）
- インストール済みであること:
  - openssh-client / openssh-server（sshdが起動していること）
  - docker（`docker compose` が使えること）
  - curl / tcpdump
  - wireguard-tools（5時間目で使用。`sudo apt install -y wireguard-tools`）
- ホストPC（Windows）に Wireshark（1時間目のGUI確認用。任意）
- **VM側で80/443/8000/8080番ポートが空いていること**

## 【重要】第7回の演習環境が残っていること

2時間目は**第7回で構築したHTTPS環境をそのまま使います**。
以下の3点が揃っていることを事前に確認してください。

1. Docker Nginx一式: `~/crypto-handson/files/nginx`
2. CA署名済み証明書: `files/nginx/ssl/server.crt` / `server.key`
3. CA証明書の信頼ストア登録済み

確認コマンド:

```bash
cd ~/crypto-handson/files/nginx
docker compose up -d
curl https://localhost/
```

HTMLが返れば（証明書エラーが出なければ）OK。
エラーになる場合は、**第7回の `05_証明書とPKI.md` の Part B**
（CA構築→証明書発行→信頼ストア登録）を先に実施してください。

また、3・4時間目のSSH接続は第7回2時間目で設定した
公開鍵認証（`ssh localhost` がパスワードなしで通る状態）を利用します。

## 進め方

- 各MDファイルの先頭から順にコマンドを実行してください。
- 複数ターミナルを使う手順が多くあります。
  各コマンドの前の「ターミナル1/2/3」の表記に従ってください。
- 作業ディレクトリは `~/security-lab/` 配下を使います。
- 6時間目は `files/wireguard/` を使用します。
  事前にVMへこのディレクトリ一式をコピーしておいてください。

## 注意（改行コード）

WindowsからVMへコピーした場合はCRLF除去を実施:

```bash
find ~/security-lab/files -type f \( -name '*.sh' -o -name '*.conf' -o -name '*.yml' \) \
  -exec sed -i 's/\r$//' {} + 2>/dev/null
```

## 注意（tcpdumpの扱い）

- tcpdumpで観測するのは**自分のVM内の通信だけ**です。
  他人の通信を無断で観測することは不正行為になり得ます。
- 演習で見える token 等はすべてダミー値です。
