# ============================================================================
#  ARNO Installer - Animations & Visual Effects
# ============================================================================

# Cursor control
arno_cursor_hide() { printf '\033[?25l'; }
arno_cursor_show() { printf '\033[?25h'; }
arno_cursor_save() { printf '\033[s'; }
arno_cursor_restore() { printf '\033[u'; }
arno_cursor_up()    { printf '\033[%dA' "${1:-1}"; }
arno_cursor_down()  { printf '\033[%dB' "${1:-1}"; }
arno_cursor_clear_line() { printf '\033[2K\r'; }

# ----------------------------------------------------------------------------
# Typing effect
# ----------------------------------------------------------------------------
arno_type() {
    local text="$1"
    local delay="${2:-0.015}"
    local i char
    for (( i=0; i<${#text}; i++ )); do
        char="${text:$i:1}"
        printf '%s' "$char"
        sleep "$delay"
    done
}

arno_type_color() {
    local color="$1"; shift
    local text="$1"; shift
    local delay="${1:-0.015}"
    if [[ "$ARNO_USE_COLOR" == "1" ]]; then printf '%s' "$color"; fi
    arno_type "$text" "$delay"
    if [[ "$ARNO_USE_COLOR" == "1" ]]; then printf '%s' "$RESET"; fi
}

# ----------------------------------------------------------------------------
# Spinner (animated)
# ----------------------------------------------------------------------------
arno_spinner() {
    # $1 = PID to wait for, $2 = message
    local pid="$1"
    local msg="${2:-Working...}"
    local spin='|/-\'
    local i=0
    local start_time end_time elapsed
    start_time=$(date +%s)

    arno_cursor_hide
    while kill -0 "$pid" 2>/dev/null; do
        local frame="${spin:$((i%4)):1}"
        end_time=$(date +%s)
        elapsed=$((end_time - start_time))
        printf '\r%s %s %s[%02d:%02d]%s' \
            "$(c "$RED" "●")" \
            "$(c "$WHITE" "$msg")" \
            "$(c "$GRAY" "")" \
            $((elapsed/60)) $((elapsed%60)) \
            ""
        printf '\r%s %s %s %s[%02d:%02d]%s' \
            "$(c "$YELLOW" "$frame")" \
            "$(c "$WHITE" "$msg")" \
            "$(c "$GRAY" "...")" \
            "$(c "$GRAY" "")" \
            $((elapsed/60)) $((elapsed%60)) \
            ""
        i=$((i+1))
        sleep 0.08
    done
    wait "$pid"
    local rc=$?
    arno_cursor_clear_line
    arno_cursor_show
    return $rc
}

# ----------------------------------------------------------------------------
# Progress bar
# ----------------------------------------------------------------------------
arno_progress_bar() {
    # $1 = current, $2 = total, $3 = label
    local current="$1"
    local total="${2:-100}"
    local label="${3:-}"
    local width=30
    local pct=$(( (current * 100) / total ))
    local filled=$(( (pct * width) / 100 ))
    local empty=$(( width - filled ))
    local bar=""
    local i
    for (( i=0; i<filled; i++ )); do bar+='█'; done
    for (( i=0; i<empty; i++ )); do bar+='░'; done
    printf '\r%s %s%s %s%3d%%%s' \
        "$(c "$RED_BOLD" "▶")" \
        "$(c "$RED" "$bar")" \
        "" \
        "$(c "$GRAY" "")" \
        "$pct" \
        ""
    if [[ -n "$label" ]]; then
        printf ' %s' "$(c "$GRAY" "$label")"
    fi
    if [[ "$pct" -eq 100 ]]; then
        printf '\n'
    fi
}

# ----------------------------------------------------------------------------
# Animated multi-step progress
# ----------------------------------------------------------------------------
arno_animate_steps() {
    # $1 = total steps, rest = labels
    local total="$1"; shift
    local labels=("$@")
    local i
    for (( i=0; i<total; i++ )); do
        arno_progress_bar $((i+1)) "$total" "${labels[$i]:-}"
        sleep 0.15
    done
}

# ----------------------------------------------------------------------------
# Pulsing text effect
# ----------------------------------------------------------------------------
arno_pulse() {
    local text="$1"
    local pulses="${2:-3}"
    local i
    for (( i=0; i<pulses; i++ )); do
        printf '\r%s' "$(c "$RED_BOLD" "$text")"
        sleep 0.18
        printf '\r%s' "$(c "$GRAY_DIM" "$text")"
        sleep 0.18
    done
    printf '\r%s\n' "$(c "$RED_BOLD" "$text")"
}

# ----------------------------------------------------------------------------
# Fade in (approximate via color stepping)
# ----------------------------------------------------------------------------
arno_fade_in() {
    local text="$1"
    local delay="${2:-0.05}"
    local shades=(
        "$(c "$GRAY_DIM" "$text")"
        "$(c "$GRAY" "$text")"
        "$(c "$WHITE" "$text")"
        "$(c "$RED" "$text")"
        "$(c "$RED_BOLD" "$text")"
    )
    local s
    for s in "${shades[@]}"; do
        printf '\r%s' "$s"
        sleep "$delay"
    done
    printf '\n'
}

# ----------------------------------------------------------------------------
# Blinking cursor effect
# ----------------------------------------------------------------------------
arno_blink_cursor() {
    local count="${1:-4}"
    local i
    for (( i=0; i<count; i++ )); do
        printf '%s' "$(c "$RED" "_")"
        sleep 0.25
        printf '\b \b'
        sleep 0.25
    done
}
