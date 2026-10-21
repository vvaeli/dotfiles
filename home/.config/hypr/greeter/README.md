ReGreet theme for the MD3 shell

Apply with:

    sudo python3 ~/.config/hypr/scripts/setup-greeter.py

The installer preserves greetd's VT/user/session settings, backs up /etc/greetd,
and installs wlr-randr if missing. Cage runs ReGreet on DP-1 only; other outputs
are disabled for the greeter and configured normally by the user's Hyprland
session. If DP-1 is disconnected, the first available output is used.

The installer takes a snapshot of the shell palette and wallpaper. Re-run it
to update that snapshot. Files are copied to /etc/greetd so the greeter does
not depend on access to the user's home directory. The service is not restarted.

Sources:
https://github.com/rharish101/ReGreet
https://github.com/cage-kiosk/cage/wiki/Configuration
