# 6時間目：WireGuardデモ＋まとめ

テーマ：VPNを起動／停止した瞬間、ネットワークに何が現れ、消えるか。

構成（Dockerで2役を再現）:

```
外側ネットワーク 10.20.0.0/24
├── wg-client  eth0: 10.20.0.10   wg0: 10.10.0.2（up後）
└── wg-server  eth0: 10.20.0.20   wg0: 10.10.0.1
                └── 内部Web (10.10.0.1:8000 … VPN内IPにバインド)

VPN内ネットワーク 10.10.0.0/24（WireGuardが作る）
```

鍵・設定は Step 1 の setup-keys.sh で作る。
受講者は**設定を読み、up/downの前後を観察**します。

**前提**: 手元のマシン（WSL / Raspberry Pi）に wireguard-tools が入っていること
（カーネルモジュールはUbuntu 22.04+なら標準装備）。

---

## Step 1. 準備（初回1回だけ）

```bash
cd ~/security-lab/files/wireguard

# 鍵ペア2組と wg0.conf を生成
bash setup-keys.sh

# 設定ファイルを読んでおく（5時間目の語彙で読める）
cat server/wg0.conf
cat client/wg0.conf
```

✅ 確認: `[Interface]`（自分の秘密鍵・VPN内IP）と
`[Peer]`（相手の公開鍵・AllowedIPs・Endpoint）が読める。

## Step 2. 2つのコンテナを起動する

```bash
docker compose up -d
docker ps
```

✅ 確認: `wg-server` と `wg-client` が `Up`。
（初回はaptインストールが走るため、1〜2分待ってから次へ）

```bash
# サーバー側がVPNを張れたか確認
docker exec wg-server wg show
```

✅ 確認: `interface: wg0` と `listening port: 51820` が表示される。

## Step 3. VPN OFF の状態を確認する（クライアント側）

```bash
docker exec wg-client ip -br addr
docker exec wg-client ip route
docker exec wg-client ping -c 3 -W 2 10.10.0.1
```

✅ 確認:

- `ip -br addr` に **wg0 は存在しない**（lo と eth0 のみ）
- `ip route` に 10.10.0.0/24 の経路は**ない**
- ping は**失敗する**（`100% packet loss` と表示され、応答が1つも返らない）
  （コンテナには既定の経路 `default via 10.20.0.1` があるので、ping は外側へ出ていくが、10.10.0.1 はどこにもいないので返事が来ない）

ここが起点。「仮想NICも経路も、相手への道もない」状態。

## Step 4. VPNを起動する（up）

```bash
docker exec wg-client wg-quick up wg0
```

✅ 確認: 次のようなログが流れる。
```
[#] ip link add wg0 type wireguard
[#] wg setconf wg0 /dev/fd/63
[#] ip -4 address add 10.10.0.2/24 dev wg0
[#] ip link set mtu 1420 up dev wg0
```
（10.10.0.0/24 の経路は、`10.10.0.2/24` というアドレスを付けた時点で自動で追加される。そのため route add の行は出ない）

もう一度同じ3コマンドで観察:

```bash
docker exec wg-client ip -br addr
docker exec wg-client ip route
docker exec wg-client ping -c 3 10.10.0.1
```

✅ 確認:

- `wg0` が現れ、`10.10.0.2/24` が付いている
- `ip route` に `10.10.0.0/24 dev wg0 proto kernel scope link src 10.10.0.2` が**追加されている**
- ping 10.10.0.1 が**通る**

```bash
# VPN経由で内部Webにも到達できる
docker exec wg-client curl -s http://10.10.0.1:8000/
```

✅ 確認: `VPN Internal Service` のHTMLが返る。

⚠️ 区別: `10.10.0.1` はVPN内IP（wg0側）、`10.20.0.20` は外側NICのIP。
pingやcurlは**VPN内IP宛**に打つ。

## Step 5. 外側から見るとUDP 51820しか見えない

【ターミナル1】サーバー側の外側NICを観察:

```bash
# -it を付けると、Ctrl+C で tcpdump を止められる
docker exec -it wg-server tcpdump -i eth0 -nn 'udp port 51820'
```

【ターミナル2】並行して通信を発生させる:

```bash
docker exec wg-client ping -c 3 10.10.0.1
docker exec wg-client curl -s http://10.10.0.1:8000/ > /dev/null
```

✅ 確認（ターミナル1）:

- `10.20.0.10.xxxxx > 10.20.0.20.51820: UDP, length ...` の行だけが流れる
- ICMP(ping)もHTTPも**UDPのカプセルに包まれて**見えない
- 中身は暗号化されたバイト並び（`token=vpn-demo-7c2e` は現れない）

確認できたら Ctrl+C。

## Step 6. VPNを停止する（down）

```bash
docker exec wg-client wg-quick down wg0

docker exec wg-client ip -br addr
docker exec wg-client ip route
docker exec wg-client ping -c 3 -W 2 10.10.0.1
```

✅ 確認:

- wg0 が**消えている**
- 10.10.0.0/24 の経路が**消えている**
- ping が再び**失敗する**

**upで開き、downで閉じる。** 仮想NICと経路がトグルで現れ、消える。
これがVPNの動作の本質。

## Step 7. 後片付け

```bash
docker compose down
```

---

## 第8回のまとめ

```
通信を見る（tcpdumpで平文HTTPが読める）
    ↓
暗号化を見る（HTTPS/SSHは中身が読めない。メタ情報は残る）
    ↓
SSHトンネル（安全な通信路に別のTCPを1本通す）
    ↓
踏み台シナリオ（内部管理画面へトンネル経由でだけ届く）
    ↓
VPN（発想をポート単位からネットワーク単位へ拡張）
    ↓
WireGuard（up/downで仮想NICと経路が現れ、消える）
```

## 今日わかったこと

- WireGuardのupで仮想NICと経路が追加され、downで消える
- Peer認証は第7回の公開鍵暗号そのもの
- 外側から見えるのはUDP 51820だけ。中身は保護される
- 「VPNが安全」と「VPN終端後のサービスが安全」は別問題

**最重要**: SSHトンネル・VPN・WireGuardは別々の用語ではなく、
**安全なトンネルを作り、その中に通信を通す**という
共通の考え方である。
