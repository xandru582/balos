# Auto-start Wayland session on tty1 if no DM
if [[ -z "$DISPLAY" && "$XDG_VTNR" -eq 1 ]]; then
    # DM (sddm) starts it; this is fallback for console-only users
    :
fi
