#!/system/bin/sh
# service.sh — Gesture Navigation Daemon
# Handles: bind-mounting patched APK, removing data updates, maintaining gesture settings
# Author: Or10n  https://github.com/Or10n

MODDIR=${0%/*}
LOG="$MODDIR/daemon.log"

log() { echo "$(date '+%H:%M:%S') $1" >> "$LOG"; }

# Wait for boot to complete
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done
sleep 5

log "=== Service started ==="

# ──────────────────────────────────────────────────────────────
# Bind-mount patched APK over stock
# ──────────────────────────────────────────────────────────────

if [ -f "$MODDIR/MiuiHome_patched.apk" ]; then
    MIUI_HOME_APK=$(cat "$MODDIR/original_apk_path.txt" 2>/dev/null | tr -d '\r')

    if [ -n "$MIUI_HOME_APK" ] && [ -f "$MIUI_HOME_APK" ]; then
        # Remove MiuiHome updates from /data/app/ (they override system APK)
        MIUI_DATA=$(pm path com.miui.home 2>/dev/null | grep "/data/app/" | head -1)
        if [ -n "$MIUI_DATA" ]; then
            log "Removing MiuiHome update from /data/app"
            pm uninstall -k --user 0 com.miui.home >/dev/null 2>&1
            sleep 2
        fi

        # Check if already mounted (e.g. by overlay module)
        CURRENT_MD5=$(md5sum "$MIUI_HOME_APK" 2>/dev/null | awk '{print $1}')
        PATCHED_MD5=$(md5sum "$MODDIR/MiuiHome_patched.apk" 2>/dev/null | awk '{print $1}')

        if [ "$CURRENT_MD5" != "$PATCHED_MD5" ]; then
            mount -o bind "$MODDIR/MiuiHome_patched.apk" "$MIUI_HOME_APK" 2>/dev/null
            if [ $? -eq 0 ]; then
                log "Bind-mounted patched APK over $MIUI_HOME_APK"
                # Force MiuiHome to restart with patched version
                am force-stop com.miui.home >/dev/null 2>&1
                sleep 2
            else
                log "WARNING: Bind mount failed"
            fi
        else
            log "Patched APK already active (checksums match)"
        fi
    else
        log "WARNING: Original APK path not found: $MIUI_HOME_APK"
    fi
else
    log "WARNING: No MiuiHome_patched.apk found in module"
fi

# ──────────────────────────────────────────────────────────────
# Gesture settings daemon (runs continuously)
# ──────────────────────────────────────────────────────────────

log "Starting gesture settings daemon"

ensure_gestures() {
    local current_mode=$(settings get secure navigation_mode 2>/dev/null)
    if [ "$current_mode" != "2" ]; then
        settings put secure navigation_mode 2 >/dev/null 2>&1
        log "Fixed navigation_mode: $current_mode -> 2"
    fi

    local fsg=$(settings get global force_fsg_nav_bar 2>/dev/null)
    if [ "$fsg" != "1" ]; then
        settings put global force_fsg_nav_bar 1 >/dev/null 2>&1
        log "Fixed force_fsg_nav_bar: $fsg -> 1"
    fi

    # Force gestural navigation overlay ON — prevents 3-button fallback entirely
    # On HyperOS, 3-button nav is just the default when the gestural overlay is disabled.
    # By keeping this overlay forcibly enabled, the system has no 3-button mode to fall back to.
    cmd overlay enable com.android.internal.systemui.navbar.gestural >/dev/null 2>&1
    cmd overlay enable com.android.systemui.gesture.line.overlay >/dev/null 2>&1
}

ensure_gestures

while true; do
    ensure_gestures
    sleep 5
done
