#!/bin/bash
set -e

# ASCII art BramboraWeb
cat <<'EOF'

 ___                _                __      __   _    
| _ )_ _ __ _ _ __ | |__  ___ _ _ __ \ \    / /__| |__ 
| _ \ '_/ _` | '  \| '_ \/ _ \ '_/ _` \ \/\/ / -_) '_ \
|___/_| \__,_|_|_|_|_.__/\___/_| \__,_|\_/\_/\___|_.__/

EOF

echo "🥔 Vitej u BramboraWeb - jednoduchy nastaveni webserveru (nginx/apache2)"
echo

# Vyber webserveru
echo "💡 Vyber webserver, ktery pouzivas:"
echo "1) nginx"
echo "2) apache2"
while true; do
    read -rp "Zadej cislo [1-2]: " wschoice
    case "$wschoice" in
        1) WEBSERVER="nginx"; break ;;
        2) WEBSERVER="apache2"; break ;;
        *) echo "Neplatna volba, zkus to znovu." ;;
    esac
done

echo
read -rp "Zadej hlavni domenu (napr. example.com): " DOMAIN
while [[ -z "$DOMAIN" ]]; do
    echo "Domena nesmi byt prazdna!"
    read -rp "Zadej hlavni domenu (napr. example.com): " DOMAIN
done

read -rp "Zadej aliasy domeny oddelene carkou (napr. www.example.com,api.example.com), nebo jen ENTER kdyz zadne nejsou: " ALIASES_RAW

# Prevod aliasu na format pro config
ALIASES=""
if [[ -n "$ALIASES_RAW" ]]; then
    IFS=',' read -ra ALIAS_ARRAY <<< "$ALIASES_RAW"
    for a in "${ALIAS_ARRAY[@]}"; do
        ALIASES+=" $(echo "$a" | xargs)" # osetreni mezer
    done
fi

echo
read -rp "Zadej email administratora (pro ServerAdmin a certbot): " ADMIN_EMAIL
while [[ -z "$ADMIN_EMAIL" ]]; do
    echo "Email nesmi byt prazdny!"
    read -rp "Zadej email administratora: " ADMIN_EMAIL
done

echo
echo "Vyber typ webu:"
echo "1) Staticky web (zadani cesty ke slozce)"
echo "2) Reverse proxy (zadani portu na localhost)"
while true; do
    read -rp "Zadej volbu [1-2]: " WEBTYPE
    case "$WEBTYPE" in
        1) break ;;
        2) break ;;
        *) echo "Neplatna volba, zkus to znovu." ;;
    esac
done

if [[ "$WEBTYPE" == "1" ]]; then
    read -rp "Zadej absolutni cestu ke slozce s webem (napr. /var/www/html): " WEBROOT
    while [[ -z "$WEBROOT" ]]; do
        echo "Cesta nesmi byt prazdna!"
        read -rp "Zadej absolutni cestu ke slozce s webem: " WEBROOT
    done

    if [[ ! -d "$WEBROOT" ]]; then
        echo "⚠️ Slozka '$WEBROOT' nebyla nalezena."
        read -rp "Chces ji vytvorit? (a/n): " CREATEFOLDER
        if [[ "$CREATEFOLDER" =~ ^[Aa]$ ]]; then
            echo "Vytvarim slozku '$WEBROOT'..."
            mkdir -p "$WEBROOT"
            echo "<!DOCTYPE html><html><head><title>BramboraWeb</title></head><body><h1>BramboraWeb</h1></body></html>" > "$WEBROOT/index.html"
            echo "✅ Slozka vytvorena a vlozen index.html"
        else
            echo "Musis zadat existujici slozku. Konec."
            exit 1
        fi
    fi
else
    read -rp "Zadej port na localhost, kam ma proxy smerovat (napr. 3000): " PROXYPORT
    while ! [[ "$PROXYPORT" =~ ^[0-9]+$ ]] || [ "$PROXYPORT" -le 0 ] || [ "$PROXYPORT" -gt 65535 ]; do
        echo "Neplatny port, zkus to znovu."
        read -rp "Zadej port na localhost: " PROXYPORT
    done
fi

echo
echo "Chces automaticky vytvorit HTTPS certifikat pres Let's Encrypt? (certbot)"
read -rp "a/n: " CREATE_CERT
CREATE_CERT=${CREATE_CERT,,}

echo
echo "🔧 Vytvarim konfiguraci pro webserver '$WEBSERVER'..."

CONFIG_PATH=""
if [[ "$WEBSERVER" == "nginx" ]]; then
    CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"
    SERVER_NAMES="$DOMAIN$ALIASES"

    if [[ "$WEBTYPE" == "1" ]]; then
        cat > "$CONFIG_PATH" <<EOF
server {
    listen 80;
    server_name $SERVER_NAMES;

    root $WEBROOT;
    index index.html index.htm index.php;

    server_tokens off;
    client_max_body_size 50M;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;

    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
EOF
    else
        cat > "$CONFIG_PATH" <<EOF
server {
    listen 80;
    server_name $SERVER_NAMES;

    location / {
        proxy_pass http://localhost:$PROXYPORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    fi

    ln -sf "$CONFIG_PATH" "/etc/nginx/sites-enabled/$DOMAIN"
    echo "✅ Konfigurace nginx ulozena do $CONFIG_PATH"
    nginx -t
    systemctl reload nginx

elif [[ "$WEBSERVER" == "apache2" ]]; then
    CONFIG_PATH="/etc/apache2/sites-available/$DOMAIN.conf"
    SERVER_ADMIN="webmaster@$DOMAIN"
    if [[ -n "$ADMIN_EMAIL" ]]; then
        SERVER_ADMIN="$ADMIN_EMAIL"
    fi
    SERVER_NAMES="$DOMAIN$ALIASES"

    if [[ "$WEBTYPE" == "1" ]]; then
        cat > "$CONFIG_PATH" <<EOF
<VirtualHost *:80>
    ServerAdmin $SERVER_ADMIN
    ServerName $DOMAIN
EOF
        for a in $ALIASES; do echo "    ServerAlias $a" >> "$CONFIG_PATH"; done
        cat >> "$CONFIG_PATH" <<EOF
    DocumentRoot $WEBROOT

    <Directory $WEBROOT>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
EOF
    else
        cat > "$CONFIG_PATH" <<EOF
<VirtualHost *:80>
    ServerAdmin $SERVER_ADMIN
    ServerName $DOMAIN
EOF
        for a in $ALIASES; do echo "    ServerAlias $a" >> "$CONFIG_PATH"; done
        cat >> "$CONFIG_PATH" <<EOF
    ProxyPreserveHost On
    ProxyRequests Off
    ProxyPass / http://localhost:$PROXYPORT/
    ProxyPassReverse / http://localhost:$PROXYPORT/

    ErrorLog \${APACHE_LOG_DIR}/$DOMAIN-error.log
    CustomLog \${APACHE_LOG_DIR}/$DOMAIN-access.log combined
</VirtualHost>
EOF
    fi

    echo "✅ Konfigurace apache2 ulozena do $CONFIG_PATH"
    a2ensite "$DOMAIN.conf"
    a2enmod proxy proxy_http proxy_balancer proxy_connect proxy_ftp headers rewrite
    systemctl reload apache2
fi

# Certbot - automaticke https
if [[ "$CREATE_CERT" == "a" || "$CREATE_CERT" == "ano" || "$CREATE_CERT" == "y" || "$CREATE_CERT" == "yes" ]]; then
    echo
    echo "🔐 Spoustim certbot pro automaticke ziskani SSL certifikatu..."
    CERTBOT_DOMAINS="-d $DOMAIN"
    for a in $ALIASES; do CERTBOT_DOMAINS+=" -d $a"; done

    if [[ "$WEBSERVER" == "nginx" ]]; then
        certbot --nginx $CERTBOT_DOMAINS --email "$ADMIN_EMAIL" --agree-tos --non-interactive --redirect
    else
        certbot --apache $CERTBOT_DOMAINS --email "$ADMIN_EMAIL" --agree-tos --non-interactive --redirect
    fi
    echo "✅ Certifikaty nainstalovany a nastaveny HTTPS pres redirect."
fi

echo
echo "🎉 Hotovo! Tvoje domena $DOMAIN byla nastavena."
echo "🌐 Otestuj prosim, jestli web funguje podle tveho ocekavani."
