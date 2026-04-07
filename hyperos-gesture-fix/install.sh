#!/bin/bash
# install.sh — HyperOS Gesture Navigation Fix: One-Command Installer
#
# Runs on your LAPTOP with device connected via ADB.
# Does everything: pulls stock APK, patches it, builds module, installs, reboots.
#
# Requirements (laptop): bash, python3 OR smali+baksmali, apktool, adb, zip
# Requirements (phone): rooted with KernelSU, Magisk, or APatch
#
# Usage: ./install.sh
# Author: Or10n  https://github.com/Or10n

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK=$(mktemp -d)
MODULE_TEMPLATE="$SCRIPT_DIR/module"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[x]${NC} $1"; cleanup; exit 1; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  HyperOS Gesture Navigation Fix v1.0${NC}"
echo -e "${CYAN}  One-Command Installer${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# ──────────────────────────────────────────────────────────────
# Check prerequisites
# ──────────────────────────────────────────────────────────────

log "Checking prerequisites..."

which adb >/dev/null 2>&1 || fail "adb not found. Install Android platform-tools."
which apktool >/dev/null 2>&1 || fail "apktool not found. Install: sudo apt install apktool"
which zip >/dev/null 2>&1 || fail "zip not found. Install: sudo apt install zip"

# Check for smali/baksmali (not needed — we only need smali for reassembly)
if which smali >/dev/null 2>&1; then
    SMALI_CMD="smali assemble"
    info "Using system smali"
elif which java >/dev/null 2>&1 && [ -f "$SCRIPT_DIR/tools/smali.jar" ]; then
    SMALI_CMD="java -jar $SCRIPT_DIR/tools/smali.jar assemble"
    info "Using bundled smali.jar"
else
    fail "smali not found. Install: sudo apt install libsmali-java"
fi

# Check device connection
log "Checking device connection..."
adb devices 2>/dev/null | grep -q "device$" || fail "No device connected. Connect via USB and enable ADB."

# Verify root access
adb shell "su -c 'id'" 2>/dev/null | grep -q "uid=0" || fail "Root access not available. Ensure KernelSU/Magisk is working."

# Detect root manager
ROOT_MGR="unknown"
if adb shell "su -c 'ls /data/adb/ksud'" >/dev/null 2>&1; then
    ROOT_MGR="kernelsu"
elif adb shell "su -c 'ls /data/adb/magisk'" >/dev/null 2>&1; then
    ROOT_MGR="magisk"
elif adb shell "su -c 'ls /data/adb/ap'" >/dev/null 2>&1; then
    ROOT_MGR="apatch"
fi
info "Root manager: $ROOT_MGR"

# Get device info
DEVICE=$(adb shell "getprop ro.product.model" 2>/dev/null | tr -d '\r')
ANDROID=$(adb shell "getprop ro.build.version.release" 2>/dev/null | tr -d '\r')
HYPEROS=$(adb shell "getprop ro.mi.os.version.name" 2>/dev/null | tr -d '\r')
info "Device: $DEVICE | Android $ANDROID | $HYPEROS"
echo ""

# ──────────────────────────────────────────────────────────────
# Step 1: Pull stock MiuiHome APK
# ──────────────────────────────────────────────────────────────

log "Step 1: Pulling stock MiuiHome APK from device..."

MIUI_HOME_PATH=$(adb shell "su -c 'find /product /system /system_ext -name MiuiHome.apk -path \"*/priv-app/*\" 2>/dev/null'" | head -1 | tr -d '\r')
if [ -z "$MIUI_HOME_PATH" ]; then
    fail "MiuiHome.apk not found on device. Is this a Xiaomi/HyperOS device?"
fi

info "Found: $MIUI_HOME_PATH"
adb pull "$MIUI_HOME_PATH" "$WORK/MiuiHome.apk" 2>&1 | tail -1

# ──────────────────────────────────────────────────────────────
# Step 2: Decompile
# ──────────────────────────────────────────────────────────────

log "Step 2: Decompiling APK..."
apktool d "$WORK/MiuiHome.apk" -o "$WORK/decompiled" -f 2>&1 | tail -2

VERSION=$(grep "versionName:" "$WORK/decompiled/apktool.yml" 2>/dev/null | head -1 | awk '{print $2}')
info "MiuiHome version: $VERSION"
echo ""

# ──────────────────────────────────────────────────────────────
# Step 3: Apply patches
# ──────────────────────────────────────────────────────────────

log "Step 3: Applying gesture navigation patches..."

if [ -f "$SCRIPT_DIR/tools/patcher.py" ]; then
    python3 "$SCRIPT_DIR/tools/patcher.py" "$WORK/decompiled"
elif [ -f "$SCRIPT_DIR/tools/patcher.sh" ]; then
    sh "$SCRIPT_DIR/tools/patcher.sh" "$WORK/decompiled"
else
    fail "No patcher found in $SCRIPT_DIR/tools/"
fi

if [ $? -ne 0 ]; then
    fail "Patching failed! Check output above."
fi
echo ""

# ──────────────────────────────────────────────────────────────
# Step 4: Reassemble DEX files
# ──────────────────────────────────────────────────────────────

log "Step 4: Reassembling DEX files..."

mkdir -p "$WORK/dex_out"
for sdir in "$WORK/decompiled"/smali*; do
    [ -d "$sdir" ] || continue
    dname=$(basename "$sdir")
    if [ "$dname" = "smali" ]; then dex="classes.dex"; else dex="${dname#smali_}.dex"; fi
    info "  $dname -> $dex"
    $SMALI_CMD "$sdir" -o "$WORK/dex_out/$dex" 2>&1
    [ ! -f "$WORK/dex_out/$dex" ] && fail "Failed to assemble $dex"
done

# Build patched APK
cp "$WORK/MiuiHome.apk" "$WORK/MiuiHome_patched.apk"
cd "$WORK/dex_out"
zip -j "$WORK/MiuiHome_patched.apk" classes*.dex >/dev/null 2>&1
cd "$SCRIPT_DIR"
echo ""

# ──────────────────────────────────────────────────────────────
# Step 5: Build module ZIP with patched APK baked in
# ──────────────────────────────────────────────────────────────

log "Step 5: Building module..."

MODULE_DIR="$WORK/module_build"
mkdir -p "$MODULE_DIR/META-INF/com/google/android"

# Copy module template files
cp "$MODULE_TEMPLATE/module.prop" "$MODULE_DIR/"
cp "$MODULE_TEMPLATE/service.sh" "$MODULE_DIR/"
cp "$MODULE_TEMPLATE/post-fs-data.sh" "$MODULE_DIR/"
cp "$MODULE_TEMPLATE/uninstall.sh" "$MODULE_DIR/"
cp "$MODULE_TEMPLATE/system.prop" "$MODULE_DIR/"
cp "$MODULE_TEMPLATE/META-INF/com/google/android/update-binary" "$MODULE_DIR/META-INF/com/google/android/"
cp "$MODULE_TEMPLATE/META-INF/com/google/android/updater-script" "$MODULE_DIR/META-INF/com/google/android/"

# Include the patched APK and original path
cp "$WORK/MiuiHome_patched.apk" "$MODULE_DIR/"
echo "$MIUI_HOME_PATH" > "$MODULE_DIR/original_apk_path.txt"

# Create a customize.sh that just sets up the overlay
cat > "$MODULE_DIR/customize.sh" << 'CUSTOMIZE'
#!/system/bin/sh
SKIPUNZIP=1

ui_print ""
ui_print "============================================"
ui_print "  HyperOS Gesture Navigation Fix v1.0"
ui_print "  Third-party launcher gesture support"
ui_print "============================================"
ui_print ""

# Extract all module files
ui_print "[*] Installing module files..."
unzip -o "$ZIPFILE" -d "$MODPATH" >/dev/null 2>&1

# Set permissions
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
[ -f "$MODPATH/uninstall.sh" ] && set_perm "$MODPATH/uninstall.sh" 0 0 0755

ui_print "[+] Module installed!"
ui_print ""
ui_print "  Reboot to activate."
ui_print "  Then set any launcher as default."
ui_print "  Gesture navigation will stay active!"
ui_print ""
ui_print "  To revert: uninstall this module & reboot"
ui_print "============================================"
ui_print ""
CUSTOMIZE

chmod 755 "$MODULE_DIR/service.sh" "$MODULE_DIR/post-fs-data.sh" "$MODULE_DIR/uninstall.sh"
chmod 755 "$MODULE_DIR/META-INF/com/google/android/update-binary"

# Package
cd "$MODULE_DIR"
MODULE_ZIP="$WORK/HyperOS-Gesture-Nav-Fix.zip"
zip -r "$MODULE_ZIP" . -x "*.DS_Store" >/dev/null 2>&1
cd "$SCRIPT_DIR"

ZIP_SIZE=$(du -h "$MODULE_ZIP" | cut -f1)
info "Module ZIP: $ZIP_SIZE"
echo ""

# ──────────────────────────────────────────────────────────────
# Step 6: Install module on device
# ──────────────────────────────────────────────────────────────

log "Step 6: Installing module on device..."

adb push "$MODULE_ZIP" /data/local/tmp/gesture-fix.zip 2>&1 | tail -1

case "$ROOT_MGR" in
    kernelsu)
        adb shell "su -c 'ksud module install /data/local/tmp/gesture-fix.zip'" 2>&1
        ;;
    magisk)
        adb shell "su -c 'magisk --install-module /data/local/tmp/gesture-fix.zip'" 2>&1
        ;;
    *)
        # Generic: extract manually
        warn "Unknown root manager. Installing manually..."
        adb shell "su -c 'mkdir -p /data/adb/modules/hyperos_gesture_nav'" 2>&1
        adb shell "su -c 'unzip -o /data/local/tmp/gesture-fix.zip -d /data/adb/modules/hyperos_gesture_nav/'" 2>&1
        ;;
esac

# Clean up device temp
adb shell "su -c 'rm -f /data/local/tmp/gesture-fix.zip'" 2>&1

echo ""

# ──────────────────────────────────────────────────────────────
# Step 7: Save a local copy + reboot prompt
# ──────────────────────────────────────────────────────────────

# Save the module ZIP locally for backup
cp "$MODULE_ZIP" "$SCRIPT_DIR/HyperOS-Gesture-Nav-Fix-v1.0.zip" 2>/dev/null || true

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Installation complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "  Module installed on device."
echo "  A copy has been saved to:"
echo "  $SCRIPT_DIR/HyperOS-Gesture-Nav-Fix-v1.0.zip"
echo ""
read -p "  Reboot device now? [y/N] " answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    log "Rebooting device..."
    adb reboot
    echo ""
    echo "  Device is rebooting. After boot:"
    echo "  1. Set your preferred launcher as default"
    echo "  2. Enjoy gesture navigation!"
else
    echo ""
    echo "  When ready, reboot your device manually."
    echo "  Then set any launcher as default."
fi
echo ""
