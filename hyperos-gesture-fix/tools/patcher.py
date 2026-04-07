#!/usr/bin/env python3
"""
# Author: Or10n  https://github.com/Or10n
Universal MiuiHome Gesture Navigation Patcher

Patches MiuiHome smali to keep gesture navigation alive with third-party launchers.
Designed to be resilient across different HyperOS builds:
  - Tolerates presence/absence of .line directives
  - Searches all smali_classesN/ directories
  - Handles both const-string and const-string/jumbo
  - Matches by method signature, not exact byte patterns
  - Validates structure before patching
"""

import os
import re
import sys
import glob

# ──────────────────────────────────────────────────────────────
# Utility functions
# ──────────────────────────────────────────────────────────────

GREEN = "\033[0;32m"
RED = "\033[0;31m"
YELLOW = "\033[1;33m"
CYAN = "\033[0;36m"
NC = "\033[0m"

def log_ok(msg):
    print(f"  {GREEN}[+]{NC} {msg}")

def log_fail(msg):
    print(f"  {RED}[x]{NC} {msg}")

def log_info(msg):
    print(f"  {CYAN}[i]{NC} {msg}")

def log_warn(msg):
    print(f"  {YELLOW}[!]{NC} {msg}")


def find_smali_file(decompiled_dir, relative_path):
    """Search for a smali file across all smali/smali_classesN directories."""
    for smali_dir in sorted(glob.glob(os.path.join(decompiled_dir, "smali*"))):
        candidate = os.path.join(smali_dir, relative_path)
        if os.path.isfile(candidate):
            return candidate
    return None


def strip_line_directives(text):
    """Remove .line N directives and surrounding blank lines for pattern matching."""
    # Remove .line directives
    stripped = re.sub(r'\n\s*\.line \d+\s*\n', '\n', text)
    # Collapse multiple blank lines into one
    stripped = re.sub(r'\n{3,}', '\n\n', stripped)
    return stripped


def extract_method(content, method_signature):
    """Extract a complete method body by its signature.
    Returns (start_index, end_index, method_text) or None."""
    # Escape the signature for regex but keep it readable
    escaped = re.escape(method_signature)
    pattern = re.compile(r'^(' + escaped + r'.*?^\.end method)', re.MULTILINE | re.DOTALL)
    match = pattern.search(content)
    if match:
        return match.start(), match.end(), match.group(0)
    return None


def replace_method_body(content, method_signature, new_body):
    """Replace a method's body (everything between signature+.locals and .end method).
    new_body should NOT include the .method line or .end method."""
    result = extract_method(content, method_signature)
    if not result:
        return None
    start, end, old_method = result

    # Parse method header (everything up to and including .locals N)
    header_match = re.match(
        r'(\.method\s+.*?\n\s*\.locals\s+\d+)\s*\n',
        old_method, re.DOTALL
    )
    if not header_match:
        return None

    header = header_match.group(1)
    new_method = f"{header}\n\n{new_body}\n.end method"
    return content[:start] + new_method + content[end:]


# ──────────────────────────────────────────────────────────────
# Patch implementations
# ──────────────────────────────────────────────────────────────

def patch_1_isUseMiuiHomeAsDefaultHome(content, filepath):
    """Patch 1: Make isUseMiuiHomeAsDefaultHome always return true."""
    sig = ".method public static isUseMiuiHomeAsDefaultHome(Landroid/content/Context;)Z"
    result = extract_method(content, sig)
    if not result:
        log_fail("Patch 1: Method isUseMiuiHomeAsDefaultHome not found")
        return content, False

    _, _, method = result
    stripped = strip_line_directives(method)

    # Verify this is the method we expect (checks default home package)
    if "getCurrentDefaultHomePackageName" not in stripped and "com.miui.home" not in stripped:
        # Already patched or unexpected structure
        if "const/4 p0, 0x1" in stripped and stripped.count("\n") < 8:
            log_warn("Patch 1: Already patched (isUseMiuiHomeAsDefaultHome)")
            return content, True
        log_fail("Patch 1: Method body doesn't match expected pattern")
        return content, False

    new_body = (
        "    # PATCHED: Always return true - keeps gesture engine alive\n"
        "    const/4 p0, 0x1\n"
        "\n"
        "    return p0"
    )
    new_content = replace_method_body(content, sig, new_body)
    if new_content:
        log_ok("Patch 1: isUseMiuiHomeAsDefaultHome -> always true")
        return new_content, True
    else:
        log_fail("Patch 1: Failed to replace method body")
        return content, False


def patch_2_isUsePocoHomeAsDefaultHome(content, filepath):
    """Patch 2: Make isUsePocoHomeAsDefaultHome always return true."""
    sig = ".method public static isUsePocoHomeAsDefaultHome(Landroid/content/Context;)Z"
    result = extract_method(content, sig)
    if not result:
        log_fail("Patch 2: Method isUsePocoHomeAsDefaultHome not found")
        return content, False

    _, _, method = result
    stripped = strip_line_directives(method)

    if "globallauncher" not in stripped and "getDefaultHomePackageName" not in stripped:
        if "const/4 p0, 0x1" in stripped and stripped.count("\n") < 8:
            log_warn("Patch 2: Already patched (isUsePocoHomeAsDefaultHome)")
            return content, True
        log_fail("Patch 2: Method body doesn't match expected pattern")
        return content, False

    new_body = (
        "    # PATCHED: Always return true - Poco variant\n"
        "    const/4 p0, 0x1\n"
        "\n"
        "    return p0"
    )
    new_content = replace_method_body(content, sig, new_body)
    if new_content:
        log_ok("Patch 2: isUsePocoHomeAsDefaultHome -> always true")
        return new_content, True
    else:
        log_fail("Patch 2: Failed to replace method body")
        return content, False


def patch_3_setIsUseMiuiHomeAsDefaultHome(content, filepath):
    """Patch 3: Force parameter to true in setIsUseMiuiHomeAsDefaultHome."""
    sig = ".method public setIsUseMiuiHomeAsDefaultHome(Z)V"
    result = extract_method(content, sig)
    if not result:
        log_fail("Patch 3: Method setIsUseMiuiHomeAsDefaultHome not found")
        return content, False

    start, end, method = result

    # Check if already patched — look for our injection marker anywhere in the method
    if "# PATCHED: Force parameter to true" in method:
        log_warn("Patch 3: Already patched (setIsUseMiuiHomeAsDefaultHome)")
        return content, True

    # Find the .locals line and insert const/4 p1, 0x1 right after it
    # This works regardless of whether .line directives follow
    locals_match = re.search(r'(\.locals\s+\d+)\s*\n', method)
    if not locals_match:
        log_fail("Patch 3: Cannot find .locals directive in method")
        return content, False

    insert_pos = locals_match.end()
    patched_method = (
        method[:insert_pos] +
        "\n    # PATCHED: Force parameter to true\n"
        "    const/4 p1, 0x1\n\n" +
        method[insert_pos:]
    )

    new_content = content[:start] + patched_method + content[end:]
    log_ok("Patch 3: setIsUseMiuiHomeAsDefaultHome -> forced true")
    return new_content, True


def patch_4_init_mIsUseMiuiHomeAsDefaultHome(content, filepath):
    """Patch 4: Force mIsUseMiuiHomeAsDefaultHome = true at init time.

    Looks for the pattern where v4 is assigned based on a package name comparison
    and then stored to mIsUseMiuiHomeAsDefaultHome. Inserts const/4 v4, 0x1
    just before the iput-boolean.
    """
    # Find the iput-boolean line for mIsUseMiuiHomeAsDefaultHome
    # This pattern is: iput-boolean <reg>, <obj>, L.../BaseRecentsImpl;->mIsUseMiuiHomeAsDefaultHome:Z
    pattern = re.compile(
        r'^(\s*)(iput-boolean\s+(\w+),\s*\w+,\s*L[^;]+/BaseRecentsImpl;->mIsUseMiuiHomeAsDefaultHome:Z)',
        re.MULTILINE
    )
    match = pattern.search(content)
    if not match:
        log_fail("Patch 4: Cannot find iput-boolean for mIsUseMiuiHomeAsDefaultHome")
        return content, False

    indent = match.group(1)
    full_line = match.group(2)
    register = match.group(3)  # Usually v4

    # Check if already patched (our comment marker before the iput-boolean)
    before = content[max(0, match.start() - 200):match.start()]
    if "# PATCHED: Force true at init" in before:
        log_warn("Patch 4: Already patched (init mIsUseMiuiHomeAsDefaultHome)")
        return content, True

    # Insert const/4 <register>, 0x1 before the iput-boolean
    injection = (
        f"{indent}# PATCHED: Force true at init\n"
        f"{indent}const/4 {register}, 0x1\n"
    )
    new_content = content[:match.start()] + injection + content[match.start():]
    log_ok(f"Patch 4: Init mIsUseMiuiHomeAsDefaultHome -> forced true (reg={register})")
    return new_content, True


def patch_5_recents_fallback(content, filepath):
    """Patch 5: Replace performAppToHome fallback with RecentsActivity launch.

    Finds the pattern where a label is followed by NavStubView;->performAppToHome()V
    and replaces the performAppToHome call with Intent-based RecentsActivity launch.
    """
    # Find: <label>\n    invoke-virtual/range {p0 .. p0}, L.../NavStubView;->performAppToHome()V
    # This might have .line directives between the label and the invoke
    pattern = re.compile(
        r'^(\s*)(:\w+)\s*\n'          # A label (e.g., :cond_8)
        r'(?:\s*\.line\s+\d+\s*\n)?'  # Optional .line directive
        r'(\s*invoke-virtual/range\s+\{p0\s*\.\.\s*p0\},\s*'
        r'L[^;]+/NavStubView;->performAppToHome\(\)V)',
        re.MULTILINE
    )
    match = pattern.search(content)
    if not match:
        # If performAppToHome is not found, check if already patched
        # (RecentsActivity launch code present near a cond label before HapticFeedbackCompat)
        if "com.miui.home.recents.RecentsActivity" in content:
            haptic_pattern = re.compile(r'RecentsActivity.*?HapticFeedbackCompat', re.DOTALL)
            if haptic_pattern.search(content):
                log_warn("Patch 5: Already patched (recents fallback)")
                return content, True
        log_fail("Patch 5: Cannot find performAppToHome fallback in NavStubView")
        return content, False

    indent = match.group(1)
    label = match.group(2)
    invoke_line = match.group(3)

    # Check if already patched
    nearby = content[match.start():match.start() + 500]
    if "RecentsActivity" in nearby:
        log_warn("Patch 5: Already patched (recents fallback)")
        return content, True

    # Build the replacement: keep the label, replace the invoke with RecentsActivity launch
    replacement = (
        f"{indent}{label}\n"
        f"{indent}# PATCHED: Launch RecentsActivity directly instead of going home\n"
        f"{indent}invoke-virtual/range {{p0 .. p0}}, Landroid/view/View;->getContext()Landroid/content/Context;\n"
        f"\n"
        f"{indent}move-result-object v10\n"
        f"\n"
        f"{indent}new-instance v11, Landroid/content/Intent;\n"
        f"\n"
        f"{indent}invoke-direct {{v11}}, Landroid/content/Intent;-><init>()V\n"
        f"\n"
        f"{indent}new-instance v12, Landroid/content/ComponentName;\n"
        f"\n"
        f'{indent}const-string v13, "com.miui.home"\n'
        f"\n"
        f'{indent}const-string v14, "com.miui.home.recents.RecentsActivity"\n'
        f"\n"
        f"{indent}invoke-direct {{v12, v13, v14}}, Landroid/content/ComponentName;-><init>(Ljava/lang/String;Ljava/lang/String;)V\n"
        f"\n"
        f"{indent}invoke-virtual {{v11, v12}}, Landroid/content/Intent;->setComponent(Landroid/content/ComponentName;)Landroid/content/Intent;\n"
        f"\n"
        f"{indent}const v12, 0x14010000\n"
        f"\n"
        f"{indent}invoke-virtual {{v11, v12}}, Landroid/content/Intent;->setFlags(I)Landroid/content/Intent;\n"
        f"\n"
        f"{indent}invoke-virtual {{v10, v11}}, Landroid/content/Context;->startActivity(Landroid/content/Intent;)V"
    )

    new_content = content[:match.start()] + replacement + content[match.end():]
    log_ok(f"Patch 5: Recents fallback -> launches RecentsActivity (at {label})")
    return new_content, True


def patch_6_gesture_zone_height(content, filepath):
    """Patch 6: Increase bottom gesture zone height to 35dp.

    Finds getHotSpaceHeight() and replaces float constants for gesture height.
    Handles any original value (20.5f, 25f, etc.) by finding them within the method.
    """
    sig = ".method public getHotSpaceHeight()I"
    result = extract_method(content, sig)
    if not result:
        log_fail("Patch 6: Method getHotSpaceHeight not found")
        return content, False

    start, end, method = result
    target_hex = "0x420c0000"  # 35.0f

    # Already patched?
    if method.count(target_hex) >= 2 or "PATCHED" in method:
        log_warn("Patch 6: Already patched (gesture zone height)")
        return content, True

    patched_method = method
    count = 0

    # Find all const/high16 vN, 0xNNNNNNNN within this method (float constants)
    # These are the gesture height values. Replace any that aren't already 35.0f
    float_pattern = re.compile(r'(const/high16\s+v\d+,\s+)(0x[0-9a-fA-F]+)(\s+#\s+[\d.]+f)')
    for m in float_pattern.finditer(method):
        hex_val = m.group(2)
        if hex_val != target_hex:
            old_full = m.group(0)
            reg_part = m.group(1)
            new_full = f"{reg_part}{target_hex}    # 35.0f  PATCHED: increased gesture zone"
            patched_method = patched_method.replace(old_full, new_full, 1)
            count += 1

    if count == 0:
        # Try without the comment (some builds might not have # Nf comments)
        float_pattern_nocomment = re.compile(r'(const/high16\s+v\d+,\s+)(0x4[0-1][a-fA-F0-9]{6})\b')
        for m in float_pattern_nocomment.finditer(method):
            hex_val = m.group(2)
            if hex_val != target_hex:
                old_full = m.group(0)
                reg_part = m.group(1)
                new_full = f"{reg_part}{target_hex}    # 35.0f  PATCHED"
                patched_method = patched_method.replace(old_full, new_full, 1)
                count += 1

    if count > 0:
        new_content = content[:start] + patched_method + content[end:]
        log_ok(f"Patch 6: Gesture zone height -> 35dp ({count} constant(s) replaced)")
        return new_content, True
    else:
        log_fail("Patch 6: No float constants found in getHotSpaceHeight")
        return content, False


# ──────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <decompiled_dir>")
        sys.exit(1)

    decompiled_dir = sys.argv[1]

    if not os.path.isdir(decompiled_dir):
        print(f"{RED}[x]{NC} Not a directory: {decompiled_dir}")
        sys.exit(1)

    # Find target files
    buildconfig_path = find_smali_file(decompiled_dir, "com/miui/home/common/utils/BuildConfigUtils.smali")
    if not buildconfig_path:
        # Try legacy HyperOS 2 / MIUI path
        buildconfig_path = find_smali_file(decompiled_dir, "com/miui/home/launcher/common/Utilities.smali")
        if buildconfig_path:
            log_warn("Found legacy class path: Utilities.smali (HyperOS 1/2 or MIUI)")
        else:
            print(f"{RED}[x]{NC} Cannot find BuildConfigUtils.smali or Utilities.smali")
            sys.exit(1)

    baserecents_path = find_smali_file(decompiled_dir, "com/miui/home/recents/BaseRecentsImpl.smali")
    if not baserecents_path:
        print(f"{RED}[x]{NC} Cannot find BaseRecentsImpl.smali")
        sys.exit(1)

    navstub_path = find_smali_file(decompiled_dir, "com/miui/home/recents/NavStubView.smali")
    if not navstub_path:
        print(f"{RED}[x]{NC} Cannot find NavStubView.smali")
        sys.exit(1)

    log_info(f"BuildConfig: {os.path.relpath(buildconfig_path, decompiled_dir)}")
    log_info(f"BaseRecents: {os.path.relpath(baserecents_path, decompiled_dir)}")
    log_info(f"NavStubView: {os.path.relpath(navstub_path, decompiled_dir)}")
    print()

    # Load files
    with open(buildconfig_path, 'r') as f:
        bc_content = f.read()
    with open(baserecents_path, 'r') as f:
        br_content = f.read()
    with open(navstub_path, 'r') as f:
        ns_content = f.read()

    success = 0
    total = 6

    # Apply patches
    bc_content, ok = patch_1_isUseMiuiHomeAsDefaultHome(bc_content, buildconfig_path)
    if ok: success += 1

    bc_content, ok = patch_2_isUsePocoHomeAsDefaultHome(bc_content, buildconfig_path)
    if ok: success += 1

    br_content, ok = patch_3_setIsUseMiuiHomeAsDefaultHome(br_content, baserecents_path)
    if ok: success += 1

    br_content, ok = patch_4_init_mIsUseMiuiHomeAsDefaultHome(br_content, baserecents_path)
    if ok: success += 1

    ns_content, ok = patch_5_recents_fallback(ns_content, navstub_path)
    if ok: success += 1

    ns_content, ok = patch_6_gesture_zone_height(ns_content, navstub_path)
    if ok: success += 1

    # Write modified files
    with open(buildconfig_path, 'w') as f:
        f.write(bc_content)
    with open(baserecents_path, 'w') as f:
        f.write(br_content)
    with open(navstub_path, 'w') as f:
        f.write(ns_content)

    # Summary
    print(f"\n{'='*60}")
    print(f"  Patches applied: {success}/{total}")
    if success == total:
        print(f"  {GREEN}ALL PATCHES SUCCEEDED{NC}")
    elif success > 0:
        print(f"  {YELLOW}PARTIAL SUCCESS — {total - success} patches failed{NC}")
    else:
        print(f"  {RED}ALL PATCHES FAILED{NC}")
    print(f"{'='*60}")

    sys.exit(0 if success == total else 1)


if __name__ == "__main__":
    main()
