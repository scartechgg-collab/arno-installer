# ============================================================================
#  ARNO Installer - SSL via Let's Encrypt (Certbot)
# ============================================================================

ssl_install_certbot() {
    ui_print_step "Installing Certbot..."
    if util_is_debian_family; then
        if ! pkg_installed certbot; then
            arno_run_spinner "Installing Certbot" pkg_install certbot python3-certbot-nginx
        fi
    elif util_is_rhel_family; then
        if ! pkg_installed certbot; then
            arno_run_spinner "Installing Certbot" pkg_install certbot python3-certbot-nginx
        fi
    fi
    ui_print_success "Certbot Installed"
}

ssl_request_certificate() {
    local domain="$1"
    local email="$2"

    ui_print_step "Requesting SSL Certificate for $domain..."
    if certbot --nginx --non-interactive --agree-tos -m "$email" -d "$domain" --redirect >> "${ARNO_LOG_FILE}" 2>&1; then
        ui_print_success "SSL Certificate Issued for $domain"
        return 0
    else
        ui_print_error "Failed to obtain SSL certificate for $domain"
        arno_log "Certbot failed for $domain"
        return 1
    fi
}

ssl_certificate_exists() {
    local domain="$1"
    [[ -f "/etc/letsencrypt/live/${domain}/fullchain.pem" ]]
}

ssl_setup_cron_renewal() {
    local cron_line="0 3 * * * certbot renew --quiet --deploy-hook 'systemctl reload nginx'"
    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
        (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
        arno_log "Added certbot renewal cron job"
    fi
}
