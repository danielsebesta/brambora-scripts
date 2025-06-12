#!/bin/bash
set -e

clear

cat << "EOF"

 ___                _                  ___      _             
| _ )_ _ __ _ _ __ | |__  ___ _ _ __ _/ __| ___| |_ _  _ _ __ 
| _ \ '_/ _` | '  \| '_ \/ _ \ '_/ _` \__ \/ -_)  _| || | '_ \
|___/_| \__,_|_|_|_|_.__/\___/_| \__,_|___/\___|\__|\_,_| .__/
                                                        |_|   

🥔 Vitej u BramboraSetup – univerzalni setup pro chude VPS (1 CPU, 1 GB RAM)

EOF

echo "------------------------------------------------------------"

# 🛰️ Aktualizace systemu
echo "🔄 Aktualizuji system..."
apt update && apt upgrade -y

# 🧰 Zakladni nastroje
echo "🧰 Instaluji zakladni nastroje..."
apt install -y curl wget git unzip software-properties-common ca-certificates lsb-release gnupg ufw

# 🌐 Zjisteni nebo vyber webserveru
echo "🌐 Detekuji webserver..."
if command -v nginx >/dev/null 2>&1; then
    webserver="nginx"
elif command -v apache2 >/dev/null 2>&1; then
    webserver="apache2"
else
    echo "❓ Neni nainstalovan zadny webserver."
    echo "Chces nainstalovat Nginx nebo Apache2? (nginx/apache2)"
    read -r webserver
    if [ "$webserver" = "nginx" ]; then
        echo "📦 Instaluji Nginx..."
        apt install -y nginx
        systemctl enable nginx
    elif [ "$webserver" = "apache2" ]; then
        echo "📦 Instaluji Apache2..."
        apt install -y apache2
        systemctl enable apache2
    else
        echo "❌ Neplatny vyber. Ukonceno."
        exit 1
    fi
fi

# 🐘 Instalace PHP
echo "🐘 Pridavam PPA pro nejnovejsi PHP..."
add-apt-repository ppa:ondrej/php -y
apt update

echo "🐘 Instaluji PHP a zakladni rozsireni..."
apt install -y php php-cli php-fpm php-curl php-mysql php-xml php-mbstring php-zip php-gd php-bcmath

# 🛡️ Fail2Ban
echo "🛡️  Instaluji Fail2Ban..."
apt install -y fail2ban
systemctl enable fail2ban

# 🔐 UFW firewall
echo "🔐 Nastavuji UFW (firewall)..."
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 8080/tcp
ufw --force enable

# 🐳 Docker + Docker Compose
echo "🐳 Instaluji Docker a docker-compose plugin..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable docker
usermod -aG docker "$USER"

# 🔄 Automaticke aktualizace
echo "🔄 Instalace a aktivace automatickych aktualizaci..."
apt install -y unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades

# 🧠 EarlyOOM – zabraneni zamrznuti
echo "🧠 Instalace earlyoom (prevence pri malo RAM)..."
apt install -y earlyoom
systemctl enable --now earlyoom

# 📊 htop – monitoring
echo "📊 Instalace htop..."
apt install -y htop

# 🛡️ Extra Apache moduly (pokud Apache2)
if [ "$webserver" = "apache2" ]; then
    echo "🧱 Instalace mod-evasive a mod-security pro Apache2..."
    apt install -y libapache2-mod-evasive libapache2-mod-security2
    echo "🧰 Aktivace modulu..."
    a2enmod evasive security2
    systemctl restart apache2
fi

# 🧹 Cron job pro uklid pameti
echo "🧹 Pridavam cron job pro denni uklid pameti (drop_caches)..."
echo '0 4 * * * root sync; echo 3 > /proc/sys/vm/drop_caches' | tee /etc/cron.d/clearcache

echo "✅ BramboraSetup dokonceno! System je pripraven na dalsi krok 🚀"
echo "Mozna se budes muset odhlasit a znovu prihlasit kvuli skupine 'docker'."
