#!/bin/bash

custom_cursor_dir="/usr/share/icons/All"
cursor_size=35
index_theme_file="$HOME/.icons/default/index.theme"

# Preload theme list once (sorted alphabetically, directories only, with cursors)
mapfile -t themes < <(find "$custom_cursor_dir" -mindepth 1 -maxdepth 1 -type d \
    -exec test -d "{}/cursors" \; -print | xargs -n1 basename | sort)

[ "${#themes[@]}" -eq 0 ] && exit 0

# Set size once
gsettings set org.gnome.desktop.interface cursor-size "$cursor_size"

# Prepare default folder
mkdir -p "${index_theme_file%/*}"
last_theme=""

# Efficient, low-load theme switch loop
while true; do
    for theme in "${themes[@]}"; do
        [ "$theme" = "$last_theme" ] && continue

        gsettings set org.gnome.desktop.interface cursor-theme "$theme"
        printf "[Icon Theme]\nInherits=%s\n" "$theme" > "$index_theme_file"
        last_theme="$theme"

        sleep 2
    done
done

