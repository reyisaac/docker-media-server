#!/bin/bash

# ============================================================================
# 24/7 Media Server - Disable ALL Sleep/Suspend
# ============================================================================
# This script disables all power management features that could cause
# the system to sleep, suspend, or shut down unexpectedly.
#
# Run this script after any OS reinstall or major updates!
# ============================================================================

set -e

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║      24/7 MEDIA SERVER - DISABLE SLEEP/SUSPEND               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  This script requires sudo privileges."
    echo "   Please run with: sudo $0"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Disable systemd sleep targets"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
echo "✅ Systemd sleep targets masked"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Configure systemd-logind"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create logind.conf drop-in
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/no-sleep.conf << 'LOGINDEOF'
[Login]
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
IdleAction=ignore
IdleActionSec=0
LOGINDEOF

echo "✅ systemd-logind configured to ignore all sleep triggers"

# Restart logind
systemctl restart systemd-logind
echo "✅ systemd-logind restarted"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Disable GNOME power management (for all users)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# This is the KEY fix - GNOME can override systemd settings!

# Get the actual user (not root)
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_UID=$(id -u "$ACTUAL_USER")

echo "Configuring for user: $ACTUAL_USER (UID: $ACTUAL_UID)"

# Run gsettings as the actual user
sudo -u "$ACTUAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" \
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0

sudo -u "$ACTUAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" \
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0

sudo -u "$ACTUAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" \
    gsettings set org.gnome.desktop.session idle-delay 0

echo "✅ GNOME power settings disabled"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Disable screen blanking"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

sudo -u "$ACTUAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" \
    gsettings set org.gnome.desktop.screensaver lock-enabled false

sudo -u "$ACTUAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" \
    gsettings set org.gnome.desktop.screensaver idle-activation-enabled false

echo "✅ Screen blanking and lock disabled"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Disable USB autosuspend (prevents USB device issues)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > /etc/udev/rules.d/50-usb-power-management.rules << 'UDEVEOF'
# Disable USB autosuspend for all devices
ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="on"
UDEVEOF

udevadm control --reload-rules
echo "✅ USB autosuspend disabled"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6: Configure Docker to start on boot"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

systemctl enable docker
echo "✅ Docker enabled on boot"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 7: Verify current settings"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "Sleep targets status:"
systemctl status sleep.target suspend.target hibernate.target 2>&1 | grep -E "(Loaded|Active)" || true

echo ""
echo "GNOME sleep timeout (should be 0):"
sudo -u "$ACTUAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" \
    gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                   ✅ CONFIGURATION COMPLETE!                  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Your system is now configured for 24/7 operation:"
echo "  ✅ All sleep/suspend modes disabled"
echo "  ✅ GNOME won't auto-sleep"
echo "  ✅ Docker starts on boot"
echo "  ✅ USB devices stay awake"
echo ""
echo "⚠️  IMPORTANT: For complete protection against power outages:"
echo "   1. Enter BIOS (DEL/F2 on boot)"
echo "   2. Set 'AC Power Recovery' to 'ALWAYS ON'"
echo "   3. Enable 'Wake on LAN' (optional)"
echo "   4. Consider getting a UPS (~$100)"
echo ""
echo "🎯 Your media server will now stay on 24/7!"
echo ""

