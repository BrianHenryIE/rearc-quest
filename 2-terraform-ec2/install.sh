#!/bin/bash
# EC2 user_data for Amazon Linux 2023 (x86_64). Runs once, as root, at first boot.
# Output is logged to /var/log/cloud-init-output.log.
set -euxo pipefail

QUEST_SHA=5c09447dc0b3dfd4cfb90871bfc43ee50410ef83 # same commit as the rearc-quest submodule
APP_DIR=/opt/quest

dnf update -y
dnf install -y nodejs24 nodejs24-npm git

# Clone App from GitHub, pinned
useradd --system --home-dir "$APP_DIR" --shell /sbin/nologin quest
git clone https://github.com/rearc/quest.git "$APP_DIR"
git -C "$APP_DIR" checkout "$QUEST_SHA"
cd "$APP_DIR"
npm install --omit=dev
chown -R quest:quest "$APP_DIR"

# Run the webserver as a service. It listens on :3000, defined in rearc-quest/src/000.js:4
cat > /etc/systemd/system/quest.service <<EOF
[Unit]
Description=Rearc quest
After=network-online.target
Wants=network-online.target

[Service]
User=quest
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/node src/000.js # matching rearc-quest/package.json:7
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now quest
