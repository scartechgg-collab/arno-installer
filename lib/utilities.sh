# ============================================================================
#  ARNO Installer - Utility Functions
# ============================================================================

# ----------------------------------------------------------------------------
# Logging
# ----------------------------------------------------------------------------
arno_log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    if [[ $EUID -eq 0 ]] && [[ -w "${ARNO_LOG_FILE:-/var/log/arno-installer.log}" ]]; then
        echo "$msg" >> "${ARNO_LOG_FILE}"
    elif [[ -n "${ARNO_LOG_FILE:-}" ]]; then
        echo "$msg" >> "${ARNO_LOG_FILE}" 2>/dev/null || true
    fi
}

arno_log_cmd() {
    # Logs the command about to be executed
    arno_log "CMD: $*"
}

# ----------------------------------------------------------------------------
# Run a command silently with logging
# ----------------------------------------------------------------------------
arno_run() {
    arno_log_cmd "$*"
    "$@" >> "${ARNO_LOG_FILE:-/dev/null}" 2>&1
}

arno_run_silent() {
    arno_log_cmd "$*"
    "$@" >/dev/null 2>&1
}

# ----------------------------------------------------------------------------
# Run with spinner
# ----------------------------------------------------------------------------
arno_run_spinner() {
    local msg="$1"; shift
    local log_file="${ARNO_LOG_FILE:-/dev/null}"
    arno_log "CMD (spinner): $*"
    ( "$@" >> "$log_file" 2>&1 ) &
    local pid=$!
    arno_spinner "$pid" "$msg"
    wait "$pid"
    return $?
}

# ----------------------------------------------------------------------------
# OS Detection
# ----------------------------------------------------------------------------
util_detect_os() {
    local os_id=""
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        os_id="${ID:-}"
        export ARNO_OS_ID="$os_id"
        export ARNO_OS_VERSION="${VERSION_ID:-}"
        export ARNO_OS_PRETTY="${PRETTY_NAME:-Unknown}"
        return 0
    elif [[ -f /etc/redhat-release ]]; then
        local rhl
        rhl=$(cat /etc/redhat-release)
        if echo "$rhl" | grep -qi "rocky"; then
            export ARNO_OS_ID="rocky"
        elif echo "$rhl" | grep -qi "almalinux"; then
            export ARNO_OS_ID="almalinux"
        elif echo "$rhl" | grep -qi "centos"; then
            export ARNO_OS_ID="centos"
        else
            export ARNO_OS_ID="rhel"
        fi
        export ARNO_OS_VERSION=""
        export ARNO_OS_PRETTY="$rhl"
        return 0
    fi
    return 1
}

util_os_supported() {
    case "${ARNO_OS_ID:-}" in
        ubuntu|debian|rocky|almalinux|rhel|centos) return 0 ;;
        *) return 1 ;;
    esac
}

util_is_debian_family() {
    case "${ARNO_OS_ID:-}" in
        ubuntu|debian) return 0 ;;
        *) return 1 ;;
    esac
}

util_is_rhel_family() {
    case "${ARNO_OS_ID:-}" in
        rocky|almalinux|rhel|centos) return 0 ;;
        *) return 1 ;;
    esac
}

# ----------------------------------------------------------------------------
# System checks
# ----------------------------------------------------------------------------
util_check_root() {
    if [[ $EUID -ne 0 ]]; then
        return 1
    fi
    return 0
}

util_check_internet() {
    if curl -sSf --max-time 5 -o /dev/null https://raw.githubusercontent.com 2>/dev/null; then
        return 0
    elif ping -c1 -W2 1.1.1.1 >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

util_get_ram_mb() {
    local ram
    ram=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null)
    echo "${ram:-0}"
}

util_get_cpu_count() {
    local cpus
    cpus=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null)
    echo "${cpus:-0}"
}

util_get_disk_gb() {
    local disk
    disk=$(df -BG / 2>/dev/null | awk 'NR==2 {print $4}' | tr -d 'G')
    echo "${disk:-0}"
}

util_get_swap_mb() {
    local swap
    swap=$(awk '/SwapTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null)
    echo "${swap:-0}"
}

util_check_virtualization() {
    local virt
    if systemd-detect-virt &>/dev/null; then
        virt=$(systemd-detect-virt 2>/dev/null)
    else
        virt="unknown"
    fi
    echo "$virt"
}

util_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

util_service_exists() {
    systemctl list-unit-files "${1}.service" 2>/dev/null | grep -q "^${1}.service"
}

util_service_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

# ----------------------------------------------------------------------------
# Package management abstraction
# ----------------------------------------------------------------------------
pkg_update() {
    if util_is_debian_family; then
        arno_run apt-get update -y
        arno_run apt-get upgrade -y
    elif util_is_rhel_family; then
        arno_run dnf -y update
    fi
}

pkg_install() {
    if util_is_debian_family; then
        DEBIAN_FRONTEND=noninteractive arno_run apt-get install -y "$@"
    elif util_is_rhel_family; then
        arno_run dnf install -y "$@"
    fi
}

pkg_installed() {
    if util_is_debian_family; then
        dpkg -s "$1" &>/dev/null
    elif util_is_rhel_family; then
        rpm -q "$1" &>/dev/null
    fi
}

# ----------------------------------------------------------------------------
# Confirm prompt
# ----------------------------------------------------------------------------
util_confirm() {
    local prompt="${1:-Confirm?}"
    local default="${2:-y}"
    local choice
    if [[ "$default" == "y" ]]; then
        read -rp "$(c "$WHITE_BOLD" "$prompt") $(c "$GRAY" "[Y/n]: ")" choice
        choice="${choice:-y}"
    else
        read -rp "$(c "$WHITE_BOLD" "$prompt") $(c "$GRAY" "[y/N]: ")" choice
        choice="${choice:-n}"
    fi
    case "${choice,,}" in
        y|yes) return 0 ;;
        *)     return 1 ;;
    esac
}

# ----------------------------------------------------------------------------
# Read input with prompt
# ----------------------------------------------------------------------------
util_read_input() {
    local var="$1"; shift
    local prompt="$1"; shift
    local default="${1:-}"
    local value
    if [[ -n "$default" ]]; then
        read -rp "$(c "$WHITE_BOLD" "$prompt") $(c "$GRAY" "[$default]: ")" value
        value="${value:-$default}"
    else
        read -rp "$(c "$WHITE_BOLD" "$prompt") $(c "$GRAY" ": ")" value
    fi
    eval "$var=\"\$value\""
}

util_read_secret() {
    local var="$1"; shift
    local prompt="$1"; shift
    local value
    read -rsp "$(c "$WHITE_BOLD" "$prompt") $(c "$GRAY" ": ")" value
    echo
    eval "$var=\"\$value\""
}

# ----------------------------------------------------------------------------
# Retry wrapper
# ----------------------------------------------------------------------------
util_retry() {
    local max_attempts="${1:-3}"
    local delay="${2:-2}"
    local attempt=1
    shift 2
    until "$@"; do
        if (( attempt >= max_attempts )); then
            arno_log "Retry failed after $max_attempts attempts: $*"
            return 1
        fi
        arno_log "Retrying ($attempt/$max_attempts) in ${delay}s..."
        sleep "$delay"
        attempt=$((attempt + 1))
    done
    return 0
}

# ----------------------------------------------------------------------------
# Get public IP
# ----------------------------------------------------------------------------
util_get_public_ip() {
    local ip
    ip=$(curl -sS --max-time 5 https://api.ipify.org 2>/dev/null) || true
    if [[ -z "$ip" ]]; then
        ip=$(curl -sS --max-time 5 https://ifconfig.me 2>/dev/null) || true
    fi
    echo "${ip:-127.0.0.1}"
}

# ----------------------------------------------------------------------------
# Random password generator
# ----------------------------------------------------------------------------
util_gen_password() {
    local length="${1:-24}"
    tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c "$length" || true
    echo
}

# ----------------------------------------------------------------------------
# Random string
# ----------------------------------------------------------------------------
util_gen_token() {
    local length="${1:-32}"
    tr -dc 'a-zA-Z0-9' </dev/urandom | head -c "$length" || true
    echo
}

# ----------------------------------------------------------------------------
# Elapsed time formatter
# ----------------------------------------------------------------------------
util_format_duration() {
    local seconds="$1"
    local h m s
    h=$((seconds / 3600))
    m=$(( (seconds % 3600) / 60 ))
    s=$((seconds % 60))
    printf '%02d:%02d:%02d\n' "$h" "$m" "$s"
}
