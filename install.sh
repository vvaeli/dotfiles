#!/usr/bin/env bash
# Installs the md3 Hyprland desktop (Quickshell shell, themes, scripts) for the current user.
#
#   ./install.sh               packages + configs
#   ./install.sh --no-packages only configs (packages are already there)
#   ./install.sh --greeter     also the md3 login screen (greetd + ReGreet, asks for sudo)
#
# Files that would be replaced are moved to ~/.local/state/md3-dotfiles/backup-<time>/ first.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
packages=1
greeter=0
for argument in "$@"; do
    case "$argument" in
        --no-packages) packages=0 ;;
        --greeter) greeter=1 ;;
        -h|--help) sed -n 2,8p "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Неизвестный параметр: $argument (см. --help)" >&2; exit 1 ;;
    esac
done

say() { printf '\033[1;35m::\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }

[[ $EUID -ne 0 ]] || { warn "Запускай от своего пользователя, не от root: sudo спросится сам."; exit 1; }

# ---------------------------------------------------------------- packages
if (( packages )); then
    command -v pacman >/dev/null || { warn "Нужен Arch Linux (pacman). Поставь пакеты из packages/ вручную и запусти с --no-packages."; exit 1; }
    mapfile -t list < <(grep -v '^\s*#' "$repo/packages/pacman.txt" | awk 'NF {print $1}')
    (( greeter )) && mapfile -t -O "${#list[@]}" list < <(grep -v '^\s*#' "$repo/packages/greeter.txt" | awk 'NF {print $1}')
    say "Ставлю пакеты (${#list[@]} шт.)"
    sudo pacman -S --needed "${list[@]}"
    helper="$(command -v paru || command -v yay || true)"
    mapfile -t aur < <(grep -v '^\s*#' "$repo/packages/aur.txt" | awk 'NF {print $1}')
    if [[ -n "$helper" ]]; then
        say "AUR через ${helper##*/}: ${aur[*]}"
        "$helper" -S --needed "${aur[@]}" || warn "AUR-пакеты не поставились; без них не будет только видео-обоев."
    else
        warn "paru/yay не найден: пропускаю AUR (${aur[*]}) — без него не будет только видео-обоев."
    fi
fi

# ---------------------------------------------------------------- configs
stamp="$(date +%Y%m%d-%H%M%S)"
backup="$HOME/.local/state/md3-dotfiles/backup-$stamp"
moved=0
keep_aside() {  # keep_aside <path relative to $HOME>
    local relative="$1"
    [[ -e "$HOME/$relative" || -L "$HOME/$relative" ]] || return 0
    mkdir -p "$backup/$(dirname "$relative")"
    mv "$HOME/$relative" "$backup/$relative"
    moved=1
}

say "Копирую конфиги"
# Whole directories owned by this setup are replaced as a unit, so stale files cannot linger.
for directory in .config/hypr .config/quickshell/md3 .config/spicetify/Themes/md3 .local/share/Steam/millennium/themes/md3; do
    [[ -d "$repo/home/$directory" ]] && keep_aside "$directory"
done
while IFS= read -r -d '' file; do
    relative="${file#"$repo/home/"}"
    [[ -e "$HOME/$relative" ]] && keep_aside "$relative"
    mkdir -p "$HOME/$(dirname "$relative")"
    if [[ -L "$file" ]]; then
        cp -P "$file" "$HOME/$relative"
    elif grep -qI -e '@HOME@' -e '@USER@' "$file" 2>/dev/null; then
        sed -e "s|@HOME@|$HOME|g" -e "s|@USER@|$USER|g" "$file" > "$HOME/$relative"
        chmod --reference="$file" "$HOME/$relative"
    else
        cp -p "$file" "$HOME/$relative"
    fi
done < <(find "$repo/home" \( -type f -o -type l \) -print0)
# Hyprland reads hyprland.lua; an old hyprland.conf next to it would only confuse.
keep_aside .config/hypr/hyprland.conf

# btop keeps its other settings; only the theme is switched.
btop="$HOME/.config/btop/btop.conf"
if [[ -f "$btop" ]]; then
    sed -i 's/^color_theme = .*/color_theme = "md3"/' "$btop"
else
    printf 'color_theme = "md3"\n' > "$btop"
fi

# Palette for the first start; the wallpaper menu regenerates it from any picture.
mkdir -p "$HOME/.cache/md3" "$HOME/Pictures/Wallpapers"
cp "$HOME/.local/state/md3/colors.json" "$HOME/.cache/md3/colors.json"
wallpaper="$HOME/Pictures/Wallpapers/md3-default.png"
[[ -f "$wallpaper" ]] || cp "$repo/assets/wallpaper.png" "$wallpaper"
if [[ ! -f "$HOME/.local/state/md3/wallpaper.json" ]]; then
    printf '{"path": "%s", "video": false, "preview": ""}\n' "$wallpaper" > "$HOME/.local/state/md3/wallpaper.json"
fi

say "Собираю ночной режим (md3-nightlight)"
if command -v gcc >/dev/null && command -v wayland-scanner >/dev/null; then
    sh "$HOME/.config/quickshell/md3/tools/nightlight/build.sh" || warn "Ночной режим не собрался — остальное работает."
else
    warn "Нет gcc/wayland-scanner: ночной режим пропущен."
fi

systemctl --user daemon-reload 2>/dev/null || true

# ---------------------------------------------------------------- applications
python3 - "$HOME" <<'PY'
import json, sys
from pathlib import Path
home = Path(sys.argv[1])

def patch(path, change, label):
    if not path.exists():
        return
    try:
        data = json.loads(path.read_text())
        change(data)
        path.write_text(json.dumps(data, indent=4, ensure_ascii=False) + '\n')
        print(f'   {label}: тема md3 включена')
    except (OSError, ValueError, AttributeError) as error:
        print(f'   {label}: не вышло ({error}), включи тему вручную')

def vencord(data):
    themes = data.setdefault('enabledThemes', [])
    if 'md3.css' not in themes: themes.append('md3.css')

def millennium(data):
    data.setdefault('themes', {})['activeTheme'] = 'md3'

patch(home / '.config/Vencord/settings/settings.json', vencord, 'Vencord')
patch(home / '.config/millennium/config.json', millennium, 'Millennium (Steam)')
PY
spicetify="$(command -v spicetify || echo "$HOME/.spicetify/spicetify")"
if [[ -x "$spicetify" ]]; then
    "$spicetify" config current_theme md3 color_scheme md3 inject_css 1 replace_colors 1 inject_theme_js 1 >/dev/null \
        && { "$spicetify" backup apply >/dev/null 2>&1 || "$spicetify" apply >/dev/null 2>&1 || true; } \
        && echo "   Spotify (Spicetify): тема md3 включена" \
        || warn "Spicetify: тему не включил, сделай 'spicetify config current_theme md3 color_scheme md3 && spicetify apply'"
fi

# Desktop-wide dark mode, GTK theme and accent; harmless outside a running session.
python3 "$HOME/.config/quickshell/md3/theme_sync.py" "$(cat "$HOME/.local/state/md3/mode" 2>/dev/null || echo dark)" >/dev/null 2>&1 || true

if (( greeter )); then
    say "Экран входа (greetd + ReGreet)"
    sudo python3 "$HOME/.config/hypr/scripts/setup-greeter.py" || warn "Экран входа не настроен, см. ~/.config/hypr/greeter/README.md"
fi

# Inside a running Hyprland the shell is restarted right away.
if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl reload >/dev/null 2>&1 || true
    "$HOME/.config/hypr/scripts/recover-shell" >/dev/null 2>&1 || true
fi

echo
say "Готово."
(( moved )) && echo "   Старые файлы: $backup"
cat <<EOF
   Дальше: выйди из сеанса и зайди в Hyprland (в менеджере входа — сессия «Hyprland»).
   Обои и цвета: меню обоев в панели (картинки лежат в ~/Pictures/Wallpapers).
   Мониторы: ~/.config/hypr/conf/monitors.lua. Клавиши: ~/.config/hypr/README.md
EOF
