# ============================================================================
#  ARNO Installer - Pterodactyl Wings Installation
# ============================================================================

declare -gA ARNO_WINGS_CFG

# ----------------------------------------------------------------------------
# Wizard
# ----------------------------------------------------------------------------
wings_wizard() {
    ui_print_step "Wings Configuration Wizard"
    echo

    util_read_input ARNO_WINGS_CFG[panel_url] \
        "Panel URL (https://panel.example.com)" ""

    util_read_input ARNO_WINGS_CFG[node_name] \
        "Node Name" "Node-$(hostname)"

    util_read_input ARNO_WINGS_CFG[node_location] \
        "Node Location" "Default"

    local ssl_choice
    ssl_choice=$(ui_read_choice "Enable SSL?" "y n")
    ARNO_WINGS_CFG[ssl]=$([[ "$ssl_choice" == "y" ]] && echo "true" || echo "false")

    local fw_choice
    fw_choice=$(ui_read_choice "Configure firewall automatically?" "y n")
    ARNO_WINGS_CFG[firewall]=$([[ "$fw_choice" == "y" ]] && echo "true" || echo "false")

    echo
    ui_print_step "Configuration Summary"
    cat <<EOF
  $(c "$GRAY" "Panel URL     :") $(c "$WHITE" "${ARNO_WINGS_CFG[panel_url]}")
  $(c "$GRAY" "Node Name     :") $(c "$WHITE" "${ARNO_WINGS_CFG[node_name]}")
  $(c "$GRAY" "Node Location :") $(c "$WHITE" "${ARNO_WINGS_CFG[node_location]}")
  $(c "$GRAY" "SSL           :") $(c "$WHITE" "${ARNO_WINGS_CFG[ssl]}")
  $(c "$GRAY" "Firewall      :") $(c "$WHITE" "${ARNO_WINGS_CFG[firewall]}")
EOF
    echo

    ui_print_info "You will need to add a Node in your Panel and copy the auto-generated configuration token."
    ui_print_info "The installer will download Wings and set up the systemd service."
    echo

    if ! util_confirm "Proceed with Wings installation?" "y"; then
        ui_print_warning "Installation cancelled."
        exit 0
    fi
}

# ----------------------------------------------------------------------------
# Install Wings binary
# ----------------------------------------------------------------------------
wings_download_binary() {
    ui_print_step "Downloading Wings binary..."
    mkdir -p /usr/local/bin
    if [[ -f /usr/local/bin/wings ]]; then
        arno_run rm -f /usr/local/bin/wings
    fi
    arno_run_spinner "Downloading Wings" \
        curl -L -o /usr/local/bin/wings https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64
    arno_run chmod +x /usr/local/bin/wings
    ui_print_success "Wings binary installed"
}

# ----------------------------------------------------------------------------
# Configure Wings directory structure
# ----------------------------------------------------------------------------
wings_setup_dirs() {
    ui_print_step "Setting up Wings directories..."
    mkdir -p /etc/pterodactyl
    mkdir -p /var/lib/pterodactyl/volumes
    mkdir -p /var/log/pterodactyl
    ui_print_success "Directories created"
}

# ----------------------------------------------------------------------------
# Systemd service
# ----------------------------------------------------------------------------
wings_setup_service() {
    ui_print_step "Configuring Wings service..."
    cat > /etc/systemd/system/wings.service <<'EOF'
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    arno_run systemctl daemon-reload
    arno_run systemctl enable wings
    ui_print_success "Wings service configured"
}

# ----------------------------------------------------------------------------
# Config placement helper (manual step)
# ----------------------------------------------------------------------------
wings_config_instructions() {
    echo
    ui_print_step "Manual Configuration Required"
    cat <<EOF

  $(c "$YELLOW" "IMPORTANT: Complete these steps in your Panel:")

  $(c "$WHITE" "1.") Login to your Panel as admin
  $(c "$WHITE" "2.") Navigate to: $(c "$GRAY" "Admin → Nodes → Create New")
  $(c "$WHITE" "3.") Fill in:
       $(c "$GRAY" "Name        : ${ARNO_WINGS_CFG[node_name]}")
       $(c "$GRAY" "Location    : ${ARNO_WINGS_CFG[node_location]}")
       $(c "$GRAY" "FQDN        : $(util_get_public_ip)")
       $(c "$GRAY" "Daemon Port : 8080")
       $(c "$GRAY" "SFTP Port   : 2022")
  $(c "$WHITE" "4.") Click $(c "$GREEN" "Create Node")
  $(c "$WHITE" "5.") Go to $(c "$GRAY" "Configuration") tab → click $(c "$GREEN" "Generate Token")
  $(c "$WHITE" "6.") Copy the configuration JSON to clipboard
  $(c "$WHITE" "7.") Return to this terminal and paste below

EOF

    if util_confirm "Have you copied the config? Paste it now?" "y"; then
        local config_json
        # Read multi-line input until EOF (Ctrl+D)
        echo "$(c "$GRAY" "Paste config (Ctrl+D when done):")"
        config_json=$(cat)
        if [[ -n "$config_json" ]]; then
            echo "$config_json" > /etc/pterodactyl/config.yml
            chmod 600 /etc/pterodactyl/config.yml
            ui_print_success "Configuration saved to /etc/pterodactyl/config.yml"
            arno_log "Wings config.yml written"
        else
            ui_print_warning "No config provided. You can manually create /etc/pterodactyl/config.yml later."
        fi
    fi
}

# ----------------------------------------------------------------------------
# Start Wings
# ----------------------------------------------------------------------------
wings_start() {
    ui_print_step "Starting Wings..."
    if [[ -f /etc/pterodactyl/config.yml ]]; then
        arno_run systemctl start wings
        sleep 2
        if util_service_active wings; then
            ui_print_success "Wings is running"
        else
            ui_print_warning "Wings failed to start. Check: journalctl -u wings -f"
        fi
    else
        ui_print_warning "Skipping auto-start: config.yml not present"
    fi
}

# ----------------------------------------------------------------------------
# Main wings flow
# ----------------------------------------------------------------------------
wings_install_flow() {
    local start_time end_time duration
    start_time=$(date +%s)

    arno_log "=== Wings installation started ==="

    wings_wizard

    # Dependencies
    ui_print_step "Installing base dependencies..."
    if util_is_debian_family; then
        arno_run_spinner "Installing deps" pkg_install curl wget git tar ca-certificates
    elif util_is_rhel_family; then
        arno_run_spinner "Installing deps" pkg_install curl wget git tar ca-certificates
    fi

    # Docker
    docker_install
    docker_configure

    # Wings binary
    wings_download_binary
    wings_setup_dirs
    wings_setup_service

    # Firewall
    if [[ "${ARNO_WINGS_CFG[firewall]}" == "true" ]]; then
        fw_install
        fw_configure_wings
        fw_enable
    fi

    # SSL (self-signed for node, or instructions)
    if [[ "${ARNO_WINGS_CFG[ssl]}" == "true" ]]; then
        ui_print_step "Generating self-signed SSL for Wings..."
        mkdir -p /etc/ssl/pterodactyl
        if [[ ! -f /etc/ssl/pterodactyl/wings.crt ]]; then
            arno_run openssl req -x509 -nodes -days 3650 \
                -newkey rsa:2048 \
                -keyout /etc/ssl/pterodactyl/wings.key \
                -out /etc/ssl/pterodactyl/wings.crt \
                -subj "/CN=$(util_get_public_ip)"
        fi
        ui_print_success "SSL certificates generated"
    fi

    # Manual config step
    wings_config_instructions

    # Start
    wings_start

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    wings_completion_screen "$duration"
}

# ----------------------------------------------------------------------------
# Completion screen
# ----------------------------------------------------------------------------
wings_completion_screen() {
    local duration="$1"
    local formatted
    formatted=$(util_format_duration "$duration")

    clear
    echo
    local bar="██████████████████████████████████████████████████████████████"
    ui_center_color "$RED_BOLD" "$bar"
    echo
    ui_center_color "$WHITE_BOLD" "Wings Installation Complete"
    echo
    cat <<EOF
  $(c "$GRAY" "Node Name     :") $(c "$WHITE" "${ARNO_WINGS_CFG[node_name]}")
  $(c "$GRAY" "Panel URL     :") $(c "$WHITE" "${ARNO_WINGS_CFG[panel_url]}")
  $(c "$GRAY" "Wings Binary  :") $(c "$GREEN" "/usr/local/bin/wings")
  $(c "$GRAY" "Config File   :") $(c "$WHITE" "/etc/pterodactyl/config.yml")
  $(c "$GRAY" "Docker        :") $(c "$GREEN" "$([[ $(docker_running) ]] && echo 'Running' || echo 'Stopped')"
  $(c "$GRAY" "Wings Service :") $(c "$GREEN" "$([[ $(util_service_active wings) ]] && echo 'Running' || echo 'Stopped')"
  $(c "$GRAY" "Install Time  :") $(c "$WHITE" "$formatted")
EOF
    echo
    ui_center_color "$GRAY" "Useful commands:"
    ui_center_color "$GRAY" "  systemctl status wings"
    ui_center_color "$GRAY" "  systemctl restart wings"
    ui_center_color "$GRAY" "  journalctl -u wings -f"
    echo
    ui_center_color "$RED_BOLD" "ARNO INSTALLER"
    ui_center_color "$GRAY" "Powered by Arnoplays"
    echo
    ui_center_color "$RED_BOLD" "$bar"
    echo

    arno_log "=== Wings installation completed in $formatted ==="

    ui_press_any_key "Press any key to return to main menu..."
}
