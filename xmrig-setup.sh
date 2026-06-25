#!/bin/bash
# ====================================
# XMRig Auto Setup Script
# Monero Mining - MoneroOcean Pool
# ====================================

WALLET="86x3NzP4UrjijYTNeffh1ERK812jt9bXK8SQVGp9LMYvZhgxsiK3HuYTvAELGigtyGWDmniWxjGMgNXiEfUi826G6tvxVF9"
POOL="gulf.moneroocean.stream:10128"
WORKER=$(hostname)
THREADS=$(nproc)
INSTALL_DIR="/opt/xmrig"

echo "======================================"
echo " XMRig Mining Setup"
echo " Worker: $WORKER"
echo " Threads: $THREADS"
echo " Pool: $POOL"
echo "======================================"

# تثبيت المتطلبات
echo "[*] Installing dependencies..."
apt-get update -qq
apt-get install -y -qq wget tar libhwloc-dev

# إنشاء مجلد التثبيت
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# تحميل أحدث نسخة من XMRig
echo "[*] Downloading XMRig..."
XMRIG_VERSION="6.22.2"
wget -q "https://github.com/xmrig/xmrig/releases/download/v${XMRIG_VERSION}/xmrig-${XMRIG_VERSION}-linux-static-x64.tar.gz" -O xmrig.tar.gz

if [ ! -f xmrig.tar.gz ]; then
    echo "[!] Download failed!"
    exit 1
fi

tar -xzf xmrig.tar.gz --strip-components=1
rm xmrig.tar.gz
chmod +x xmrig

echo "[*] Creating config..."
cat > $INSTALL_DIR/config.json << EOF
{
    "autosave": true,
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "hw-aes": null,
        "priority": 2,
        "max-threads-hint": 100
    },
    "pools": [
        {
            "url": "$POOL",
            "user": "$WALLET",
            "pass": "$WORKER",
            "algo": null,
            "tls": false,
            "keepalive": true,
            "nicehash": false
        }
    ]
}
EOF

# إنشاء systemd service
echo "[*] Creating systemd service..."
cat > /etc/systemd/system/xmrig.service << EOF
[Unit]
Description=XMRig Monero Miner
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/xmrig --config=$INSTALL_DIR/config.json
Restart=always
RestartSec=10
User=root
Nice=10

[Install]
WantedBy=multi-user.target
EOF

# تفعيل وتشغيل الـ service
echo "[*] Starting XMRig service..."
systemctl daemon-reload
systemctl enable xmrig
systemctl start xmrig

# انتظر ثواني وتحقق
sleep 5

if systemctl is-active --quiet xmrig; then
    echo ""
    echo "======================================"
    echo " ✅ XMRig is running successfully!"
    echo " Worker: $WORKER"
    echo " Threads: $THREADS CPU threads"
    echo " Check stats: https://moneroocean.stream/#/dashboard?hash=$WALLET"
    echo "======================================"
else
    echo "[!] Service failed to start. Check logs:"
    journalctl -u xmrig -n 20
fi
