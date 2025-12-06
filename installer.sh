#!/bin/sh

# ===============================
# SKRIP INSTALASI NODOGSPLASH 
# ===============================

# Konfigurasi URL GitHub
GITHUB_RAW="https://raw.githubusercontent.com/tokektv/nodogsplash/refs/heads/main/"
SPLASH_URL="$GITHUB_RAW/splash.html"
CONFIG_URL="$GITHUB_RAW/nodogsplash"
MACLIST_URL="$GITHUB_RAW/maclist.txt"
INIT_URL="$GITHUB_RAW/init.d/nodogsplash"
FALLBACK_MODE=0

echo "[1] UPDATE DAN INSTALASI PAKET"
opkg update
opkg install vsftpd nodogsplash wget

echo "[2] DOWNLOAD FILE DARI GITHUB"
mkdir -p /etc/nodogsplash/htdocs

# Fungsi untuk menangani download
download_file() {
  echo "Mengunduh $1..."
  if wget -q --spider "$1"; then
    if wget -O "$2" "$1"; then
      echo "✅ Berhasil mengunduh"
      return 0
    fi
  fi
  echo "❌ Gagal mengunduh"
  return 1
}

# Download file init.d
wget -O /etc/init.d/nodogsplash "$INIT_URL" || {
     echo "Error: Gagal download" >&2
     exit 1
   }
chmod +x /etc/init.d/nodogsplash

# Download splash.html
if ! download_file "$SPLASH_URL" "/etc/nodogsplash/htdocs/splash.html"; then
  cat > /etc/nodogsplash/htdocs/splash.html << 'EOL'
<!DOCTYPE html>
<html>
<head>
    <title>Hotspot Login</title>
    <meta http-equiv="refresh" content="5;url=$authaction?tok=$tok&redir=$redir">
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
    </style>
</head>
<body>
    <h1>Selamat Datang</h1>
    <p>Anda akan otomatis terhubung dalam 5 detik...</p>
</body>
</html>
EOL
  FALLBACK_MODE=1
fi

# Download config
if ! download_file "$CONFIG_URL" "/etc/config/nodogsplash"; then
  cat > /etc/config/nodogsplash << 'EOL'
config nodogsplash
    option enabled '1'
    option gatewayinterface 'br-lan'
    option gatewayname 'OpenWRT-Hotspot'
    option splashpage 'splash.html'
    option htmlpath '/etc/nodogsplash/htdocs'
    option clientforcetimeout '3'
    option authentication 'true'
    option redirecturl 'http://www.google.com'
    option macfilter 'allow'
    option allowedmaclistfile '/etc/nodogsplash/allowed_macs.txt'
EOL
  FALLBACK_MODE=1
fi

# Download TRUSHTED MAC
mkdir -p /etc/nodogsplash
if ! download_file "$MACLIST_URL" "/etc/nodogsplash/trusted_macs.txt"; then
  cat > /etc/nodogsplash/trusted_macs.txt << 'EOL'
AA:BB:CC:DD:EE:FF
11:22:33:44:55:66
EOL
  FALLBACK_MODE=1
fi

# Set permission
chown nobody:nogroup /etc/nodogsplash/htdocs/splash.html
chmod 644 /etc/nodogsplash/htdocs/splash.html

echo "[4] KONFIGURASI FIREWALL UNTUK WAN/WWAN"
# Backup firewall
cp /etc/config/firewall /etc/config/firewall.backup

# Rules untuk akses manajemen
uci add firewall rule
uci set firewall.@rule[-1].name='MANAGEMENT-WAN'
uci set firewall.@rule[-1].src='wan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='21 22 80 443'
uci set firewall.@rule[-1].target='ACCEPT'

uci add firewall rule
uci set firewall.@rule[-1].name='MANAGEMENT-WWAN'
uci set firewall.@rule[-1].src='wwan'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].dest_port='21 22 80 443'
uci set firewall.@rule[-1].target='ACCEPT'

# Jadwalkan update tiap 6 jam
(crontab -l 2>/dev/null; echo "0 */6 * * * wget -O /etc/nodogsplash/trusted_macs.txt https://raw.githubusercontent.com/tokektv/nodogsplash/refs/heads/main/maclist.txt
") | crontab -

echo "[5] RESTART SERVICE"
/etc/init.d/firewall restart
/etc/init.d/nodogsplash restart

# Hasil instalasi
cat <<EOF

===============================================
INSTALASI BERHASIL!
-----------------------------------------------
Fitur yang aktif:
1. NoDogSplash dengan:
   - splash.html: $(if [ $FALLBACK_MODE -eq 0 ]; then echo "GitHub"; else echo "Lokal"; fi)
   - config: $(if [ $FALLBACK_MODE -eq 0 ]; then echo "GitHub"; else echo "Lokal"; fi)
2. MAC TRUSHTED MAC:
   - Sumber: $(if [ $FALLBACK_MODE -eq 0 ]; then echo "GitHub"; else echo "Lokal"; fi)
   - Auto-update tiap 6 jam
3. Firewall:
   - Port 22,80,443 terbuka untuk WAN/WWAN

Daftar MAC yang diizinkan:
$(cat /etc/nodogsplash/trusted_macs.txt)

Akses hotspot:
- http://$(uci get network.lan.ipaddr):2050
===============================================
EOF
