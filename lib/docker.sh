# ============================================================================
#  ARNO Installer - Docker & Docker Compose
# ============================================================================

docker_installed() {
    util_command_exists docker
}

docker_install() {
    ui_print_step "Installing Docker..."

    if docker_installed; then
        ui_print_warning "Docker already installed, skipping..."
        return 0
    fi

    if util_is_debian_family; then
        arno_run_spinner "Installing Docker prerequisites" pkg_install \
            ca-certificates curl gnupg lsb-release

        # Add Docker's official GPG key
        install -m 0755 -d /etc/apt/keyrings
        if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
            curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg | \
                gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            chmod a+r /etc/apt/keyrings/docker.gpg
        fi

        # Add Docker apt repo
        local codename
        codename=$(. /etc/os-release && echo "$VERSION_CODENAME")
        if ! grep -q "download.docker.com" /etc/apt/sources.list.d/docker.list 2>/dev/null; then
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") $codename stable" \
                > /etc/apt/sources.list.d/docker.list
        fi

        arno_run apt-get update -y
        arno_run_spinner "Installing Docker Engine" pkg_install \
            docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    elif util_is_rhel_family; then
        arno_run_spinner "Installing Docker prerequisites" pkg_install \
            dnf-plugins-core
        if ! grep -q "download.docker.com" /etc/yum.repos.d/docker-ce.repo 2>/dev/null; then
            arno_run dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        fi
        arno_run_spinner "Installing Docker Engine" pkg_install \
            docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi

    arno_run_spinner "Enabling Docker" systemctl enable --now docker
    ui_print_success "Docker Installed"
}

docker_compose_installed() {
    docker compose version &>/dev/null
}

docker_running() {
    util_service_active docker
}

docker_configure() {
    ui_print_step "Configuring Docker..."
    # Ensure docker is enabled
    arno_run systemctl enable docker
    arno_run systemctl start docker

    # Create docker network for pterodactyl if it doesn't exist
    if ! docker network inspect pterodactyl_nw &>/dev/null; then
        arno_run docker network create --driver bridge --subnet 172.18.0.0/16 pterodactyl_nw 2>/dev/null || \
            arno_run docker network create pterodactyl_nw
    fi
    ui_print_success "Docker Configured"
}
