# ============================================================================
#  ARNO Installer - Database (MariaDB) Management
# ============================================================================

db_install_mariadb() {
    ui_print_step "Installing MariaDB..."
    if util_is_debian_family; then
        arno_run_spinner "Installing MariaDB Server" pkg_install mariadb-server
    elif util_is_rhel_family; then
        arno_run_spinner "Installing MariaDB Server" pkg_install mariadb-server
    fi
    arno_run_spinner "Enabling MariaDB" systemctl enable --now mariadb
    ui_print_success "MariaDB Installed"
}

db_secure() {
    ui_print_step "Securing MariaDB..."
    # Run mysql_secure_installation equivalent non-interactively
    arno_run mysql -e "DELETE FROM mysql.user WHERE User='';" 2>/dev/null || true
    arno_run mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1');" 2>/dev/null || true
    arno_run mysql -e "DROP DATABASE IF EXISTS test;" 2>/dev/null || true
    arno_run mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" 2>/dev/null || true
    arno_run mysql -e "FLUSH PRIVILEGES;" 2>/dev/null || true
    ui_print_success "MariaDB Secured"
}

db_create_database() {
    local db_name="$1"
    local db_user="$2"
    local db_pass="$3"

    ui_print_step "Creating Database & User..."
    arno_run mysql -e "CREATE DATABASE IF NOT EXISTS \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    arno_run mysql -e "CREATE USER IF NOT EXISTS '$db_user'@'127.0.0.1' IDENTIFIED BY '$db_pass';"
    arno_run mysql -e "GRANT ALL PRIVILEGES ON \`$db_name\`.* TO '$db_user'@'127.0.0.1';"
    arno_run mysql -e "FLUSH PRIVILEGES;"
    ui_print_success "Database '$db_name' Created"
}

db_test_connection() {
    local db_user="$1"
    local db_pass="$2"
    local db_name="$3"
    if mysql -u "$db_user" -p"$db_pass" -h 127.0.0.1 -e "USE \`$db_name\`; SHOW TABLES;" &>/dev/null; then
        return 0
    fi
    return 1
}

db_root_password_set() {
    # Returns 0 if root password is already configured
    if mysql -u root -e "SELECT 1;" &>/dev/null; then
        return 1  # no password required = not set
    fi
    return 0
}

db_set_root_password() {
    local new_pass="$1"
    arno_run mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$new_pass';" 2>/dev/null || \
        arno_run mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$new_pass');" 2>/dev/null || \
        arno_run mysqladmin -u root password "$new_pass"
    arno_log "MariaDB root password set"
}

db_install_redis() {
    ui_print_step "Installing Redis..."
    if util_is_debian_family; then
        arno_run_spinner "Installing Redis" pkg_install redis-server
        arno_run_spinner "Enabling Redis" systemctl enable --now redis-server
    elif util_is_rhel_family; then
        arno_run_spinner "Installing Redis" pkg_install redis
        arno_run_spinner "Enabling Redis" systemctl enable --now redis
    fi
    ui_print_success "Redis Installed"
}

db_redis_running() {
    util_service_active redis-server || util_service_active redis
}
