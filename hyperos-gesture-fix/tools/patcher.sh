#!/system/bin/sh
# patcher.sh — Universal MiuiHome Gesture Navigation Smali Patcher (Shell)
#
# Applies 6 patches to decompiled MiuiHome smali to keep gesture navigation
# alive when a third-party launcher is set as default.
#
# Resilient across builds:
#   - Tolerates .line directives (present or absent)
#   - Searches all smali_classesN/ directories
#   - Matches by method signature, not exact byte patterns
#   - Uses awk for multi-line operations (available on all Android devices)
#
# Usage: sh patcher.sh <decompiled_dir>
# Author: Or10n  https://github.com/Or10n

DECOMPILED="$1"
SUCCESS=0
TOTAL=6

# ──────────────────────────────────────────────────────────────
# Utility
# ──────────────────────────────────────────────────────────────

log_ok()   { echo "  [+] $1"; }
log_fail() { echo "  [x] $1"; }
log_info() { echo "  [i] $1"; }
log_warn() { echo "  [!] $1"; }

find_smali() {
    # Find a smali file across all smali*/smali_classesN directories
    local relpath="$1"
    for d in "$DECOMPILED"/smali*; do
        [ -d "$d" ] || continue
        if [ -f "$d/$relpath" ]; then
            echo "$d/$relpath"
            return 0
        fi
    done
    return 1
}

# ──────────────────────────────────────────────────────────────
# Patch 1: isUseMiuiHomeAsDefaultHome -> always return true
# ──────────────────────────────────────────────────────────────

patch_1() {
    local file="$1"
    local sig=".method public static isUseMiuiHomeAsDefaultHome(Landroid/content/Context;)Z"

    if ! grep -q "isUseMiuiHomeAsDefaultHome" "$file"; then
        log_fail "Patch 1: Method isUseMiuiHomeAsDefaultHome not found"
        return 1
    fi

    # Check if already patched
    local start_line=$(grep -n "$sig" "$file" | head -1 | cut -d: -f1)
    local after=$(tail -n "+$start_line" "$file" | head -20)
    if echo "$after" | grep -q "PATCHED"; then
        log_warn "Patch 1: Already patched"
        return 0
    fi

    awk -v sig="$sig" '
    BEGIN { in_method=0; found=0 }
    $0 ~ sig && !found {
        in_method=1; found=1
        print $0
        next
    }
    in_method && /^\.end method/ {
        print "    .locals 1"
        print ""
        print "    # PATCHED: Always return true - keeps gesture engine alive"
        print "    const/4 p0, 0x1"
        print ""
        print "    return p0"
        print $0
        in_method=0
        next
    }
    in_method { next }
    { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"

    log_ok "Patch 1: isUseMiuiHomeAsDefaultHome -> always true"
    return 0
}

# ──────────────────────────────────────────────────────────────
# Patch 2: isUsePocoHomeAsDefaultHome -> always return true
# ──────────────────────────────────────────────────────────────

patch_2() {
    local file="$1"
    local sig=".method public static isUsePocoHomeAsDefaultHome(Landroid/content/Context;)Z"

    if ! grep -q "isUsePocoHomeAsDefaultHome(Landroid/content/Context;)Z" "$file"; then
        log_fail "Patch 2: Method isUsePocoHomeAsDefaultHome not found"
        return 1
    fi

    local start_line=$(grep -n "isUsePocoHomeAsDefaultHome(Landroid/content/Context;)Z" "$file" | head -1 | cut -d: -f1)
    local after=$(tail -n "+$start_line" "$file" | head -20)
    if echo "$after" | grep -q "PATCHED"; then
        log_warn "Patch 2: Already patched"
        return 0
    fi

    awk -v sig="isUsePocoHomeAsDefaultHome\\(Landroid/content/Context;\\)Z" '
    BEGIN { in_method=0; found=0 }
    $0 ~ sig && /^\.method/ && !found {
        in_method=1; found=1
        print $0
        next
    }
    in_method && /^\.end method/ {
        print "    .locals 1"
        print ""
        print "    # PATCHED: Always return true - Poco variant"
        print "    const/4 p0, 0x1"
        print ""
        print "    return p0"
        print $0
        in_method=0
        next
    }
    in_method { next }
    { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"

    log_ok "Patch 2: isUsePocoHomeAsDefaultHome -> always true"
    return 0
}

# ──────────────────────────────────────────────────────────────
# Patch 3: setIsUseMiuiHomeAsDefaultHome -> force param true
# ──────────────────────────────────────────────────────────────

patch_3() {
    local file="$1"
    local sig=".method public setIsUseMiuiHomeAsDefaultHome(Z)V"

    if ! grep -q "$sig" "$file"; then
        log_fail "Patch 3: Method setIsUseMiuiHomeAsDefaultHome not found"
        return 1
    fi

    # Check if already patched
    local start_line=$(grep -n "$sig" "$file" | head -1 | cut -d: -f1)
    local after=$(tail -n "+$start_line" "$file" | head -10)
    if echo "$after" | grep -q "PATCHED"; then
        log_warn "Patch 3: Already patched"
        return 0
    fi

    # Insert const/4 p1, 0x1 after .locals in this specific method
    awk -v sig="setIsUseMiuiHomeAsDefaultHome" '
    BEGIN { in_method=0; patched=0 }
    /^\.method/ && $0 ~ sig {
        in_method=1; patched=0
        print; next
    }
    in_method && /\.locals/ && !patched {
        print
        print ""
        print "    # PATCHED: Force parameter to true"
        print "    const/4 p1, 0x1"
        print ""
        patched=1
        next
    }
    in_method && /^\.end method/ {
        in_method=0
    }
    { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"

    log_ok "Patch 3: setIsUseMiuiHomeAsDefaultHome -> forced true"
    return 0
}

# ──────────────────────────────────────────────────────────────
# Patch 4: Force mIsUseMiuiHomeAsDefaultHome = true at init
# ──────────────────────────────────────────────────────────────

patch_4() {
    local file="$1"
    local field="mIsUseMiuiHomeAsDefaultHome:Z"

    if ! grep -q "iput-boolean.*$field" "$file"; then
        log_fail "Patch 4: iput-boolean for mIsUseMiuiHomeAsDefaultHome not found"
        return 1
    fi

    # Find the first iput-boolean for this field (the init-time assignment)
    local line=$(grep -n "iput-boolean.*$field" "$file" | head -1 | cut -d: -f1)

    # Check preceding lines for already-patched marker
    local before_start=$((line > 5 ? line - 5 : 1))
    local before=$(sed -n "${before_start},${line}p" "$file")
    if echo "$before" | grep -q "PATCHED"; then
        log_warn "Patch 4: Already patched"
        return 0
    fi

    # Extract the register name from the iput-boolean line
    local reg=$(sed -n "${line}p" "$file" | sed 's/.*iput-boolean \([a-z0-9]*\),.*/\1/')

    # Insert const/4 <reg>, 0x1 before the iput-boolean line
    awk -v target_line="$line" -v reg="$reg" '
    NR == target_line {
        print "    # PATCHED: Force true at init"
        printf "    const/4 %s, 0x1\n", reg
        print ""
    }
    { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"

    log_ok "Patch 4: Init mIsUseMiuiHomeAsDefaultHome -> forced true (reg=$reg)"
    return 0
}

# ──────────────────────────────────────────────────────────────
# Patch 5: Replace performAppToHome fallback with RecentsActivity
# ──────────────────────────────────────────────────────────────

patch_5() {
    local file="$1"

    # Check if already patched
    if grep -q "com.miui.home.recents.RecentsActivity" "$file"; then
        log_warn "Patch 5: Already patched (recents fallback)"
        return 0
    fi

    # Find: invoke-virtual/range {p0 .. p0}, L.../NavStubView;->performAppToHome()V
    # This is the fallback call when gesture ends. We need the specific one
    # preceded by a cond label (not inside performAppToHome method itself)
    local line=$(grep -n 'invoke-virtual/range {p0 \.\. p0}.*NavStubView;->performAppToHome()V' "$file" | head -1 | cut -d: -f1)

    if [ -z "$line" ]; then
        log_fail "Patch 5: Cannot find performAppToHome fallback"
        return 1
    fi

    # Replace that single invoke line with RecentsActivity intent launch
    awk -v target_line="$line" '
    NR == target_line {
        print "    # PATCHED: Launch RecentsActivity directly instead of going home"
        print "    invoke-virtual/range {p0 .. p0}, Landroid/view/View;->getContext()Landroid/content/Context;"
        print ""
        print "    move-result-object v10"
        print ""
        print "    new-instance v11, Landroid/content/Intent;"
        print ""
        print "    invoke-direct {v11}, Landroid/content/Intent;-><init>()V"
        print ""
        print "    new-instance v12, Landroid/content/ComponentName;"
        print ""
        print "    const-string v13, \"com.miui.home\""
        print ""
        print "    const-string v14, \"com.miui.home.recents.RecentsActivity\""
        print ""
        print "    invoke-direct {v12, v13, v14}, Landroid/content/ComponentName;-><init>(Ljava/lang/String;Ljava/lang/String;)V"
        print ""
        print "    invoke-virtual {v11, v12}, Landroid/content/Intent;->setComponent(Landroid/content/ComponentName;)Landroid/content/Intent;"
        print ""
        print "    const v12, 0x14010000"
        print ""
        print "    invoke-virtual {v11, v12}, Landroid/content/Intent;->setFlags(I)Landroid/content/Intent;"
        print ""
        print "    invoke-virtual {v10, v11}, Landroid/content/Context;->startActivity(Landroid/content/Intent;)V"
        next
    }
    { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"

    log_ok "Patch 5: Recents fallback -> launches RecentsActivity"
    return 0
}

# ──────────────────────────────────────────────────────────────
# Patch 6: Increase gesture zone height to 35dp
# ──────────────────────────────────────────────────────────────

patch_6() {
    local file="$1"

    if ! grep -q "getHotSpaceHeight" "$file"; then
        log_fail "Patch 6: getHotSpaceHeight method not found"
        return 1
    fi

    # Check if already patched
    local start_line=$(grep -n "^\.method public getHotSpaceHeight" "$file" | head -1 | cut -d: -f1)
    local end_line=$(tail -n "+$start_line" "$file" | grep -n "^\.end method" | head -1 | cut -d: -f1)
    end_line=$((start_line + end_line - 1))

    local method_body=$(sed -n "${start_line},${end_line}p" "$file")
    if echo "$method_body" | grep -q "0x420c0000"; then
        log_warn "Patch 6: Already patched (gesture zone height)"
        return 0
    fi

    # Replace float constants within getHotSpaceHeight method
    # 0x41c80000 = 25.0f, 0x41a40000 = 20.5f -> 0x420c0000 = 35.0f
    local count=0
    awk -v start="$start_line" -v end="$end_line" '
    NR >= start && NR <= end && /const\/high16/ && /0x4[01][a-fA-F0-9]+/ {
        gsub(/0x4[01][a-fA-F0-9]+/, "0x420c0000")
        # Replace comment if present
        if (match($0, /#.*f$/)) {
            sub(/#.*f$/, "# 35.0f  PATCHED: increased gesture zone")
        }
    }
    { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"

    log_ok "Patch 6: Gesture zone height -> 35dp"
    return 0
}

# ──────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────

if [ -z "$DECOMPILED" ] || [ ! -d "$DECOMPILED" ]; then
    echo "Usage: sh patcher.sh <decompiled_dir>"
    exit 1
fi

# Find target files
BC_FILE=$(find_smali "com/miui/home/common/utils/BuildConfigUtils.smali")
if [ -z "$BC_FILE" ]; then
    # Try legacy path
    BC_FILE=$(find_smali "com/miui/home/launcher/common/Utilities.smali")
    [ -n "$BC_FILE" ] && log_warn "Found legacy class: Utilities.smali"
fi
[ -z "$BC_FILE" ] && { log_fail "Cannot find BuildConfigUtils.smali"; exit 1; }

BR_FILE=$(find_smali "com/miui/home/recents/BaseRecentsImpl.smali")
[ -z "$BR_FILE" ] && { log_fail "Cannot find BaseRecentsImpl.smali"; exit 1; }

NS_FILE=$(find_smali "com/miui/home/recents/NavStubView.smali")
[ -z "$NS_FILE" ] && { log_fail "Cannot find NavStubView.smali"; exit 1; }

log_info "BuildConfig: $BC_FILE"
log_info "BaseRecents: $BR_FILE"
log_info "NavStubView: $NS_FILE"
echo ""

# Apply patches
patch_1 "$BC_FILE" && SUCCESS=$((SUCCESS + 1))
patch_2 "$BC_FILE" && SUCCESS=$((SUCCESS + 1))
patch_3 "$BR_FILE" && SUCCESS=$((SUCCESS + 1))
patch_4 "$BR_FILE" && SUCCESS=$((SUCCESS + 1))
patch_5 "$NS_FILE" && SUCCESS=$((SUCCESS + 1))
patch_6 "$NS_FILE" && SUCCESS=$((SUCCESS + 1))

echo ""
echo "============================================================"
echo "  Patches applied: $SUCCESS/$TOTAL"
if [ "$SUCCESS" -eq "$TOTAL" ]; then
    echo "  ALL PATCHES SUCCEEDED"
elif [ "$SUCCESS" -gt 0 ]; then
    echo "  PARTIAL SUCCESS - $((TOTAL - SUCCESS)) patches failed"
else
    echo "  ALL PATCHES FAILED"
fi
echo "============================================================"

[ "$SUCCESS" -eq "$TOTAL" ] && exit 0 || exit 1
