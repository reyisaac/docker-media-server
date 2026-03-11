#!/bin/bash
# Turn off all controllable LEDs: kernel LEDs (NIC, WiFi, etc.) + RGB (OpenRGB)
# Run with: ./turn-off-all-lights.sh   (sudo used only for kernel LEDs)

set -e

echo "Turning off all lights..."
echo ""

# --- Kernel LEDs (NIC, WiFi/phy, keyboard indicators) ---
LED_SYS="/sys/class/leds"
if [ -d "$LED_SYS" ]; then
    count=0
    for brightness in "$LED_SYS"/*/brightness; do
        if [ -f "$brightness" ] && [ -w "$brightness" ]; then
            echo 0 > "$brightness" 2>/dev/null && count=$((count+1)) || true
        fi
    done
    if [ "$count" -gt 0 ]; then
        echo "✓ Set $count kernel LED(s) to off (no sudo needed)."
    else
        echo "Kernel LEDs (NIC/WiFi etc.) require root. Running with sudo..."
        for brightness in "$LED_SYS"/*/brightness; do
            [ -f "$brightness" ] && sudo sh -c "echo 0 > $brightness" 2>/dev/null || true
        done
        echo "✓ Kernel LEDs set to off."
    fi
else
    echo "No /sys/class/leds found."
fi
echo ""

# --- RGB (motherboard, RAM, GPU) via OpenRGB ---
OPENRGB_APPIMAGE="${OPENRGB_APPIMAGE:-$HOME/OpenRGB_1.0rc2_x86_64_0fca93e.AppImage}"
openrgb_quiet() { "$OPENRGB_APPIMAGE" "$@" 2>/dev/null; }

if [ -f "$OPENRGB_APPIMAGE" ] && [ -x "$OPENRGB_APPIMAGE" ]; then
    # Try multiple modes per device (Corsair cooler doesn't support 'static'; NVIDIA needs Direct + brightness 0)
    for i in 0 1 2 3 4 5 6 7 8 9; do
        off=
        openrgb_quiet --device $i --mode static --color 000000 && off=1
        [ -z "$off" ] && openrgb_quiet --device $i --mode direct --color 000000 && off=1
        [ -z "$off" ] && openrgb_quiet --device $i --mode Direct --brightness 0 && off=1
        [ -z "$off" ] && openrgb_quiet --device $i --mode off && off=1
        [ -z "$off" ] && openrgb_quiet --device $i --mode Off && off=1
        [ -n "$off" ] && echo "  OpenRGB device $i: off"
    done
else
    echo "OpenRGB not found at $OPENRGB_APPIMAGE — skipping RGB. Put the AppImage there or set OPENRGB_APPIMAGE."
fi

echo ""
echo "Done. If any lights are still on, they may not be software-controllable (e.g. power LED)."
