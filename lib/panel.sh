# ============================================================================
#  ARNO Installer - Pterodactyl Panel Installation
# ============================================================================

# Panel configuration collected from wizard
declare -gA ARNO_PANEL_CFG

# ----------------------------------------------------------------------------
# Interactive wizard
# ----------------------------------------------------------------------------
panel_wizard() {
    ui_print_step "Panel Configuration Wizard"
    echo

    local default_domain
    default_domain=$(util_get_public_ip)

    util_read_input ARNO_PANEL_CFG[domain] \
        "Panel Domain (or IP)" "$default_domain"

    util_read_input ARNO_PANEL_CFG[email] \
        "Admin Email" ""

    util_read_input ARNO_PANEL_CFG[username] \
        "Admin Username" "admin"

    util_read_input ARNO_PANEL_CFG[first_name] \
        "First Name" "Admin"

    util_read_input ARNO_PANEL_CFG[last_name] \
        "Last Name" "User"

    util_read_secret ARNO_PANEL_CFG[password] "Admin Password"
    while [[ -z "${ARNO_PANEL_CFG[password]}" ]]; do
        ui_print_warning "Password cannot be empty"
        util_read_secret ARNO_PANEL_CFG[password] "Admin Password"
    done

    util_read_input ARNO_PANEL_CFG[timezone] \
        "Timezone" "UTC"

    util_read_input ARNO_PANEL_CFG[db_pass] \
        "Database Password (blank = auto-generate)" ""
    if [[ -z "${ARNO_PANEL_CFG[db_pass]}" ]]; then
        ARNO_PANEL_CFG[db_pass]=$(util_gen_password 24)
        ui_print_info "Generated database password: ${ARNO_PANEL_CFG[db_pass]}"
    fi

    local ssl_choice
    ssl_choice=$(ui_read_choice "Enable SSL with Let's Encrypt?" "y n")
    ARNO_PANEL_CFG[ssl]=$([[ "$ssl_choice" == "y" ]] && echo "true" || echo "false")

    local fw_choice
    fw_choice=$(ui_read_choice "Configure firewall automatically?" "y n")
    ARNO_PANEL_CFG[firewall]=$([[ "$fw_choice" == "y" ]] && echo "true" || echo "false")

    local telemetry_choice
    telemetry_choice=$(ui_read_choice "Send anonymous telemetry?" "y n")
    ARNO_PANEL_CFG[telemetry]=$([[ "$telemetry_choice" == "y" ]] && echo "true" || echo "false")

    echo
    ui_print_step "Configuration Summary"
    panel_show_summary

    if ! util_confirm "Proceed with installation?" "y"; then
        ui_print_warning "Installation cancelled by user."
        exit 0
    fi
}

panel_show_summary() {
    cat <<EOF
  $(c "$GRAY" "Domain         :") $(c "$WHITE" "${ARNO_PANEL_CFG[domain]}")
  $(c "$GRAY" "Admin Email    :") $(c "$WHITE" "${ARNO_PANEL_CFG[email]}")
  $(c "$GRAY" "Admin Username :") $(c "$WHITE" "${ARNO_PANEL_CFG[username]}")
  $(c "$GRAY" "Admin Name     :") $(c "$WHITE" "${ARNO_PANEL_CFG[first_name]} ${ARNO_PANEL_CFG[last_name]}")
  $(c "$GRAY" "Timezone       :") $(c "$WHITE" "${ARNO_PANEL_CFG[timezone]}")
  $(c "$GRAY" "SSL            :") $(c "$WHITE" "${ARNO_PANEL_CFG[ssl]}")
  $(c "$GRAY" "Firewall       :") $(c "$WHITE" "${ARNO_PANEL_CFG[firewall]}")
  $(c "$GRAY" "Telemetry      :") $(c "$WHITE" "${ARNO_PANEL_CFG[telemetry]}")
  $(c "$GRAY" "DB Password    :") $(c "$YELLOW" "(hidden)")
EOF
}

# ----------------------------------------------------------------------------
# PHP Installation
# ----------------------------------------------------------------------------
panel_install_php() {
    ui_print_step "Installing PHP 8.3 + extensions..."

    if util_is_debian_family; then
        # Add Sury PHP repository for Debian/Ubuntu
        arno_run_spinner "Installing prerequisites" pkg_install \
            ca-certificates lsb-release curl apt-transport-https software-properties-common gnupg

        if [[ ! -f /etc/apt/keyrings/deadsnakes.gpg ]] && [[ ! -f /etc/apt/trusted.gpg.d/sury-php.gpg ]]; then
            local distro
            distro=$(. /etc/os-release && echo "$ID")
            local codename
            codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
            # Use sury repo
            curl -fsSL "https://packages.sury.org/php/apt.gpg" | gpg --dearmor -o /usr/share/keyrings/deb.sury.org-php.gpg 2>/dev/null || true
            if [[ ! -f /etc/apt/sources.list.d/sury-php.list ]]; then
                echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $codename main" \
                    > /etc/apt/sources.list.d/sury-php.list
            fi
            arno_run apt-get update -y
        fi

        arno_run_spinner "Installing PHP 8.3 + extensions" pkg_install \
            php8.3 php8.3-{cli,fpm,gd,mbstring,bcmath,xml,curl,zip,intl,mysql,bz2,sqlite3,redis,imagick} \
            composer

    elif util_is_rhel_family; then
        # Install Remi repo
        if ! rpm -q epel-release &>/dev/null; then
            arno_run dnf install -y epel-release
        fi
        if ! rpm -q remi-release &>/dev/null; then
            arno_run dnf install -y "https://rpms.remirepo.net/enterprise/remi-release-$(rpm -E %rhel).rpm"
        fi
        arno_run dnf module reset -y php
        arno_run dnf module enable -y php:remi-8.3
        arno_run_spinner "Installing PHP 8.3 + extensions" pkg_install \
            php php-{cli,fpm,gd,mbstring,bcmath,xml,curl,zip,intl,mysqlnd,bz2,pdo,redis,pecl-imagick} \
            composer
    fi

    ui_print_success "PHP 8.3 Installed"
}

panel_install_dependencies() {
    ui_print_step "Installing system dependencies..."
    if util_is_debian_family; then
        arno_run_spinner "Installing deps" pkg_install \
            git curl wget zip unzip tar cron git \
            nginx redis-server mariadb-server \
            fail2ban ca-certificates
    elif util_is_rhel_family; then
        arno_run_spinner "Installing deps" pkg_install \
            git curl wget zip unzip tar cronie git \
            nginx redis mariadb-server \
            fail2ban ca-certificates policycoreutils-python-utils
    fi
    ui_print_success "Dependencies Installed"
}

# ----------------------------------------------------------------------------
# Download Panel
# ----------------------------------------------------------------------------
panel_download() {
    ui_print_step "Downloading Pterodactyl Panel..."
    mkdir -p /var/www/pterodactyl

    if [[ -d /var/www/pterodactyl/.git ]]; then
        ui_print_warning "Panel directory exists, pulling latest..."
        arno_run git -C /var/www/pterodactyl pull
    else
        arno_run_spinner "Cloning Pterodactyl repository" \
            git clone -b develop https://github.com/pterodactyl/panel.git /var/www/pterodactyl
    fi
    ui_print_success "Panel Downloaded"
}

# ----------------------------------------------------------------------------
# Composer install
# ----------------------------------------------------------------------------
panel_composer_install() {
    ui_print_step "Installing Composer dependencies..."
    cd /var/www/pterodactyl
    arno_run_spinner "Running composer install" \
        composer install --no-dev --optimize-autoloader
    cd - >/dev/null
    ui_print_success "Composer dependencies installed"
}

# ----------------------------------------------------------------------------
# Environment configuration
# ----------------------------------------------------------------------------
panel_configure_env() {
    ui_print_step "Configuring environment..."
    cd /var/www/pterodactyl

    if [[ ! -f .env ]]; then
        cp .env.example .env
    fi

    # Generate app key
    local app_key
    app_key=$(php artisan key:generate --force --show 2>/dev/null || php -r "echo Illuminate\Support\Str::random(32);" 2>/dev/null || util_gen_token 32)

    # Build DB URL
    local db_url="mysql://${DB_USER}:${DB_PASS}@127.0.0.1:3306/${DB_NAME}"

    # Configure .env
    arno_run sed -i "s|^APP_URL=.*|APP_URL=https://${ARNO_PANEL_CFG[domain]}|" .env
    arno_run sed -i "s|^APP_TIMEZONE=.*|APP_TIMEZONE=${ARNO_PANEL_CFG[timezone]}|" .env
    arno_run sed -i "s|^DB_HOST=.*|DB_HOST=127.0.0.1|" .env
    arno_run sed -i "s|^DB_DATABASE=.*|DB_DATABASE=${DB_NAME}|" .env
    arno_run sed -i "s|^DB_USERNAME=.*|DB_USERNAME=${DB_USER}|" .env
    arno_run sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|" .env

    cd - >/dev/null
    ui_print_success "Environment Configured"
}

# ----------------------------------------------------------------------------
# Database migration
# ----------------------------------------------------------------------------
panel_migrate_database() {
    ui_print_step "Migrating database..."
    cd /var/www/pterodactyl
    arno_run_spinner "Running migrations" php artisan migrate --seed --force
    cd - >/dev/null
    ui_print_success "Database migrated"
}

# ----------------------------------------------------------------------------
# Permissions
# ----------------------------------------------------------------------------
panel_set_permissions() {
    ui_print_step "Setting permissions..."

    # If no www-data user, use nginx
    local web_user="www-data"
    if ! id -u www-data &>/dev/null; then
        web_user="nginx"
    fi

    arno_run chown -R "${web_user}:www-data" /var/www/pterodactyl
    arno_run chown -R "${web_user}:${web_user}" /var/www/pterodactyl/storage /var/www/pterodactyl/bootstrap/cache
    arno_run chmod -R 755 /var/www/pterodactyl
    arno_run chmod -R 775 /var/www/pterodactyl/storage /var/www/pterodactyl/bootstrap/cache
    ui_print_success "Permissions set"
}

# ----------------------------------------------------------------------------
# Queue service
# ----------------------------------------------------------------------------
panel_setup_queue() {
    ui_print_step "Setting up queue service..."
    cat > /etc/systemd/system/pteroq.service <<EOF
[Unit]
Description=Pterodactyl Queue Worker
After=network.target

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    # If www-data doesn't exist, use nginx
    if ! id -u www-data &>/dev/null; then
        sed -i 's/www-data/nginx/g' /etc/systemd/system/pteroq.service
    fi

    arno_run systemctl daemon-reload
    arno_run systemctl enable --now pteroq
    ui_print_success "Queue service enabled"
}

# ----------------------------------------------------------------------------
# Cron jobs
# ----------------------------------------------------------------------------
panel_setup_cron() {
    ui_print_step "Setting up cron jobs..."
    local cron_line="* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1"
    if ! crontab -l 2>/dev/null | grep -q "artisan schedule:run"; then
        (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
    fi
    ui_print_success "Cron jobs configured"
}

# ----------------------------------------------------------------------------
# Create admin user
# ----------------------------------------------------------------------------
panel_create_admin() {
    ui_print_step "Creating admin user..."
    cd /var/www/pterodactyl

    arno_run php artisan p:user:make \
        --email "${ARNO_PANEL_CFG[email]}" \
        --username "${ARNO_PANEL_CFG[username]}" \
        --name-first "${ARNO_PANEL_CFG[first_name]}" \
        --name-last "${ARNO_PANEL_CFG[last_name]}" \
        --password "${ARNO_PANEL_CFG[password]}" \
        --admin 1

    cd - >/dev/null
    ui_print_success "Admin user created"
}

# ----------------------------------------------------------------------------
# Main panel install flow
# ----------------------------------------------------------------------------
panel_install_flow() {
    local start_time end_time duration
    start_time=$(date +%s)

    arno_log "=== Panel installation started ==="

    # 1. Wizard
    panel_wizard

    # 2. Database name/user setup
    export DB_NAME="panel"
    export DB_USER="pterodactyl"
    export DB_PASS="${ARNO_PANEL_CFG[db_pass]}"

    # 3. Dependencies
    panel_install_dependencies
    panel_install_php

    # 4. MariaDB & Redis
    db_install_mariadb
    db_secure
    db_create_database "$DB_NAME" "$DB_USER" "$DB_PASS"
    db_install_redis

    # 5. Download panel
    panel_download
    panel_composer_install

    # 6. Configure environment
    panel_configure_env

    # 7. Migrate
    panel_migrate_database

    # 8. Permissions
    panel_set_permissions

    # 9. Nginx
    nginx_install
    nginx_remove_default
    nginx_ensure_dirs

    # 10. Firewall (before SSL so HTTP can be validated)
    if [[ "${ARNO_PANEL_CFG[firewall]}" == "true" ]]; then
        fw_install
        fw_configure_panel
        fw_enable
    fi

    # 11. SSL
    if [[ "${ARNO_PANEL_CFG[ssl]}" == "true" ]]; then
        ssl_install_certbot
        # First write plain HTTP config to allow certbot verification
        nginx_write_config "${ARNO_PANEL_CFG[domain]}" "false"
        arno_run systemctl reload nginx
        if ssl_request_certificate "${ARNO_PANEL_CFG[domain]}" "${ARNO_PANEL_CFG[email]}"; then
            nginx_write_config "${ARNO_PANEL_CFG[domain]}" "true"
            ssl_setup_cron_renewal
        else
            ui_print_warning "SSL failed, continuing with HTTP only"
            nginx_write_config "${ARNO_PANEL_CFG[domain]}" "false"
        fi
    else
        nginx_write_config "${ARNO_PANEL_CFG[domain]}" "false"
    fi

    nginx_reload || {
        ui_error_box "Nginx Config Error" \
            "Nginx configuration test failed." \
            "Check /var/log/arno-installer.log for details." \
            "Manual intervention required."
    }

    # 12. Queue + Cron
    panel_setup_queue
    panel_setup_cron

    # 13. Admin user
    panel_create_admin

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    panel_completion_screen "$duration"
}

# ----------------------------------------------------------------------------
# Completion screen
# ----------------------------------------------------------------------------
panel_completion_screen() {
    local duration="$1"
    local formatted
    formatted=$(util_format_duration "$duration")

    clear
    echo
    local bar="██████████████████████████████████████████████████████████████"
    ui_center_color "$RED_BOLD" "$bar"
    echo
    ui_center_color "$WHITE_BOLD" "Installation Complete"
    echo
    cat <<EOF
  $(c "$GRAY" "Panel URL     :") $(c "$GREEN" "https://${ARNO_PANEL_CFG[domain]}")
  $(c "$GRAY" "Admin User    :") $(c "$WHITE" "${ARNO_PANEL_CFG[username]}")
  $(c "$GRAY" "Admin Email   :") $(c "$WHITE" "${ARNO_PANEL_CFG[email]}")
  $(c "$GRAY" "Database      :") $(c "$GREEN" "Connected")
  $(c "$GRAY" "Redis         :") $(c "$GREEN" "$([[ $(db_redis_running) ]] && echo 'Running' || echo 'Stopped')"
  $(c "$GRAY" "Nginx         :") $(c "$GREEN" "$([[ $(nginx_running) ]] && echo 'Running' || echo 'Stopped')"
  $(c "$GRAY" "Queue Worker  :") $(c "$GREEN" "$([[ $(util_service_active pteroq) ]] && echo 'Running' || echo 'Stopped')"
  $(c "$GRAY" "SSL           :") $(c "$WHITE" "${ARNO_PANEL_CFG[ssl]}")
  $(c "$GRAY" "Install Time  :") $(c "$WHITE" "$formatted")
EOF
    echo
    ui_center_color "$RED_BOLD" "ARNO INSTALLER"
    ui_center_color "$GRAY" "Powered by Arnoplays"
    echo
    ui_center_color "$RED_BOLD" "$bar"
    echo

    arno_log "=== Panel installation completed in $formatted ==="
    arno_log "Panel URL: https://${ARNO_PANEL_CFG[domain]}"
    arno_log "Admin: ${ARNO_PANEL_CFG[username]}"

    ui_press_any_key "Press any key to return to main menu..."
}
