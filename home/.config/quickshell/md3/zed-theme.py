#!/usr/bin/env python3
"""Synchronize the local Zed theme with the shell's saved Material palette."""
import json
import os
from pathlib import Path


def generate():
    home = Path.home()
    cache = Path(os.environ.get('XDG_CACHE_HOME', home / '.cache')) / 'md3/colors.json'
    palette = json.loads(cache.read_text())
    light = palette.get('mode') == 'light'
    bg, card, button, hover = (palette[k] for k in ['surface', 'cardSurface', 'cardInteractive', 'cardHover'])
    accent, text, muted, outline, error = (palette[k] for k in ['primary', 'textSurface', 'muted', 'outline', 'error'])
    selection = palette['primaryContainer']
    green, yellow, pink, cyan = '#a8dab5', '#e8cb8f', '#e2bbdb', '#a5d8df'
    style = {}
    def set_colors(color, keys):
        for key in keys.split():
            style[key] = color
    set_colors(bg, 'background surface.background title_bar.background status_bar.background toolbar.background tab_bar.background tab.inactive_background panel.background editor.background editor.gutter.background terminal.background scrollbar.track.background')
    set_colors(card, 'elevated_surface.background tab.active_background editor.subheader.background editor.active_line.background editor.highlighted_line.background ghost_element.hover')
    set_colors(button, 'element.background element.active ghost_element.active editor.indent_guide')
    set_colors(hover, 'element.hover element.disabled ghost_element.disabled border.disabled')
    set_colors(selection, 'element.selected ghost_element.selected editor.document_highlight.read_background editor.document_highlight.write_background editor.document_highlight.bracket_background')
    set_colors(outline, 'border editor.wrap_guide editor.active_wrap_guide scrollbar.thumb.border scrollbar.track.border')
    set_colors(card, 'border.variant')
    set_colors(accent, 'border.focused border.selected panel.focused_border pane.focused_border text.accent icon.accent editor.active_line_number editor.indent_guide_active link_text.hover')
    set_colors(text, 'text icon editor.foreground terminal.foreground terminal.bright_foreground')
    set_colors(muted, 'text.muted text.placeholder icon.muted icon.placeholder editor.line_number terminal.dim_foreground')
    set_colors(muted + '80', 'text.disabled icon.disabled editor.invisible')
    set_colors('#00000000', 'border.transparent ghost_element.background')
    style.update({'background.appearance': 'opaque', 'drop_target.background': accent + '22',
                  'search.match_background': yellow + '33', 'scrollbar.thumb.background': muted + '33',
                  'scrollbar.thumb.hover_background': muted + '66', 'accents': [accent, pink, cyan]})
    for role, color in {'error': error, 'deleted': error, 'success': green, 'created': green,
                        'warning': yellow, 'conflict': yellow, 'info': accent, 'modified': accent,
                        'renamed': pink, 'hint': muted, 'ignored': muted, 'hidden': muted,
                        'predictive': muted, 'unreachable': muted}.items():
        style[role] = color
        style[role + '.background'] = color + '18'
        style[role + '.border'] = color + '55'
    for name, color in {'black': hover, 'red': error, 'green': green, 'yellow': yellow,
                        'blue': accent, 'magenta': pink, 'cyan': cyan, 'white': text}.items():
        for prefix in ['', 'bright_', 'dim_']:
            style['terminal.ansi.' + prefix + name] = color
    style['players'] = [{'cursor': accent, 'background': accent, 'selection': accent + '33'}]
    # Adapted from JetBrains' Rider Dark scheme, not IDEA Darcula.
    # https://github.com/JetBrains/rider-theme-pack/blob/master/src/main/resources/colorSchemes/RiderDark.xml
    style['editor.foreground'] = text if light else '#BDBDBD'
    syntax = {}
    # Darker hues of the same scheme keep contrast on a light background.
    dark_to_light = {'#6C95EB': '#2F5FC4', '#39CC9B': '#0B7F5A', '#C191FF': '#7B3FC4', '#BDBDBD': text,
                     '#66C3CC': '#167C86', '#E1BFFF': '#8A4FBF', '#C9A26D': '#8D5E14', '#D688D4': '#A3409F',
                     '#ED94C0': '#B23573', '#85C46C': '#4B7F33', '#F0F0F0': text}
    for color, tokens in [
        ('#6C95EB', 'keyword boolean keyword.control keyword.control.conditional keyword.control.repeat keyword.control.return keyword.control.exception keyword.import keyword.coroutine'),
        ('#39CC9B', 'function function.method function.builtin constructor'),
        ('#C191FF', 'type type.builtin namespace attribute tag'),
        ('#BDBDBD', 'variable variable.parameter operator punctuation punctuation.bracket punctuation.delimiter punctuation.special emphasis emphasis.strong'),
        ('#66C3CC', 'variable.member property'),
        ('#E1BFFF', 'constant variable.special'),
        ('#C9A26D', 'string string.special string.special.symbol text.literal string.regex'),
        ('#D688D4', 'string.escape'),
        ('#ED94C0', 'number'),
        ('#85C46C', 'comment comment.doc'),
        ('#F0F0F0', 'label'),
        ('#39CC9B', 'title'),
        ('#6C95EB', 'link_text link_uri'),
    ]:
        for token in tokens.split():
            syntax[token] = {'color': dark_to_light.get(color, color) if light else color}
    syntax['comment']['font_style'] = 'italic'
    syntax['comment.doc']['font_style'] = 'italic'
    syntax['emphasis']['font_style'] = 'italic'
    syntax['emphasis.strong']['font_weight'] = 700
    style['syntax'] = syntax
    theme = {'$schema': 'https://zed.dev/schema/themes/v0.2.0.json', 'name': 'MD3 Shell',
             'author': 'vael', 'themes': [{'name': 'MD3 Shell Dark', 'appearance': 'light' if light else 'dark', 'style': style}]}
    target = home / '.config/zed/themes/md3-shell.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(theme, ensure_ascii=False, indent=2) + '\n'
    if not target.exists() or target.read_text() != encoded:
        temporary = target.with_suffix('.json.tmp')
        temporary.write_text(encoded)
        temporary.replace(target)

if __name__ == '__main__':
    generate()
