#!/data/data/com.termux/files/usr/bin/bash
# install_termux.sh — HyperOS Gesture Navigation Fix: Termux Installer
#
# Runs entirely on-device via Termux. No computer needed.
# Uses Termux's own Java/Python (NOT Android's app_process).
#
# Requirements: Termux with python, openjdk-17, apktool, zip, root access (tsu)
#
# Usage: ./install_termux.sh
# Author: Or10n  https://github.com/Or10n

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK=$(mktemp -d)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
fail() { echo -e "${RED}[x]${NC} $1"; rm -rf "$WORK"; exit 1; }
info() { echo -e "${CYAN}[i]${NC} $1"; }

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  HyperOS Gesture Navigation Fix v1.0${NC}"
echo -e "${CYAN}  Termux On-Device Installer${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# ──────────────────────────────────────────────────────────────
# Check prerequisites
# ──────────────────────────────────────────────────────────────

log "Checking prerequisites..."

which python3 >/dev/null 2>&1 || fail "python3 not found. Run: pkg install python"
which java >/dev/null 2>&1 || fail "java not found. Run: pkg install openjdk-17"
which zip >/dev/null 2>&1 || fail "zip not found. Run: pkg install zip"

# Check for apktool — handle the #!/bin/bash shebang issue on Android
APKTOOL_CMD=""
if bash "$(which apktool 2>/dev/null)" --version >/dev/null 2>&1; then
    APKTOOL_CMD="bash $(which apktool)"
elif [ -f "$HOME/bin/apktool.jar" ]; then
    APKTOOL_CMD="java -jar $HOME/bin/apktool.jar"
elif [ -f "$SCRIPT_DIR/tools/apktool.jar" ]; then
    APKTOOL_CMD="java -jar $SCRIPT_DIR/tools/apktool.jar"
else
    fail "apktool not found. See SETUP_TERMUX.md for install instructions."
fi
info "Using apktool: $APKTOOL_CMD ($(${APKTOOL_CMD} --version 2>/dev/null))"

# Check for smali — search multiple locations
SMALI_CMD=""
if which smali >/dev/null 2>&1; then
    # Test if the smali command actually works (system packages may be broken)
    if smali --version >/dev/null 2>&1; then
        SMALI_CMD="smali assemble"
    fi
fi
if [ -z "$SMALI_CMD" ] && [ -f "$HOME/bin/smali.jar" ]; then
    SMALI_CMD="java -jar $HOME/bin/smali.jar assemble"
elif [ -z "$SMALI_CMD" ] && [ -f "$SCRIPT_DIR/tools/smali.jar" ]; then
    SMALI_CMD="java -jar $SCRIPT_DIR/tools/smali.jar assemble"
fi
if [ -z "$SMALI_CMD" ]; then
    # Try to find any smali jar on the system
    SMALI_JAR=$(find "${PREFIX:-/data/data/com.termux/files/usr}" "$HOME" -name "smali*.jar" 2>/dev/null | head -1)
    if [ -n "$SMALI_JAR" ]; then
        SMALI_CMD="java -jar $SMALI_JAR assemble"
    else
        fail "smali not found. Download smali-2.5.2.jar to ~/bin/smali.jar — see SETUP_TERMUX.md"
    fi
fi
info "Using smali: $SMALI_CMD"

# Check root access
if ! su -c 'id' 2>/dev/null | grep -q "uid=0"; then
    fail "Root access not available. Make sure KernelSU/Magisk grants Termux root."
fi

log "All prerequisites met!"

# Detect root manager
ROOT_MGR="unknown"
if su -c 'ls /data/adb/ksud' >/dev/null 2>&1; then
    ROOT_MGR="kernelsu"
elif su -c 'ls /data/adb/magisk' >/dev/null 2>&1; then
    ROOT_MGR="magisk"
elif su -c 'ls /data/adb/ap' >/dev/null 2>&1; then
    ROOT_MGR="apatch"
fi
info "Root manager: $ROOT_MGR"
echo ""

# ──────────────────────────────────────────────────────────────
# Step 1: Copy stock MiuiHome APK
# ──────────────────────────────────────────────────────────────

log "Step 1: Finding stock MiuiHome APK..."

MIUI_HOME_PATH=""
for path in \
    /product/priv-app/MiuiHome/MiuiHome.apk \
    /system/product/priv-app/MiuiHome/MiuiHome.apk \
    /system/priv-app/MiuiHome/MiuiHome.apk \
    /system_ext/priv-app/MiuiHome/MiuiHome.apk; do
    if su -c "[ -f '$path' ]" 2>/dev/null; then
        MIUI_HOME_PATH="$path"
        break
    fi
done

if [ -z "$MIUI_HOME_PATH" ]; then
    fail "MiuiHome.apk not found. Is this a Xiaomi/HyperOS device?"
fi

info "Found: $MIUI_HOME_PATH"
su -c "cp '$MIUI_HOME_PATH' '$WORK/MiuiHome.apk'"
chmod 644 "$WORK/MiuiHome.apk"

# ──────────────────────────────────────────────────────────────
# Step 2: Decompile
# ──────────────────────────────────────────────────────────────

log "Step 2: Decompiling APK (this takes ~20 seconds)..."
$APKTOOL_CMD d "$WORK/MiuiHome.apk" -o "$WORK/decompiled" -f 2>&1 | tail -2

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

[ $? -ne 0 ] && fail "Patching failed!"
echo ""

# ──────────────────────────────────────────────────────────────
# Step 4: Reassemble DEX files
# ──────────────────────────────────────────────────────────────

log "Step 4: Reassembling DEX files (this takes ~30 seconds)..."

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
# Step 5: Build and install module
# ──────────────────────────────────────────────────────────────

log "Step 5: Building and installing module..."

MODULE_DIR="$WORK/module_build"
mkdir -p "$MODULE_DIR/META-INF/com/google/android"

cp "$SCRIPT_DIR/module/module.prop" "$MODULE_DIR/"
cp "$SCRIPT_DIR/module/service.sh" "$MODULE_DIR/"
cp "$SCRIPT_DIR/module/post-fs-data.sh" "$MODULE_DIR/"
cp "$SCRIPT_DIR/module/uninstall.sh" "$MODULE_DIR/"
cp "$SCRIPT_DIR/module/system.prop" "$MODULE_DIR/"
cp "$SCRIPT_DIR/module/META-INF/com/google/android/update-binary" "$MODULE_DIR/META-INF/com/google/android/"
cp "$SCRIPT_DIR/module/META-INF/com/google/android/updater-script" "$MODULE_DIR/META-INF/com/google/android/"

cp "$WORK/MiuiHome_patched.apk" "$MODULE_DIR/"
echo "$MIUI_HOME_PATH" > "$MODULE_DIR/original_apk_path.txt"

# Create customize.sh
cat > "$MODULE_DIR/customize.sh" << 'CUSTOMIZE'
#!/system/bin/sh
SKIPUNZIP=1
ui_print ""
ui_print "============================================"
ui_print "  HyperOS Gesture Navigation Fix v1.0"
ui_print "============================================"
ui_print ""
ui_print "[*] Installing module files..."
unzip -o "$ZIPFILE" -d "$MODPATH" >/dev/null 2>&1
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
[ -f "$MODPATH/uninstall.sh" ] && set_perm "$MODPATH/uninstall.sh" 0 0 0755
ui_print "[+] Done! Reboot to activate."
ui_print ""
CUSTOMIZE

chmod 755 "$MODULE_DIR/service.sh" "$MODULE_DIR/post-fs-data.sh" "$MODULE_DIR/uninstall.sh"
chmod 755 "$MODULE_DIR/META-INF/com/google/android/update-binary"

# Package ZIP
MODULE_ZIP="$WORK/gesture-fix.zip"
cd "$MODULE_DIR"
zip -r "$MODULE_ZIP" . >/dev/null 2>&1
cd "$SCRIPT_DIR"

# Install
su -c "cp '$MODULE_ZIP' /data/local/tmp/gesture-fix.zip"

case "$ROOT_MGR" in
    kernelsu)
        log "Installing via KernelSU..."
        su -c 'ksud module install /data/local/tmp/gesture-fix.zip' 2>&1
        ;;
    magisk)
        log "Installing via Magisk..."
        su -c 'magisk --install-module /data/local/tmp/gesture-fix.zip' 2>&1
        ;;
    *)
        warn "Unknown root manager — installing manually..."
        su -c 'mkdir -p /data/adb/modules/hyperos_gesture_nav'
        su -c 'unzip -o /data/local/tmp/gesture-fix.zip -d /data/adb/modules/hyperos_gesture_nav/'
        ;;
esac

su -c 'rm -f /data/local/tmp/gesture-fix.zip'

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Installation complete!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "  Reboot your device to activate."
echo "  Then set any launcher as default."
echo "  Gesture navigation will stay active!"
echo ""
echo "  To revert: uninstall the module & reboot."
echo ""
read -p "  Reboot now? [y/N] " answer
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    log "Rebooting..."
    su -c 'reboot'
else
    echo "  Run 'su -c reboot' when ready."
fi
echo ""
