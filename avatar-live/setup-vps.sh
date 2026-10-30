#!/usr/bin/env bash
# Ubuntu 22.04/24.04 の VPS に、配信に必要なものを一括で入れる。root で実行。
#   sudo bash setup-vps.sh
set -euo pipefail
[ "$(id -u)" = 0 ] || { echo "root で実行してください"; exit 1; }
SRC="$(cd "$(dirname "$0")" && pwd)"

apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y xvfb ffmpeg pulseaudio pulseaudio-utils \
  nodejs npm docker.io fonts-noto-cjk fonts-noto-color-emoji

id live >/dev/null 2>&1 || useradd -m -s /bin/bash live
loginctl enable-linger live            # pulseaudio 用に /run/user/<uid> を常設
usermod -aG audio live

# アプリ一式を配置
install -d -o live -g live /opt/avatar-live
cp -r "$SRC"/. /opt/avatar-live/ && chown -R live:live /opt/avatar-live
sudo -u live bash -c 'cd /opt/avatar-live && npm install --no-audit --no-fund && npx playwright install --with-deps chromium' \
  || { cd /opt/avatar-live && npx playwright install-deps chromium && sudo -u live bash -c 'cd /opt/avatar-live && npx playwright install chromium'; }

# VOICEVOX（音声合成）を Docker で常駐
docker rm -f voicevox >/dev/null 2>&1 || true
docker run -d --name voicevox --restart always -p 127.0.0.1:50021:50021 voicevox/voicevox_engine:cpu-latest

# キー置き場（root だけが読める）
if [ ! -f /etc/avatar-live.env ]; then
  install -m 600 /dev/null /etc/avatar-live.env
  printf 'TIKTOK_RTMP_URL=\nTIKTOK_STREAM_KEY=\n' > /etc/avatar-live.env
fi

cp /opt/avatar-live/avatar-live.service /etc/systemd/system/avatar-live.service
systemctl daemon-reload
echo
echo "完了。次の手順:"
echo "  1) sudo nano /etc/avatar-live.env   # TikTok のサーバーURLとストリームキーを入力"
echo "  2) sudo systemctl enable --now avatar-live"
echo "  3) journalctl -u avatar-live -f     # ログ確認"
