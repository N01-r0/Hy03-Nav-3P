#!/system/bin/sh
# post-fs-data.sh — Early boot gesture settings
# Runs at post-fs-data stage (blocking, before Zygote/SystemUI)
# Author: Or10n  https://github.com/Or10n

MODDIR=${0%/*}

# Set gesture navigation properties as early as possible
resetprop -n persist.sys.gesture_nav 1 2>/dev/null
resetprop -n ro.recents.grid 0 2>/dev/null

# Force gestural overlay ON before SystemUI starts
# This prevents any window where 3-button nav could flash on screen
settings put secure navigation_mode 2 >/dev/null 2>&1
settings put global force_fsg_nav_bar 1 >/dev/null 2>&1
cmd overlay enable com.android.internal.systemui.navbar.gestural >/dev/null 2>&1
cmd overlay enable com.android.systemui.gesture.line.overlay >/dev/null 2>&1
