#!/bin/bash
# WireGuardデモの鍵生成と wg0.conf 作成（初回に1回だけ実行）
# 実行場所: このスクリプトのあるディレクトリ
# 必要: wireguard-tools（wgコマンド）
set -eu
cd "$(dirname "$0")"

mkdir -p server client

# --- 鍵ペアを2組生成 ---
SERVER_PRIV=$(wg genkey)
SERVER_PUB=$(echo "$SERVER_PRIV" | wg pubkey)
CLIENT_PRIV=$(wg genkey)
CLIENT_PUB=$(echo "$CLIENT_PRIV" | wg pubkey)

# --- サーバー側 wg0.conf ---
cat > server/wg0.conf <<EOF
[Interface]
PrivateKey = $SERVER_PRIV
Address    = 10.10.0.1/24
ListenPort = 51820

[Peer]
PublicKey  = $CLIENT_PUB
AllowedIPs = 10.10.0.2/32
EOF

# --- クライアント側 wg0.conf ---
cat > client/wg0.conf <<EOF
[Interface]
PrivateKey = $CLIENT_PRIV
Address    = 10.10.0.2/24

[Peer]
PublicKey  = $SERVER_PUB
AllowedIPs = 10.10.0.0/24
Endpoint   = 10.20.0.20:51820
PersistentKeepalive = 25
EOF

chmod 600 server/wg0.conf client/wg0.conf

echo "生成しました:"
echo "  server/wg0.conf (Address 10.10.0.1, ListenPort 51820)"
echo "  client/wg0.conf (Address 10.10.0.2, Endpoint 10.20.0.20:51820)"
echo
echo "次: docker compose up -d"
