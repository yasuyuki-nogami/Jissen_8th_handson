#!/bin/bash
# 第8回ハンズオン 環境準備スクリプト（WSL2 の Ubuntu 22.04 / 24.04 用）
# 前提: 第7回の setup_wsl.sh と、第7回のハンズオン（2時間目の SSH 鍵、5時間目の CA・Nginx）が済んでいること
# 使い方: このリポジトリのフォルダ（files/ がある場所）で
#   bash setup_wsl.sh
set -eu

LAB_DIR="$HOME/security-lab"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

info() { echo -e "\n\033[1;34m[setup] $*\033[0m"; }
warn() { echo -e "\033[1;33m[注意] $*\033[0m"; WARNED=1; }
fail() { echo -e "\033[1;31m[エラー] $*\033[0m"; exit 1; }
WARNED=0

# ---- 0. 前提チェック ----
[ "$(id -u)" -ne 0 ] || fail "root ではなく、普段のユーザーで実行してください（sudo は中で使います）"
. /etc/os-release
[ "${ID:-}" = "ubuntu" ] || fail "Ubuntu 用です（検出: ${PRETTY_NAME:-不明}）"
case "${VERSION_ID:-}" in 22.04|24.04) ;; *) warn "想定外のバージョンです: $PRETTY_NAME（22.04 / 24.04 を推奨）";; esac
grep -qi microsoft /proc/version 2>/dev/null || warn "WSL 以外の環境のようです（そのまま続行します）"
[ -d "$SRC_DIR/files/wireguard" ] || fail "$SRC_DIR/files/wireguard が見つかりません。このリポジトリのフォルダで実行してください"
command -v docker >/dev/null 2>&1 || fail "docker がありません。先に第7回の setup を実行してください"

if [ "$(cat /proc/1/comm 2>/dev/null)" = "systemd" ]; then USE_SYSTEMD=1; else USE_SYSTEMD=0; fi
start_service() {  # $1 = サービス名
  if [ "$USE_SYSTEMD" = 1 ]; then sudo systemctl start "$1"; else sudo service "$1" start; fi
}

info "sudo のパスワードを聞かれたら、自分のユーザーのパスワードを入力してください"
sudo -v

# ---- 1. ツール ----
info "1/5 ツールをインストール（tcpdump / wireguard-tools / python3 / curl / ip / ping）"
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  tcpdump wireguard-tools python3 curl iproute2 iputils-ping openssh-client openssh-server

# ---- 2. SSH と Docker を起動 ----
info "2/5 SSH と Docker を起動"
sudo mkdir -p /run/sshd
start_service ssh >/dev/null 2>&1 || warn "SSH を起動できませんでした"
docker info >/dev/null 2>&1 || start_service docker >/dev/null 2>&1 || true
sleep 2
docker info >/dev/null 2>&1 || fail "docker を sudo なしで使えません。第7回の setup のあと、一度ログインし直しましたか？"

# ---- 3. 第7回の環境が残っているか ----
info "3/5 第7回の環境を確認"
if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new localhost true 2>/dev/null; then
  echo "  OK  ssh localhost が鍵で通る（3・4時間目用）"
else
  warn "ssh localhost が鍵で通りません → 第7回 02_公開鍵暗号とSSH鍵.md の Step 1〜3 をやり直してください"
fi
NGINX_DIR="$HOME/crypto-handson/files/nginx"
if [ -f "$NGINX_DIR/ssl/server.crt" ] && [ -f /usr/local/share/ca-certificates/handson-ca.crt ]; then
  (cd "$NGINX_DIR" && docker compose up -d >/dev/null 2>&1) || true
  sleep 2
  if curl -sf -o /dev/null https://localhost/; then
    echo "  OK  https://localhost/ が証明書エラーなしで開ける（2時間目用）"
  else
    warn "https://localhost/ に -k なしで接続できません → 第7回 05_証明書とPKI.md の Part B をやり直してください"
  fi
else
  warn "第7回の CA 署名済み証明書か信頼ストア登録が見つかりません（後片付けで消した場合も含む）→ 第7回 05_証明書とPKI.md の Part B をやり直してください"
fi

# ---- 4. ハンズオンファイル ----
info "4/5 ハンズオンファイルを $LAB_DIR/files に配置"
mkdir -p "$LAB_DIR"
if [ -d "$LAB_DIR/files" ]; then
  mv "$LAB_DIR/files" "$LAB_DIR/files.bak.$(date +%Y%m%d%H%M%S)"
fi
cp -r "$SRC_DIR/files" "$LAB_DIR/files"
find "$LAB_DIR/files" -type f \( -name '*.sh' -o -name '*.conf' -o -name '*.yml' -o -name '*.html' \) \
  -exec sed -i 's/\r$//' {} +

# 6時間目用のイメージを先に取得（失敗しても当日 docker compose up で自動取得される）
docker pull -q ubuntu:24.04 >/dev/null 2>&1 || warn "ubuntu:24.04 の事前取得に失敗しました（当日の docker compose up で自動取得されます）"

# ---- 5. 確認 ----
info "5/5 確認"
tcpdump --version 2>&1 | head -1
echo "wg: $(command -v wg)"
python3 --version
# WireGuard はコンテナでもホストのカーネルを使うので、カーネルが対応しているか確かめる
sudo modprobe wireguard >/dev/null 2>&1 || true
if sudo ip link add wgcheck0 type wireguard 2>/dev/null; then
  sudo ip link del wgcheck0
  echo "  OK  カーネルが WireGuard に対応（6時間目用）"
else
  warn "このカーネルでは WireGuard の NIC を作れません（uname -r: $(uname -r)）。6時間目は講師のデモを見る形にしてください"
fi
if command -v ss >/dev/null && ss -ltn | grep -qE ':(8000|8080)\s'; then
  warn "8000 / 8080 番ポートを使っているプロセスがあります。1時間目の前に止めてください"
  ss -ltnp 2>/dev/null | grep -E ':(8000|8080)\s' || true
fi

echo
if [ "$WARNED" = 0 ]; then
  echo "==================== 準備完了 ===================="
else
  echo "========== 準備完了（上の [注意] を確認してください） =========="
fi
echo "・ハンズオンの作業場所: $LAB_DIR"
if [ "$USE_SYSTEMD" = 0 ]; then
  echo "・WSL を起動し直したときは: sudo service ssh start; sudo service docker start"
fi
