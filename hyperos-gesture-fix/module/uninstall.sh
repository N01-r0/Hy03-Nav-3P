#!/system/bin/sh
# uninstall.sh — Clean up on module removal
# Author: Or10n  https://github.com/Or10n

# Reset navigation settings to default (3-button)
settings put secure navigation_mode 0 2>/dev/null
settings delete global force_fsg_nav_bar 2>/dev/null
resetprop --delete persist.sys.gesture_nav 2>/dev/null
