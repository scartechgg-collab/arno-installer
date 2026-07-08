# ============================================================================
#  ARNO Installer - Firewall Configuration
# ============================================================================

fw_detect() {
    if util_command_exists ufw; then
        echo "ufw"
    elif util_command_exists firewall-cmd; then
        echo "firewalld"
    else
        echo "none"
    fi
}

fw_install() {
    ui_print_step "Installing Firewall..."
    if util_is_debian_family; then
        if ! util_command_exists ufw; then
            arno_run_spinner "Installing UFW" pkg_install ufw
        fi
    elif util_is_rhel_family; then
        if ! util_command_exists firewall-cmd; then
            arno_run_spinner "Installing firewalld" pkg_install firewalld
            arno_run systemctl enable --now firewalld
        fi
    fi
    ui_print_success "Firewall Ready"
}

fw_allow_port() {
    local port="$1"
    local proto="${2:-tcp}"
    local fw
    fw=$(fw_detect)
    case "$fw" in
        ufw)
            arno_run ufw allow "${port}/${proto}"
            ;;
        firewalld)
            arno_run firewall-cmd --permanent "--add-port=${port}/${proto}"
            arno_run firewall-cmd --reload
            ;;
        none)
            arno_log "No firewall detected, skipping port $port"
            ;;
    esac
}

fw_allow_service() {
    local service="$1"
    local fw
    fw=$(fw_detect)
    case "$fw" in
        ufw)
            arno_run ufw allow "$service"
            ;;
        firewalld)
            arno_run firewall-cmd --permanent "--add-service=${service}"
            arno_run firewall-cmd --reload
            ;;
        none)
            arno_log "No firewall detected, skipping service $service"
            ;;
    esac
}

fw_configure_panel() {
    ui_print_step "Configuring Firewall (Panel)..."
    fw_allow_service http
    fw_allow_service https
    fw_allow_service ssh
    fw_allow_port 8080
    ui_print_success "Firewall Configured for Panel"
}

fw_configure_wings() {
    ui_print_step "Configuring Firewall (Wings)..."
    fw_allow_port 8080
    fw_allow_port 2022
    fw_allow_service ssh
    ui_print_success "Firewall Configured for Wings"
}

fw_enable() {
    local fw
    fw=$(fw_detect)
    case "$fw" in
        ufw)
            arno_run ufw --force enable
            ;;
        firewalld)
            arno_run systemctl enable --now firewalld
            ;;
    esac
}

fw_status() {
    local fw
    fw=$(fw_detect)
    case "$fw" in
        ufw) ufw status ;;
        firewalld) firewall-cmd --list-all ;;
        none) echo "No firewall active" ;;
    esac
}
