# ちきゅうちゃん 自動ライブ配信

団体名にちなんだオリジナルの地球キャラ「ちきゅうちゃん」が、台本を読み上げながら口パクし、TikTok LIVE に自動配信するための一式です。

- `avatar.html` … アバター本体（SVG）。`setMouth(0..1)` / `setCaption(text)` で操作。`avatar.html?demo` で単体デモ
- `script.json` … 読み上げる台本（ループ再生）
- `live.mjs` … VOICEVOX で音声合成 → 音量に合わせて口パク → 仮想音声デバイスへ再生
- `stream.sh` … Xvfb + PulseAudio + ffmpeg で RTMP 送出

## 必要なもの
Linux（Xvfb, ffmpeg, pulseaudio）、Node.js、`npm i && npx playwright install chromium`、VOICEVOX ENGINE（`:50021` で起動）

## 実行
```
export TIKTOK_RTMP_URL=rtmp://...   # TikTok LIVE の「サーバーURL」
export TIKTOK_STREAM_KEY=...        # 「ストリームキー」
./stream.sh
```

## 注意
- TikTok でストリームキー（RTMP）を発行するには、アカウントの LIVE 配信資格（年齢・フォロワー数など）が必要です。キーは配信ごとに変わるため、毎回 TikTok LIVE Studio で取得してください。**キーは絶対にコミットしないでください。**
- 24時間運用するなら、パソコンではなくクラウドの常時起動Linux（VPS）での実行がおすすめです。パソコンを使う場合は BIOS で Wake-on-LAN を有効にし、起動時に `stream.sh` が走るよう設定します。
- TikTok のガイドライン上、自動配信でも内容の責任は配信者にあります。台本の内容を確認してください。

## VPS で動かす（推奨）
Ubuntu 22.04/24.04、2vCPU・4GB RAM 以上（映像エンコードがあるため）を想定。
```
git clone <このリポジトリ> && cd chikyu/avatar-live
sudo bash setup-vps.sh
sudo nano /etc/avatar-live.env          # TIKTOK_RTMP_URL / TIKTOK_STREAM_KEY を入力
sudo systemctl enable --now avatar-live # 起動＆再起動時も自動起動
journalctl -u avatar-live -f            # ログ
sudo systemctl stop avatar-live         # 配信停止
```
`/etc/avatar-live.env` は root のみ読めます。リポジトリには置かないでください。
