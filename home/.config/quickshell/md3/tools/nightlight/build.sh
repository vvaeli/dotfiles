#!/bin/sh
# Rebuilds the night light helper (needs wayland-scanner, gcc and libwayland-client).
cd "$(dirname "$0")" || exit 1
wayland-scanner client-header hyprland-ctm-control-v1.xml ctm-protocol.h &&
wayland-scanner private-code hyprland-ctm-control-v1.xml ctm-protocol.c &&
exec gcc -O2 -Wall -o md3-nightlight md3-nightlight.c ctm-protocol.c -lwayland-client -lm
