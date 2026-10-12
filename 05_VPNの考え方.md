# 5時間目：SSHトンネルからVPNへ

テーマ：全部の通信をトンネルにしたくなったら？

この時間は講義中心です。手を動かすのは
「鍵ペアの生成」と「設定ファイルの読解」だけ。

---

## Step 0. 発想の拡張

- SSHトンネル: **ある1本のTCP**を暗号化された通信路に乗せる
- VPN: **ネットワーク全体（IP経路ごと）**を暗号化された通信路に乗せる

「全く別物」ではない。どちらも
**安全な通信路に別の通信を通す**という同じ考え方で、
違うのは「運ぶ単位」。

## Step 1. SSHトンネル vs VPN 比較表

| 比較軸 | SSHトンネル(-L) | VPN(WireGuard) |
|---|---|---|
| 運ぶ単位 | 1本のTCPポート | 経路（サブネット）全体 |
| 仮想NIC | 作らない | wg0 などが現れる |
| ルーティング | 経路表には触らない | 経路表に経路が追加される |
| 導入コスト | sshがあれば1行 | 鍵ペア・アドレス設計が必要 |
| 通信の形 | TCP 22番の中に包む | UDP 51820にIPパケットをカプセル化 |

## Step 2. VPNの5つの言葉

1. **仮想NIC（wg0）** … OSにもう1枚のNICとして見える
2. **トンネル** … IPパケットをUDPで包み直す経路
3. **ルーティング** … どの宛先を仮想NICへ流すかをOSに教える
4. **Peer** … VPNの両端。**公開鍵**で識別する
5. **VPN内IP** … 仮想NICに振る、外とは別のIP帯（例: 10.10.0.0/24）

## Step 3. 【ハンズオン】WireGuardの鍵ペアを作ってみる

第7回で学んだ「秘密鍵・公開鍵」がここで再登場します。

```bash
# wireguard-tools が必要（未導入なら sudo apt install -y wireguard-tools）
mkdir -p ~/security-lab/wg-keys
cd ~/security-lab/wg-keys

# 秘密鍵を作り、そこから公開鍵を導出する
# umask 077 で、秘密鍵ファイルを自分だけが読める権限で作る
(umask 077; wg genkey | tee privatekey | wg pubkey > publickey)

cat publickey
```

✅ 確認: 44文字のBase64文字列（公開鍵）が表示される。
SSH鍵・証明書のときと同じ「鍵ペア」の構図
（秘密鍵は自分だけが持ち、公開鍵を相手に渡す）。

⚠️ `privatekey` は第7回同様、表示しない・渡さない。

## Step 4. 【読解】wg0.conf を読めるようになる

```ini
[Interface]
PrivateKey = <自分の秘密鍵>
Address    = 10.10.0.2/24
ListenPort = 51820

[Peer]
PublicKey  = <相手の公開鍵>
AllowedIPs = 10.10.0.1/32
Endpoint   = <相手の外側IP>:51820
```

| 項目 | 意味 |
|---|---|
| PrivateKey | 自分の秘密鍵 |
| Address | VPN内の自分のIP（仮想NICに振られる） |
| ListenPort | 待ち受けるUDPポート（既定51820） |
| PublicKey | **相手**の公開鍵（Peerの識別＝認証） |
| AllowedIPs | このPeerへ送ってよい／このPeerから来てよいIP帯 |
| Endpoint | 相手の外側IPアドレスとポート |

Peer認証に使われているのは、第7回で学んだ公開鍵暗号
（WireGuardではCurve25519鍵ペア）。CAも証明書も使わず、
**互いの公開鍵を登録し合うだけ**で相手を識別する。

---

## 今日わかったこと

- SSHトンネルとVPNは別物ではなく、「運ぶ単位」が違うだけ
- VPNは仮想NICとルーティングでネットワークごとつなぐ
- WireGuardのPeer認証は第7回の公開鍵暗号そのもの

## でも、まだ残る問い

> VPNを起動した瞬間、ネットワークには何が起きる？
> → 6時間目「WireGuardデモ」へ
