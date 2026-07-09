#!/usr/bin/env bash
# ============================================================================
#  ARNO INSTALLER
#  Pterodactyl Panel & Wings Installer
#  Powered by Arnoplays
#
#  Usage:
#    bash <(curl -s https://raw.githubusercontent.com/scartechgg-collab/arno-installer/main/install.sh)
#    OR
#    curl -s ... | bash
# ============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

# ----------------------------------------------------------------------------
# FIX FOR CURL | BASH
# When piping curl to bash, stdin is the script itself, so 'read' fails.
# This redirects stdin to the terminal (/dev/tty) so keyboard inputs work.
# ----------------------------------------------------------------------------
if [[ ! -t 0 ]]; then
    exec 0</dev/tty
fi

# ----------------------------------------------------------------------------
# Global Constants
# ----------------------------------------------------------------------------
export ARNO_VERSION="1.0.0"

export ARNO_REPO="scartechgg-collab/arno-installer"
export ARNO_BRANCH="main"

export ARNO_BASE_URL="https://raw.githubusercontent.com/${ARNO_REPO}/${ARNO_BRANCH}"
export ARNO_TEMP_DIR
export ARNO_LOG_FILE="/var/log/arno-installer.log"
export ARNO_PANEL_PATH="/var/www/pterodactyl"
export ARNO_CONFIG_DIR="${ARNO_PANEL_PATH}/config"

# ----------------------------------------------------------------------------
# Detect Execution Mode (curl|bash vs local)
# ----------------------------------------------------------------------------
arno_detect_mode() {
    local script_source
    script_source="${BASH_SOURCE[0]:-$0}"
    if [[ "$script_source" == /dev/fd/* ]] || [[ ! -f "$script_source" ]]; then
        export ARNO_MODE="remote"
    else
        export ARNO_MODE="local"
        export ARNO_LOCAL_DIR
        ARNO_LOCAL_DIR="$(cd "$(dirname "$script_source")" && pwd)"
    fi
}

# ----------------------------------------------------------------------------
# Prepare working directory
# ----------------------------------------------------------------------------
arno_prepare_temp_dir() {
    ARNO_TEMP_DIR="$(mktemp -d /tmp/arno-installer.XXXXXX)"
    mkdir -p "${ARNO_TEMP_DIR}/lib" "${ARNO_TEMP_DIR}/configs" "${ARNO_TEMP_DIR}/assets"
    trap 'arno_cleanup' EXIT INT TERM
}

arno_cleanup() {
    if [[ -n "${ARNO_TEMP_DIR:-}" ]] && [[ -d "${ARNO_TEMP_DIR}" ]]; then
        rm -rf "${ARNO_TEMP_DIR}"
    fi
}

# ----------------------------------------------------------------------------
# Download a resource from GitHub
# ----------------------------------------------------------------------------
arno_fetch() {
    local remote_path="$1"
    local local_path="$2"
    local url="${ARNO_BASE_URL}/${remote_path}"

    if ! curl -sSfL --retry 3 --retry-delay 1 -o "${local_path}" "${url}" 2>/dev/null; then
        echo ""
        echo "[FATAL] Failed to download: ${url}"
        echo "        Please verify your internet connection and GitHub availability."
        exit 1
    fi
}

# ----------------------------------------------------------------------------
# Load all library modules
# ----------------------------------------------------------------------------
arno_load_libraries() {
    local libs=(
        "colors.sh"
        "animations.sh"
        "utilities.sh"
        "ui.sh"
        "database.sh"
        "nginx.sh"
        "ssl.sh"
        "docker.sh"
        "firewall.sh"
        "panel.sh"
        "wings.sh"
    )

    local lib
    for lib in "${libs[@]}"; do
        if [[ "${ARNO_MODE:-remote}" == "local" && -f "${ARNO_LOCAL_DIR}/lib/${lib}" ]]; then
            # shellcheck disable=SC1090
            source "${ARNO_LOCAL_DIR}/lib/${lib}"
        else
            arno_fetch "lib/${lib}" "${ARNO_TEMP_DIR}/lib/${lib}"
            # shellcheck disable=SC1090
            source "${ARNO_TEMP_DIR}/lib/${lib}"
        fi
    done
}

# ----------------------------------------------------------------------------
# Initialize logging
# ----------------------------------------------------------------------------
arno_init_log() {
    if [[ $EUID -eq 0 ]]; then
        : > "${ARNO_LOG_FILE}" 2>/dev/null || true
        chmod 600 "${ARNO_LOG_FILE}" 2>/dev/null || true
    fi
    arno_log "============================================================"
    arno_log "ARNO Installer v${ARNO_VERSION} started at $(date '+%Y-%m-%d %H:%M:%S')"
    arno_log "Mode: ${ARNO_MODE:-remote}"
    arno_log "OS: $(uname -a)"
    arno_log "User: $(whoami) (UID: $EUID)"
    arno_log "============================================================"
}

# ----------------------------------------------------------------------------
# Bootstrap
# ----------------------------------------------------------------------------
arno_main() {
    arno_detect_mode
    arno_prepare_temp_dir
    arno_load_libraries
    arno_init_log

    ui_check_terminal
    ui_show_splash
    ui_run_startup_checks

    local choice
    while true; do
        ui_show_main_menu
        choice="$(ui_read_choice "Select an option" "1 2 3")"
        case "$choice" in
            1) panel_install_flow ;;
            2) wings_install_flow ;;
            3) ui_show_exit_screen; break ;;
            *) ui_print_warning "Invalid choice, please try again." ;;
        esac
    done

    arno_log "ARNO Installer finished at $(date '+%Y-%m-%d %H:%M:%S')"
}

arno_main "$@"
