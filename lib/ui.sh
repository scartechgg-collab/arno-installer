# ============================================================================
#  ARNO Installer - User Interface
# ============================================================================

# Terminal sizing
ui_get_cols() {
    tput cols 2>/dev/null || echo 80
}

ui_get_rows() {
    tput lines 2>/dev/null || echo 24
}

ui_center() {
    local text="$1"
    local cols
    cols=$(ui_get_cols)
    local text_len
    text_len=${#text}
    local padding=$(( (cols - text_len) / 2 ))
    (( padding < 0 )) && padding=0
    printf '%*s%s\n' "$padding" "" "$text"
}

ui_center_color() {
    local color="$1"; shift
    local text="$*"
    local cols
    cols=$(ui_get_cols)
    local padding=$(( (cols - ${#text}) / 2 ))
    (( padding < 0 )) && padding=0
    printf '%*s' "$padding" ""
    c "$color" "$text"
    printf '\n'
}

ui_separator() {
    local cols
    cols=$(ui_get_cols)
    local line=""
    local i
    for (( i=0; i<cols; i++ )); do line+='─'; done
    printf '%s\n' "$(c "$GRAY_DIM" "$line")"
}

# ----------------------------------------------------------------------------
# Status indicators
# ----------------------------------------------------------------------------
ui_print_success() {
    printf '  %s %s\n' "$(c "$GREEN" "✔")" "$(c "$WHITE" "$1")"
    arno_log "[SUCCESS] $1"
}

ui_print_error() {
    printf '  %s %s\n' "$(c "$RED_BOLD" "✘")" "$(c "$WHITE" "$1")"
    arno_log "[ERROR] $1"
}

ui_print_warning() {
    printf '  %s %s\n' "$(c "$YELLOW" "⚠")" "$(c "$WHITE" "$1")"
    arno_log "[WARN] $1"
}

ui_print_info() {
    printf '  %s %s\n' "$(c "$BLUE" "ℹ")" "$(c "$WHITE" "$1")"
    arno_log "[INFO] $1"
}

ui_print_step() {
    printf '\n  %s %s\n' "$(c "$RED_BOLD" "▶")" "$(c "$WHITE_BOLD" "$1")"
    arno_log "[STEP] $1"
}

ui_print_substep() {
    printf '    %s %s' "$(c "$GRAY" "→")" "$(c "$GRAY" "$1")"
}

# ----------------------------------------------------------------------------
# Terminal checks
# ----------------------------------------------------------------------------
ui_check_terminal() {
    if [[ ! -t 1 ]]; then
        export ARNO_USE_COLOR=0
    fi
}

# ----------------------------------------------------------------------------
# Splash screen (Added the red box at the starting)
# ----------------------------------------------------------------------------
ui_show_splash() {
    clear
    local cols
    cols=$(ui_get_cols)
    local box_width=46
    local padding=$(( (cols - box_width) / 2 ))
    (( padding < 0 )) && padding=0
    
    local pad_str=""
    local i
    for (( i=0; i<padding; i++ )); do pad_str+=' '; done

    # Splash box top
    printf '\n%s%s\n' "$pad_str" "$(c "$RED_BOLD" "╔══════════════════════════════════════════════╗")"
    
    local logo=(
        '    ██████╗ ██████╗ ███╗   ██╗ ██████╗ '
        '    ██╔══██╗██╔══██╗████╗  ██║██╔═══██╗'
        '    ██████╔╝██████╔╝██╔██╗ ██║██║   ██║'
        '    ██╔══██╗██╔══██╗██║╚██╗██║██║   ██║'
        '    ██║  ██║██║  ██║██║ ╚████║╚██████╔╝'
        '    ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ '
    )
    
    local line
    for line in "${logo[@]}"; do
        printf '%s%s%s%s%s\n' "$pad_str" "$(c "$RED_BOLD" "║")" "  " "$(c "$RED" "$line")" "$(c "$RED_BOLD" "  ║")"
        sleep 0.08
    done

    # Splash box bottom
    printf '%s%s\n\n' "$pad_str" "$(c "$RED_BOLD" "╚══════════════════════════════════════════════╝")"
    
    ui_center_color "$RED_BOLD" "ARNO INSTALLER"
    ui_center_color "$GRAY" "Powered by Arnoplays"
    ui_center_color "$GRAY_DIM" "Version ${ARNO_VERSION}"
    echo
    sleep 0.4
}

# ----------------------------------------------------------------------------
# Startup checks screen
# ----------------------------------------------------------------------------
ui_run_startup_checks() {
    ui_center_color "$WHITE_BOLD" "Loading Modules..."
    echo
    local modules=(
        "colors.sh" "animations.sh" "utilities.sh" "ui.sh"
        "database.sh" "nginx.sh" "ssl.sh" "docker.sh"
        "firewall.sh" "panel.sh" "wings.sh"
    )
    local i
    for (( i=0; i<${#modules[@]}; i++ )); do
        arno_progress_bar $((i+1)) "${#modules[@]}" "${modules[$i]}"
        sleep 0.08
    done
    echo
    echo

    ui_center_color "$WHITE_BOLD" "Running System Checks..."
    echo

    local checks=()
    # OS
    if util_detect_os; then
        checks+=("$(c "$GREEN" "✔") OS Detected: $(c "$WHITE" "${ARNO_OS_PRETTY:-Unknown}")")
    else
        checks+=("$(c "$RED" "✘") OS Detection Failed")
    fi

    # OS Support
    if util_os_supported; then
        checks+=("$(c "$GREEN" "✔") OS Supported")
    else
        checks+=("$(c "$RED" "✘") OS Unsupported - Aborting")
    fi

    # Root
    if util_check_root; then
        checks+=("$(c "$GREEN" "✔") Root Privileges")
    else
        checks+=("$(c "$RED" "✘") Not running as root")
    fi

    # Internet
    if util_check_internet; then
        checks+=("$(c "$GREEN" "✔") Internet Connection")
    else
        checks+=("$(c "$RED" "✘") No Internet Connection")
    fi

    # RAM
    local ram
    ram=$(util_get_ram_mb)
    if (( ram >= 1024 )); then
        checks+=("$(c "$GREEN" "✔") RAM: ${ram}MB")
    else
        checks+=("$(c "$YELLOW" "⚠") RAM Low: ${ram}MB (recommended: 1024MB+)")
    fi

    # CPU
    local cpus
    cpus=$(util_get_cpu_count)
    if (( cpus >= 2 )); then
        checks+=("$(c "$GREEN" "✔") CPU Cores: ${cpus}")
    else
        checks+=("$(c "$YELLOW" "⚠") CPU Cores: ${cpus} (recommended: 2+)")
    fi

    # Disk
    local disk
    disk=$(util_get_disk_gb)
    if (( disk >= 10 )); then
        checks+=("$(c "$GREEN" "✔") Disk Space: ${disk}GB")
    else
        checks+=("$(c "$YELLOW" "⚠") Disk Low: ${disk}GB")
    fi

    # Virtualization
    local virt
    virt=$(util_check_virtualization)
    checks+=("$(c "$BLUE" "ℹ") Virtualization: ${virt}")

    for c in "${checks[@]}"; do
        printf '  %s\n' "$c"
        sleep 0.1
    done

    echo

    # Abort if not root or unsupported OS or no internet
    if ! util_check_root; then
        ui_error_box "Root Required" "ARNO Installer must be run as root." \
            "Re-run with: sudo bash <(curl -s ...)"
        exit 1
    fi
    if ! util_os_supported; then
        ui_error_box "Unsupported OS" \
            "Detected: ${ARNO_OS_PRETTY:-Unknown}" \
            "Supported: Ubuntu, Debian, Rocky Linux, AlmaLinux"
        exit 1
    fi
    if ! util_check_internet; then
        ui_error_box "No Internet" \
            "ARNO Installer requires an internet connection." \
            "Check your network and DNS resolution."
        exit 1
    fi

    ui_center_color "$GREEN" "All checks passed"
    echo
    sleep 0.5
}

# ----------------------------------------------------------------------------
# Main menu (Perfectly Aligned Red Box)
# ----------------------------------------------------------------------------
ui_show_main_menu() {
    clear
    echo
    local cols
    cols=$(ui_get_cols)
    local box_width=42
    local padding=$(( (cols - box_width) / 2 ))
    (( padding < 0 )) && padding=0
    
    local pad_str=""
    local i
    for (( i=0; i<padding; i++ )); do pad_str+=' '; done

    printf '%s%s\n' "$pad_str" "$(c "$RED_BOLD" "╔══════════════════════════════════════════╗")"
    printf '%s%s%s%s\n' "$pad_str" "$(c "$RED_BOLD" "║")" "$(c "$RED_BOLD" "            ARNO INSTALLER              ")" "$(c "$RED_BOLD" "║")"
    printf '%s%s\n' "$pad_str" "$(c "$RED_BOLD" "╠══════════════════════════════════════════╣")"
    printf '%s%s%s%s\n' "$pad_str" "$(c "$RED_BOLD" "║")" "$(c "$GRAY" "                                          ")" "$(c "$RED_BOLD" "║")"
    printf '%s%s%s%s\n' "$pad_str" "$(c "$RED_BOLD" "║")" "$(c "$WHITE_BOLD" "  [1] Panel Installation                 ")" "$(c "$RED_BOLD" "║")"
    printf '%s%s%s%s\n' "$pad_str" "$(c "$RED_BOLD" "║")" "$(c "$WHITE_BOLD" "  [2] Wings Installation                  ")" "$(c "$RED_BOLD" "║")"
    printf '%s%s%s%s\n' "$pad_str" "$(c "$RED_BOLD" "║")" "$(c "$WHITE_BOLD" "  [3] Exit                                ")" "$(c "$RED_BOLD" "║")"
    printf '%s%s%s%s\n' "$pad_str" "$(c "$RED_BOLD" "║")" "$(c "$GRAY" "                                          ")" "$(c "$RED_BOLD" "║")"
    printf '%s%s\n' "$pad_str" "$(c "$RED_BOLD" "╚══════════════════════════════════════════╝")"
    echo
    ui_center_color "$GRAY" "Powered by Arnoplays • v${ARNO_VERSION}"
    echo
}

# ----------------------------------------------------------------------------
# Read numeric choice
# ----------------------------------------------------------------------------
ui_read_choice() {
    local prompt="$1"
    local valid="$2"
    local input
    while true; do
        read -rp "$(c "$WHITE_BOLD" "$prompt") $(c "$GRAY" ": ")" input
        if [[ " $valid " == *" $input "* ]]; then
            echo "$input"
            return
        fi
        ui_print_warning "Invalid choice. Valid: $(echo "$valid" | tr ' ' ', ')"
    done
}

# ----------------------------------------------------------------------------
# Error box
# ----------------------------------------------------------------------------
ui_error_box() {
    local title="$1"; shift
    local lines=("$@")
    echo
    local width=50
    local top bottom
    top="╔"; bottom="╚"
    local i
    for (( i=0; i<width; i++ )); do top+='═'; bottom+='═'; done
    top+='╗'; bottom+='╝'

    printf '\n  %s\n' "$(c "$RED_BOLD" "$top")"
    printf '  %s %s %s\n' \
        "$(c "$RED_BOLD" "║")" \
        "$(c "$WHITE_BOLD" "$(printf ' %s' "$title" | head -c $((width-2)))")" \
        "$(c "$RED_BOLD" "║")"
    printf '  %s\n' "$(c "$RED_BOLD" "╠══════════════════════════════════════════════════╣")"
    for line in "${lines[@]}"; do
        printf '  %s %-48s %s\n' \
            "$(c "$RED_BOLD" "║")" \
            "$(c "$WHITE" "$line")" \
            "$(c "$RED_BOLD" "║")"
    done
    printf '  %s\n' "$(c "$RED_BOLD" "$bottom")"
    echo
}

# ----------------------------------------------------------------------------
# Success box
# ----------------------------------------------------------------------------
ui_success_box() {
    local title="$1"; shift
    local lines=("$@")
    echo
    local width=50
    local top bottom
    top="╔"; bottom="╚"
    local i
    for (( i=0; i<width; i++ )); do top+='═'; bottom+='═'; done
    top+='╗'; bottom+='╝'

    printf '\n  %s\n' "$(c "$GREEN" "$top")"
    printf '  %s %s %s\n' \
        "$(c "$GREEN" "║")" \
        "$(c "$WHITE_BOLD" "$title")" \
        "$(c "$GREEN" "║")"
    printf '  %s\n' "$(c "$GREEN" "╠══════════════════════════════════════════════════╣")"
    for line in "${lines[@]}"; do
        printf '  %s %-48s %s\n' \
            "$(c "$GREEN" "║")" \
            "$(c "$WHITE" "$line")" \
            "$(c "$GREEN" "║")"
    done
    printf '  %s\n' "$(c "$GREEN" "$bottom")"
    echo
}

# ----------------------------------------------------------------------------
# Exit screen
# ----------------------------------------------------------------------------
ui_show_exit_screen() {
    echo
    ui_center_color "$RED_BOLD" "Thank you for using ARNO Installer"
    ui_center_color "$GRAY" "Powered by Arnoplays"
    echo
}

# ----------------------------------------------------------------------------
# Press any key
# ----------------------------------------------------------------------------
ui_press_any_key() {
    local msg="${1:-Press any key to continue...}"
    read -n 1 -rsp "$(c "$GRAY" "$msg")"
    echo
}
