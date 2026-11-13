#!/usr/bin/env bash
# NexyonCloud Installer Core - Premium UI + Real Install

PANEL_DIR="/var/www/pterodactyl"
TZ="Asia/Kolkata"
DOMAIN=""
ADMIN_EMAIL=""
ADMIN_USER=""
ADMIN_PASS=""
DB_NAME="panel"
DB_USER="pterodactyl"
DB_PASS=""
PHP_VERSION=""

die(){ echo; echo "[ERROR] $*" >&2; exit 1; }
pause(){ echo; read -r -p "Press Enter to continue..." _; }
root(){ [[ $EUID -eq 0 ]] || die "Run as root: sudo bash $0"; }
valid_domain(){ [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ ]]; }
valid_email(){ [[ "$1" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; }
secret(){
  local a b c
  a="$(openssl rand -hex 10)"
  b="$(printf '%c' $((65 + $(od -An -N1 -tu1 /dev/urandom) % 26)))"
  c="$(( $(od -An -N1 -tu1 /dev/urandom) % 10 ))"
  printf '%s%s%s' "$b" "$c" "$a"
}

detect_os(){
  . /etc/os-release
  case "$ID:$VERSION_ID" in
    ubuntu:22.04|ubuntu:24.04|debian:11|debian:12|debian:13) ;;
    *) die "Supported: Ubuntu 22.04/24.04 or Debian 11/12/13. Found: $PRETTY_NAME";;
  esac
  if [[ "$ID" == ubuntu ]]; then
    [[ "$VERSION_ID" == 22.04 ]] && PHP_VERSION="8.2" || PHP_VERSION="8.3"
  elif [[ "$VERSION_ID" == 11 ]]; then PHP_VERSION="8.2"
  else PHP_VERSION="8.2"; fi
}

install_deps(){
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y ca-certificates curl gnupg unzip tar nginx mariadb-server redis-server \
    certbot python3-certbot-nginx openssl cron git

  if [[ "$ID" == ubuntu && "$VERSION_ID" == 22.04 ]]; then
    apt-get install -y software-properties-common
    add-apt-repository -y ppa:ondrej/php
    apt-get update
  fi
  if [[ "$ID" == debian && "$VERSION_ID" == 11 ]]; then
    apt-get install -y lsb-release apt-transport-https
    curl -fsSL https://packages.sury.org/php/apt.gpg | gpg --dearmor -o /usr/share/keyrings/sury-php.gpg
    echo "deb [signed-by=/usr/share/keyrings/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" >/etc/apt/sources.list.d/php.list
    apt-get update
  fi

  apt-get install -y "php$PHP_VERSION" "php$PHP_VERSION-cli" "php$PHP_VERSION-common" \
    "php$PHP_VERSION-fpm" "php$PHP_VERSION-gd" "php$PHP_VERSION-mysql" \
    "php$PHP_VERSION-mbstring" "php$PHP_VERSION-bcmath" "php$PHP_VERSION-xml" \
    "php$PHP_VERSION-curl" "php$PHP_VERSION-zip" "php$PHP_VERSION-intl"

  systemctl enable --now mariadb redis-server nginx cron "php$PHP_VERSION-fpm"

  if ! command -v composer >/dev/null 2>&1; then
    curl -fsSL https://getcomposer.org/installer -o /tmp/composer.php
    php /tmp/composer.php --install-dir=/usr/local/bin --filename=composer
    rm -f /tmp/composer.php
  fi
}

input_config(){
  clear
  printf '\033[1;94m'
  cat << "EOF"
               .                                      .o8                          .               oooo  
             .o8                                     "888                        .o8               `888  
oo.ooooo.  .o888oo  .ooooo.  oooo d8b  .ooooo.   .oooo888   .oooo.    .ooooo.  .o888oo oooo    ooo  888  
 888' `88b   888   d88' `88b `888""8P d88' `88b d88' `888  `P  )88b  d88' `"Y8   888    `88.  .8'   888  
 888   888   888   888ooo888  888     888   888 888   888   .oP"888  888         888     `88..8'    888  
 888   888   888 . 888    .o  888     888   888 888   888  d8(  888  888   .o8   888 .    `888'     888  
 888bod8P'   "888" `Y8bod8P' d888b    `Y8bod8P' `Y8bod88P" `Y888""8o `Y8bod8P'   "888"     .8'     o888o 
 888                                                                                   .o..P'            
o888o                                                                                  `Y8P'             
EOF
  printf '\033[0m'
  echo "           PREMIUM PTERODACTYL INSTALLER"
  echo "────────────────────────────────────────────────────────────"

  read -r -p "  • Panel Domain [panel.nobita.indevs.in] " DOMAIN
  DOMAIN="${DOMAIN:-panel.nobita.indevs.in}"
  valid_domain "$DOMAIN" || die "Invalid domain."

  read -r -p "  • Admin Email [admin@gmail.com] " ADMIN_EMAIL
  ADMIN_EMAIL="${ADMIN_EMAIL:-admin@gmail.com}"
  valid_email "$ADMIN_EMAIL" || die "Invalid email."

  read -r -p "  • Admin Username [admin] " ADMIN_USER
  ADMIN_USER="${ADMIN_USER:-admin}"
  [[ "$ADMIN_USER" =~ ^[A-Za-z0-9._-]{3,32}$ ]] || die "Invalid username."

  read -r -s -p "  • Admin Password [admin] " ADMIN_PASS
  echo
  ADMIN_PASS="${ADMIN_PASS:-admin}"
  [[ ${#ADMIN_PASS} -ge 8 ]] || die "Password must be at least 8 characters."

  DB_PASS="$(secret)"

  echo
  echo "  ┌─[ REVIEW CONFIGURATION ]"
  echo "  │ Domain:      $DOMAIN"
  echo "  │ Email:       $ADMIN_EMAIL"
  echo "  │ Username:    $ADMIN_USER"
  echo "  │ Database:    $DB_NAME"
  echo "  │ DB User:     $DB_USER"
  echo "  │ Version:     v1.15.2"
  echo "  │ SSL Type:    Local SSL (Self-Signed)"
  echo "  └────────────────────────────────────"
  echo
  read -r -p "  Start Installation? (y/n): " yes
  [[ "$yes" =~ ^[Yy]$ ]] || return 1
  return 0
}

database(){
  mariadb <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
ALTER USER '$DB_USER'@'127.0.0.1' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
}

panel(){
  rm -rf "$PANEL_DIR"
  mkdir -p "$PANEL_DIR"
  cd "$PANEL_DIR"
  curl -fL --retry 3 -o panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
  tar -xzf panel.tar.gz
  rm panel.tar.gz
  cp .env.example .env
  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader --no-interaction

  php artisan key:generate --force

  php artisan p:environment:setup -n \
    --author="$ADMIN_EMAIL" --url="https://$DOMAIN" --timezone="$TZ" \
    --cache=redis --session=redis --queue=redis \
    --redis-host=127.0.0.1 --redis-port=6379 --redis-pass=""

  php artisan p:environment:database -n \
    --host=127.0.0.1 --port=3306 --database="$DB_NAME" --username="$DB_USER" --password="$DB_PASS"

  php artisan p:environment:mail -n \
    --driver=log --host=127.0.0.1 --port=25 \
    --username=null --password=null --encryption=null \
    --from="$ADMIN_EMAIL"
  sed -i 's/^MAIL_FROM_NAME=.*/MAIL_FROM_NAME="NexyonCloud Pterodactyl"/' .env

  php artisan migrate --seed --force

  php artisan p:user:make \
    --email="$ADMIN_EMAIL" \
    --username="$ADMIN_USER" \
    --name-first="NexyonCloud" \
    --name-last="Admin" \
    --password="$ADMIN_PASS" \
    --admin=1

  chown -R www-data:www-data "$PANEL_DIR"
  chmod -R 755 storage/* bootstrap/cache/* 2>/dev/null || true
}

nginx_config(){
cat >/etc/nginx/sites-available/pterodactyl.conf <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    root $PANEL_DIR/public;
    index index.php;
    client_max_body_size 100m;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php$PHP_VERSION-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht { deny all; }
}
EOF
ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx
}

services(){
cat >/etc/systemd/system/pteroq.service <<EOF
[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service
[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php $PANEL_DIR/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now pteroq
mkdir -p /etc/cron.d
echo "* * * * * www-data /usr/bin/php $PANEL_DIR/artisan schedule:run >> /dev/null 2>&1" >/etc/cron.d/pterodactyl
chmod 644 /etc/cron.d/pterodactyl
}

save(){
  umask 077
  cat >/root/nexyoncloud-pterodactyl-credentials.txt <<EOF
Panel URL: https://$DOMAIN
Admin Email: $ADMIN_EMAIL
Admin Username: $ADMIN_USER
Admin Password: $ADMIN_PASS
Database: $DB_NAME
Database User: $DB_USER
Database Password: $DB_PASS
Timezone: $TZ
APP_KEY:
$(grep '^APP_KEY=' "$PANEL_DIR/.env" || true)
EOF
}

# ==========================================
# USER MANAGEMENT FUNCTIONS (NEW)
# ==========================================

create_user_manual() {
    clear
    echo
    echo "  Custom User Creation"
    echo "  ────────────────────"
    read -r -p "  • Email: " u_email
    valid_email "$u_email" || die "Invalid email."
    read -r -p "  • Username: " u_username
    [[ "$u_username" =~ ^[A-Za-z0-9._-]{3,32}$ ]] || die "Invalid username."
    read -r -p "  • First Name: " u_fname
    read -r -p "  • Last Name: " u_lname
    read -r -s -p "  • Password: " u_pass
    echo
    [[ ${#u_pass} -ge 8 ]] || die "Password must be at least 8 characters."
    
    echo
    read -r -p "  Make this user an Admin? (y/n) [n]: " u_admin
    local is_admin=0
    [[ "$u_admin" =~ ^[Yy]$ ]] && is_admin=1

    echo "  Creating user..."
    cd "$PANEL_DIR"
    if php artisan p:user:make \
        --email="$u_email" \
        --username="$u_username" \
        --name-first="$u_fname" \
        --name-last="$u_lname" \
        --password="$u_pass" \
        --admin="$is_admin"; then
        echo "  [ OK ] User created successfully."
    else
        echo "  [FAIL] Could not create user."
    fi
    pause
}

create_user_auto() {
    clear
    echo
    echo "  Auto Create Admin User"
    echo "  ──────────────────────"
    local auto_email="admin$(date +%s)@example.com"
    local auto_user="admin$(date +%s)"
    local auto_pass="$(secret)"
    
    echo "  Generating random admin details..."
    echo "  Email: $auto_email"
    echo "  Username: $auto_user"
    echo "  Password: $auto_pass"
    echo
    read -r -p "  Proceed with these details? (y/n) [y]: " proceed
    [[ "$proceed" =~ ^[Yy]$ || -z "$proceed" ]] || return 1

    echo "  Creating admin user..."
    cd "$PANEL_DIR"
    if php artisan p:user:make \
        --email="$auto_email" \
        --username="$auto_user" \
        --name-first="Auto" \
        --name-last="Admin" \
        --password="$auto_pass" \
        --admin=1; then
        echo "  [ OK ] Admin user created successfully."
        echo
        echo "  ┌─[ SAVE THESE CREDENTIALS ]"
        echo "  │ Email:    $auto_email"
        echo "  │ Username: $auto_user"
        echo "  │ Password: $auto_pass"
        echo "  └────────────────────────────"
    else
        echo "  [FAIL] Could not create user."
    fi
    pause
}
