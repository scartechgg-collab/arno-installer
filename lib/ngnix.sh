# ============================================================================
#  ARNO Installer - Nginx Configuration
# ============================================================================

nginx_install() {
    ui_print_step "Installing Nginx..."
    if util_is_debian_family; then
        arno_run_spinner "Installing Nginx" pkg_install nginx
    elif util_is_rhel_family; then
        arno_run_spinner "Installing Nginx" pkg_install nginx
        arno_run_spinner "Enabling nginx in firewalld" firewall-cmd --permanent --add-service=http
        arno_run_spinner "Reloading firewalld" firewall-cmd --reload
    fi
    arno_run_spinner "Enabling Nginx" systemctl enable --now nginx
    ui_print_success "Nginx Installed"
}

nginx_remove_default() {
    if [[ -f /etc/nginx/sites-enabled/default ]]; then
        rm -f /etc/nginx/sites-enabled/default
        arno_log "Removed default nginx site"
    fi
    if [[ -f /etc/nginx/conf.d/default.conf ]]; then
        rm -f /etc/nginx/conf.d/default.conf
        arno_log "Removed default nginx conf"
    fi
}

nginx_ensure_dirs() {
    mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled
    # Ensure sites-enabled is included in nginx.conf
    if ! grep -q "sites-enabled" /etc/nginx/nginx.conf; then
        sed -i '/http {/a\\tinclude /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
    fi
}

nginx_write_config() {
    local domain="$1"
    local use_ssl="${2:-false}"
    local conf_file="/etc/nginx/sites-available/${domain}.conf"

    if [[ "$use_ssl" == "true" ]]; then
        cat > "$conf_file" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${domain};
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${domain};

    root /var/www/pterodactyl/public;
    index index.php index.html index.htm index.default.php;

    ssl_certificate /etc/letsencrypt/live/${domain}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${domain}/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers on;

    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Frame-Options DENY;
    add_header Referrer-Policy "same-origin";

    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 300;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    gzip on;
    gzip_comp_level 5;
    gzip_min_length 256;
    gzip_proxied any;
    gzip_vary on;
    gzip_types
        application/atom+xml
        application/javascript
        application/json
        application/ld+json
        application/manifest+json
        application/rss+xml
        application/vnd.geo+json
        application/vnd.ms-fontobject
        application/x-font-ttf
        application/x-web-app-manifest+json
        application/xhtml+xml
        application/xml
        font/opentype
        image/bmp
        image/svg+xml
        image/x-icon
        text/cache-manifest
        text/css
        text/plain
        text/vcard
        text/vnd.rim.location.xloc
        text/vtt
        text/x-component
        text/x-cross-domain-policy;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
    else
        cat > "$conf_file" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${domain};

    root /var/www/pterodactyl/public;
    index index.php index.html index.htm index.default.php;

    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 300;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    gzip on;
    gzip_comp_level 5;
    gzip_min_length 256;
    gzip_proxied any;
    gzip_vary on;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
    fi

    ln -sf "$conf_file" "/etc/nginx/sites-enabled/${domain}.conf"
    arno_log "Nginx config written for $domain (ssl=$use_ssl)"
}

nginx_test_config() {
    if nginx -t &>/dev/null; then
        return 0
    fi
    return 1
}

nginx_reload() {
    if nginx_test_config; then
        arno_run systemctl reload nginx
        return 0
    else
        arno_log "Nginx config test failed"
        return 1
    fi
}

nginx_running() {
    util_service_active nginx
}
