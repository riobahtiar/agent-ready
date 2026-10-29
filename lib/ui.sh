# shellcheck shell=bash
# Interactive prompts for bin/* — gum (mise tool) when it's there, plain bash
# otherwise. Source after lib/common.sh.
#
# Commands open a menu only when ui_interactive is true (a human at a TTY with
# no arguments given). Agents, cron and pipes never see a prompt: they get the
# flag interface, so a missing argument fails fast instead of hanging.
#
# Items are "value|Label". Labels are what people see; the value is printed.
# Keep commas out of labels (gum's --selected is comma-separated).

[[ -n ${__CLOUD_UI_LOADED:-} ]] && return 0
__CLOUD_UI_LOADED=1

ui_interactive() { [[ -t 0 && -t 1 ]] && has_tty; }

_ui_gum() { have gum && [[ ${CLOUD_UI:-} != plain ]]; }

# _ui_label <value> <item...> — label of the item whose value matches.
_ui_label() {
    local want=$1 item
    shift
    for item; do [[ ${item%%|*} == "$want" ]] && printf '%s' "${item#*|}" && return 0; done
    return 1
}

# ui_choose <header> <item...> — print one value; non-zero on cancel.
ui_choose() {
    local header=$1 item
    shift
    if _ui_gum; then
        local -a opts=()
        for item; do opts+=("${item#*|}|${item%%|*}"); done
        gum choose --header "$header" --label-delimiter '|' --height 15 "${opts[@]}"
        return
    fi
    local i=1 answer
    printf '%s%s%s\n' "$C_BOLD" "$header" "$C_RESET" >&2
    for item; do printf '  %2d) %s\n' $((i++)) "${item#*|}" >&2; done
    while :; do
        read -r -p "  choose [1-$#, Enter = cancel]: " answer </dev/tty || return 1
        [[ -z $answer ]] && return 1
        if [[ $answer =~ ^[0-9]+$ ]] && ((answer >= 1 && answer <= $#)); then
            item=${!answer}
            printf '%s\n' "${item%%|*}"
            return 0
        fi
    done
}

# ui_multi <header> <defaults> <item...> — print chosen values, one per line.
# <defaults> is a space-separated list of values, '*' for all, '' for none.
ui_multi() {
    local header=$1 defaults=$2 item value
    shift 2
    local -a pre=()
    for item; do
        value=${item%%|*}
        if [[ $defaults == '*' || " $defaults " == *" $value "* ]]; then pre+=("$value"); fi
    done
    if _ui_gum; then
        local -a opts=() labels=()
        for item; do opts+=("${item#*|}|${item%%|*}"); done
        for value in "${pre[@]}"; do labels+=("$(_ui_label "$value" "$@")"); done
        local selected
        selected="$(
            IFS=,
            printf '%s' "${labels[*]}"
        )"
        gum choose --no-limit --header "$header  (space = toggle · enter = run)" \
            --label-delimiter '|' --height 15 ${selected:+--selected "$selected"} "${opts[@]}"
        return
    fi
    local i=1 answer n mark
    printf '%s%s%s\n' "$C_BOLD" "$header" "$C_RESET" >&2
    for item; do
        mark=' '
        [[ " ${pre[*]} " == *" ${item%%|*} "* ]] && mark='x'
        printf '  %2d) [%s] %s\n' $((i++)) "$mark" "${item#*|}" >&2
    done
    read -r -p "  numbers separated by spaces (Enter = the [x] ones, 0 = cancel): " answer </dev/tty || return 1
    [[ $answer == 0 ]] && return 1
    if [[ -z $answer ]]; then
        ((${#pre[@]})) && printf '%s\n' "${pre[@]}"
        return 0
    fi
    for n in $answer; do
        [[ $n =~ ^[0-9]+$ ]] && ((n >= 1 && n <= $#)) || continue
        item=${!n}
        printf '%s\n' "${item%%|*}"
    done
}

# ui_input <header> [default] [placeholder] — print the typed (or default) text.
ui_input() {
    local header=$1 default=${2:-} placeholder=${3:-}
    if _ui_gum; then
        gum input --header "$header" --value "$default" --placeholder "${placeholder:-$default}"
        return
    fi
    local answer
    read -r -p "$header${default:+ [$default]}: " answer </dev/tty || return 1
    printf '%s\n' "${answer:-$default}"
}

# ui_password <header> — print a masked entry.
ui_password() {
    if _ui_gum; then
        gum input --password --header "$1"
        return
    fi
    local answer
    read -r -s -p "$1: " answer </dev/tty || return 1
    echo >&2
    printf '%s\n' "$answer"
}

# ui_confirm <question> [yes|no] — default no. ASSUME_YES=1 answers yes.
ui_confirm() {
    local question=$1 default=${2:-no}
    [[ ${ASSUME_YES:-0} == 1 ]] && return 0
    has_tty || return 1
    if _ui_gum; then
        local flag=false
        [[ $default == yes ]] && flag=true
        gum confirm --default="$flag" "$question"
        return
    fi
    local answer hint='[y/N]'
    [[ $default == yes ]] && hint='[Y/n]'
    read -r -p "$question $hint " answer </dev/tty || return 1
    [[ -z $answer ]] && answer=${default:0:1}
    [[ $answer =~ ^[Yy] ]]
}

# ui_title <text> — section heading for wizards.
ui_title() { printf '\n%s%s%s\n' "$C_BOLD$C_BLUE" "$*" "$C_RESET" >&2; }

# ui_pause — wait for Enter before a menu redraws over the output.
ui_pause() { read -r -p "${C_DIM}  Enter to continue…${C_RESET}" _ </dev/tty || true; }
