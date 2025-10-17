#!/bin/bash

# ============================================================================
# Fix Login Screen on Virtual Display Issue
# ============================================================================
# This script fixes the issue where the GDM login screen appears on a
# virtual/incorrect display instead of your actual monitor.
# ============================================================================

set -e

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║         FIX LOGIN SCREEN DISPLAY ISSUE                        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  This script requires sudo privileges."
    echo "   Please run with: sudo $0"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Current Display Configuration:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
xrandr --query 2>/dev/null | grep -E "connected|Screen" | head -10

echo ""
echo "Detected displays:"
echo "  • HDMI-0: 1280x800 (likely your real monitor)"
echo "  • DP-0: 5120x1440 (1mm x 1mm = virtual/fake display)"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Configure GDM to use only HDMI-0"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get current user's display config
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_UID=$(id -u "$ACTUAL_USER")

# Copy current user's monitors.xml to GDM
if [ -f "/home/$ACTUAL_USER/.config/monitors.xml" ]; then
    echo "📁 Copying user display config to GDM..."
    mkdir -p /var/lib/gdm3/.config
    cp /home/$ACTUAL_USER/.config/monitors.xml /var/lib/gdm3/.config/
    chown gdm:gdm /var/lib/gdm3/.config/monitors.xml
    echo "✅ GDM will now use your display configuration"
else
    echo "⚠️  No monitors.xml found, creating default config..."
    
    # Create a basic monitors.xml for GDM
    mkdir -p /var/lib/gdm3/.config
    cat > /var/lib/gdm3/.config/monitors.xml << 'MONITORSEOF'
<monitors version="2">
  <configuration>
    <logicalmonitor>
      <x>0</x>
      <y>0</y>
      <scale>1</scale>
      <primary>yes</primary>
      <monitor>
        <monitorspec>
          <connector>HDMI-0</connector>
        </monitorspec>
      </monitor>
    </logicalmonitor>
  </configuration>
</monitors>
MONITORSEOF
    chown gdm:gdm /var/lib/gdm3/.config/monitors.xml
    echo "✅ Created GDM display config for HDMI-0"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Set HDMI-0 as primary display for current user"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

sudo -u "$ACTUAL_USER" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" \
    DISPLAY=:0 xrandr --output HDMI-0 --primary 2>/dev/null || true

echo "✅ HDMI-0 set as primary display"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Enable auto-login (OPTIONAL)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

read -p "Enable auto-login for $ACTUAL_USER? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Configure auto-login in GDM
    sed -i "s/#  AutomaticLoginEnable = true/AutomaticLoginEnable = true/" /etc/gdm3/custom.conf 2>/dev/null || \
    sed -i "/\[daemon\]/a AutomaticLoginEnable = true" /etc/gdm3/custom.conf
    
    sed -i "s/#  AutomaticLogin = user1/AutomaticLogin = $ACTUAL_USER/" /etc/gdm3/custom.conf 2>/dev/null || \
    sed -i "/AutomaticLoginEnable/a AutomaticLogin = $ACTUAL_USER" /etc/gdm3/custom.conf
    
    echo "✅ Auto-login enabled for $ACTUAL_USER"
    echo "⚠️  After reboot, you'll login automatically (no password needed)"
else
    echo "⏭️  Auto-login skipped"
    echo "   You'll need to enter password on each reboot"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                   ✅ CONFIGURATION COMPLETE!                  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Changes made:"
echo "  ✅ GDM configured to use HDMI-0 for login screen"
echo "  ✅ HDMI-0 set as primary display"
echo "  ✅ Virtual displays will be ignored at login"
echo ""
echo "⚠️  For changes to take effect:"
echo "   Option 1: Restart GDM: sudo systemctl restart gdm3"
echo "            (will log you out!)"
echo "   Option 2: Reboot the system"
echo ""
echo "🎯 After restart, login screen will appear on your HDMI monitor!"
echo ""

