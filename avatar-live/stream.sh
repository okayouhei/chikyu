#!/usr/bin/env bash
# 仮想ディスプレイ+仮想音声デバイスでアバターを描画し、RTMP で TikTok LIVE に送出する。
# 必要: Xvfb, ffmpeg, pulseaudio, node(playwright), VOICEVOX ENGINE(起動済み)
# 環境変数: TIKTOK_RTMP_URL（サーバーURL）, TIKTOK_STREAM_KEY（ストリームキー）
set -euo pipefail
: "${TIKTOK_RTMP_URL:?TikTok LIVE Studio 等で発行したサーバーURLを設定してください}"
: "${TIKTOK_STREAM_KEY:?ストリームキーを設定してください}"
cd "$(dirname "$0")"

export DISPLAY=:99
rm -f /tmp/.X99-lock
Xvfb :99 -screen 0 720x1280x24 -nolisten tcp &
pulseaudio --start --exit-idle-time=-1
pactl list short sinks | grep -q live_sink || pactl load-module module-null-sink sink_name=live_sink >/dev/null

node live.mjs &
sleep 5   # ブラウザ描画を待つ

ffmpeg -loglevel warning \
  -f x11grab -framerate 30 -video_size 720x1280 -i :99 \
  -f pulse -i live_sink.monitor \
  -c:v libx264 -preset veryfast -b:v 2500k -maxrate 2500k -bufsize 5000k -g 60 -pix_fmt yuv420p \
  -c:a aac -b:a 128k -ar 44100 \
  -f flv "${TIKTOK_RTMP_URL%/}/${TIKTOK_STREAM_KEY}"
