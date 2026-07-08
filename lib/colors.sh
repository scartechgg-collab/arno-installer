# ============================================================================
#  ARNO Installer - Color & Style Definitions
# ============================================================================

# Theme: black bg, red primary (#ff2d2d), white text, gray secondary
if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]] && [[ "${NO_COLOR:-}" == "" ]]; then
    export ARNO_USE_COLOR=1
else
    export ARNO_USE_COLOR=0
fi

# Primary brand red (#ff2d2d in truecolor)
export RED=$'\033[38;2;255;45;45m'
export RED_BOLD=$'\033[1;38;2;255;45;45m'
export RED_DIM=$'\033[2;38;2;255;45;45m'

# White
export WHITE=$'\033[38;2;255;255;255m'
export WHITE_BOLD=$'\033[1;38;2;255;255;255m'

# Gray (secondary text)
export GRAY=$'\033[38;2;160;160;160m'
export GRAY_DIM=$'\033[2;38;2;120;120;120m'

# Status colors
export GREEN=$'\033[38;2;80;220;100m'
export YELLOW=$'\033[38;2;255;210;80m'
export BLUE=$'\033[38;2;90;180;255m'
export CYAN=$'\033[38;2;90;220;220m'
export MAGENTA=$'\033[38;2;220;120;255m'

# Style modifiers
export BOLD=$'\033[1m'
export DIM=$'\033[2m'
export ITALIC=$'\033[3m'
export UNDERLINE=$'\033[4m'
export BLINK=$'\033[5m'
export INVERT=$'\033[7m'

# Backgrounds
export BG_BLACK=$'\033[48;2;10;10;12m'
export BG_RED=$'\033[48;2;255;45;45m'

# Reset
export RESET=$'\033[0m'

# Ensure reset on exit
trap 'printf "%s" "$RESET"' EXIT

# ----------------------------------------------------------------------------
# Conditional colorization helper
# ----------------------------------------------------------------------------
c() {
    # Usage: c "$RED" "text"  -> returns text wrapped in color if enabled
    local color="$1"; shift
    local text="$*"
    if [[ "$ARNO_USE_COLOR" == "1" ]]; then
        printf '%s%s%s' "$color" "$text" "$RESET"
    else
        printf '%s' "$text"
    fi
}
