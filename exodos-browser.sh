#!/bin/bash
set -euo pipefail

# ─── Config ───
BASE_URL="https://archive.org/download/exov5_2/eXo/eXoDOS/"
ROM_DIR="${1:-$HOME/Emulation/roms/dos}"

mkdir -p "$ROM_DIR"

# URL-decode a filename for display
urldecode() {
    local s="$1"
    s="${s%.zip}"
    s="${s//%20/ }"
    s="${s//%28/(}"
    s="${s//%29/)}"
    s="${s//%2C/,}"
    s="${s//%24/$}"
    s="${s//%2B/+}"
    s="${s//%21/!}"
    s="${s//%5B/[}"
    s="${s//%5D/]}"
    printf '%s' "$s"
}

main() {
    local tmpfile
    tmpfile=$(mktemp)

    echo ">>> Fetching game list from archive.org..."
    curl -sL "$BASE_URL" | grep -oP 'href="\K[^"]+\.zip(?=")' > "$tmpfile" || {
        echo "Failed to fetch game list. Check your internet connection."
        rm -f "$tmpfile"
        return 1
    }

    mapfile -t all_games < "$tmpfile"
    local total="${#all_games[@]}"
    echo "Found $total games available in eXoDOS v5.2."
    echo "Downloading to: $ROM_DIR"
    echo ""

    while true; do
        echo "─── eXoDOS Game Browser ───"
        read -rp "Search (or 'list' for all, 'done' to finish): " query

        local matches=()
        case "${query,,}" in
            done|"") break ;;
            list)
                for i in "${!all_games[@]}"; do matches+=("$i"); done
                ;;
            *)
                for i in "${!all_games[@]}"; do
                    local display; display=$(urldecode "${all_games[$i]}")
                    if echo "$display" | grep -qi "${query// /.*}"; then
                        matches+=("$i")
                    fi
                done
                if [ "${#matches[@]}" -eq 0 ]; then
                    echo "No matches for '$query'"
                    continue
                fi
                ;;
        esac

        for j in "${!matches[@]}"; do
            local idx="${matches[$j]}"
            local display; display=$(urldecode "${all_games[$idx]}")
            printf "%4d) %s\n" "$((j + 1))" "$display"
        done

        echo ""
        read -rp "Pick numbers to download (e.g. 1 3 5-8, or 'back'): " picks

        [ "$picks" = "back" ] && continue
        [ -z "$picks" ] && continue

        local expanded=""
        for part in $picks; do
            if echo "$part" | grep -q '^[0-9]\+-[0-9]\+$'; then
                expanded="$expanded $(seq "${part%-*}" "${part#*-}")"
            elif echo "$part" | grep -q '^[0-9]\+$'; then
                expanded="$expanded $part"
            fi
        done

        for num in $expanded; do
            [ "$num" -lt 1 ] || [ "$num" -gt "${#matches[@]}" ] && continue
            local idx="${matches[$((num - 1))]}"
            local game="${all_games[$idx]}"
            local display; display=$(urldecode "$game")

            printf ">>> Downloading %s..." "$display"
            curl -sL -o "$ROM_DIR/$game" "$BASE_URL$game" && echo " done" || echo " FAILED"
        done
        echo ""
    done

    rm -f "$tmpfile"
}

main "$@"
