# HyperOS Gesture Navigation Fix for Third-Party Launchers

**Force native HyperOS gesture navigation to work with any third-party launcher on rooted Xiaomi devices.**

Back gestures, home swipe, and recent apps — all working with Smart Launcher, Lawnchair, Nova, Niagara, or any launcher of your choice.

NOTE: **Expected to work on:** Any HyperOS 3 device with MiuiHome 6.x (Xiaomi/Redmi/Poco). If you do not meet those requirements please dont test this :).


## Requirements

### On your phone (Still in testing phase, might not work)
- **Rooted**: KernelSU, KernelSU-Next, Magisk, or APatch
- **APK signature bypass**: `DisableApkVerification`, `CorePatch`, or similar (required because we modify DEX files in the APK without re-signing)

### On your computer 
- `adb` — Android platform-tools
- `apktool` — APK decompilation/recompilation
- `smali` — DEX reassembly (part of libsmali-java)
- `python3` — runs the universal patcher
- `zip` — packages the module

Instructions for installing all the requirements can be found below:

Windows: SETUP_WINDOWS.md
Linux: SETUP_LINUX.md
Termux: SETUP_TERMUX.md (in testing phasing)

## Quick Start

Once you have installed everything correctly, connect your device via USB with ADB debugging enabled, then:

```bash
./install.sh
```

That's it. It pulls your stock APK, patches it, builds a module, installs it, and asks to reboot. After reboot, set any launcher as default.

### The Problem

Xiaomi embedded the entire gesture engine directly into `com.miui.home` (the system launcher APK), rather than using Android's standard SystemUI-based system. When a third-party launcher becomes default, MiuiHome detects it's no longer the active home app and:

1. Tears down all gesture input surfaces (`NavStubView`, `GestureStubLeft`, `GestureStubRight`)
2. Forces the system back to 3-button navigation
3. Resets `force_fsg_nav_bar` and `navigation_mode` settings

This makes gestures physically impossible with any non-stock launcher.

### The Fix

The installer patches MiuiHome's smali code so it **never detects the launcher switch**, then installs a KernelSU/Magisk module that keeps everything in place across reboots.

#### 6 Smali Patches (applied to MiuiHome APK)

| # | What It Does |
|---|---|
| 1 | `isUseMiuiHomeAsDefaultHome()` always returns `true` — MiuiHome never detects a third-party launcher |
| 2 | `isUsePocoHomeAsDefaultHome()` always returns `true` — same fix for Poco/Redmi devices |
| 3 | `setIsUseMiuiHomeAsDefaultHome(false)` forced to `true` — blocks runtime kill signal |
| 4 | Init-time field `mIsUseMiuiHomeAsDefaultHome` forced to `true` — correct from boot |
| 5 | Recents fallback launches `RecentsActivity` directly instead of going home |
| 6 | Bottom gesture zone increased from 20.5dp to 35dp — 73% larger touch target |

#### Runtime Module (service.sh)

On every boot, the module:
- **Bind-mounts** the patched APK over the stock one
- **Removes** any MiuiHome updates from `/data/app/` (which would override the patch)
- **Monitors** gesture settings every 5 seconds, re-applying them if the system resets them



**Ubuntu/Debian:**
```bash
sudo apt install apktool libsmali-java python3 zip android-tools-adb
```

**Arch:**
```bash
yay -S apktool smali python zip android-tools
```

**macOS (Homebrew):**
```bash
brew install apktool smali python3 zip
```

## Compatibility

The patcher uses **method-signature matching with regex** rather than exact byte patterns, making it resilient across different MiuiHome builds:

- Builds with or without `.line` debug directives
- Files in any `smali_classesN/` directory (DEX redistribution between builds)
- HyperOS 3 (`BuildConfigUtils`) and HyperOS 2/MIUI (`Utilities`) class paths
- Variable float constants in gesture height methods
- Register names extracted dynamically (not hardcoded)

**Tested on:**

| APK | Build | `.line` directives | Result |
|---|---|---|---|
| Stock xiaomi.eu (Xiaomi 17 Ultra) | 6.01.05.2012 | No | 6/6 |
| Stock xiaomi.eu (different pull) | 6.01.05.2007 | Yes | 6/6 |
| Kashi's Modded HyperOS Launcher v6.7 | 6.01.05.2235 | Yes | 6/6 |

**Works with:** KernelSU, KernelSU-Next, Magisk, APatch

**Expected to work on:** Any HyperOS 3 device with MiuiHome 6.x (Xiaomi/Redmi/Poco).

## Tested Configuration

| Component | Version |
|---|---|
| Device | Xiaomi 17 Ultra |
| OS | HyperOS 3 (OS3.0) |
| Android | 16 (API 36) |
| ROM | xiaomi.eu Global |
| Root | KernelSU-Next (LKM mode) |
| Launchers tested | Smart Launcher 6, Lawnchair, Nova, Niagara |

## File Structure

```
hyperos-gesture-fix/
├── install.sh               # One-command installer (run this)
├── README.md                # This file
├── tools/
│   ├── patcher.py           # Universal patch engine (Python, regex-based)
│   └── patcher.sh           # Shell fallback patcher (same logic, pure sh)
└── module/                  # KSU/Magisk module template
    ├── module.prop
    ├── service.sh            # Boot daemon (bind-mount + gesture monitor)
    ├── post-fs-data.sh       # Early boot properties
    ├── system.prop           # Persistent system properties
    ├── uninstall.sh          # Cleanup on module removal
    └── META-INF/             # Magisk/KSU module installer
```

## Gesture Quality

| Gesture | Quality | Notes |
|---|---|---|
| **Back (edge swipes)** | Native | Handled by SystemUI + MiuiHome's GestureStubView. Identical to stock. |
| **Home (swipe up)** | Good | MiuiHome animation plays, goes to your third-party launcher. |
| **Recents (swipe up + hold)** | Functional | Opens RecentsActivity. Brief transition but works correctly. |

## Troubleshooting

### Gestures stop working after a system update
The OTA likely replaced MiuiHome. Just re-run the installer:
```bash
./install.sh
```
It pulls the new stock APK, patches it fresh, and reinstalls the module.

### MiuiHome crashes on boot
Disable the module to recover, then report issue to me.
```bash
adb wait-for-device
adb shell "su -c 'touch /data/adb/modules/hyperos_gesture_nav/disable'"
adb reboot
```

### Verify everything is working
```bash
# Gesture input windows present
adb shell "dumpsys input | grep GestureStub"
# Expected: GestureStub, GestureStubLeft, GestureStubRight

# APK loading from system (patched) location
adb shell "pm path com.miui.home"
# Expected: package:/product/priv-app/MiuiHome/MiuiHome.apk

# Settings correct
adb shell "settings get global force_fsg_nav_bar"   # Expected: 1
adb shell "settings get secure navigation_mode"       # Expected: 2
```

### Check the daemon log
```bash
adb shell "su -c 'cat /data/adb/modules/hyperos_gesture_nav/daemon.log'"
```

## Reverting/Further Issues

Uninstall the module from your root manager (KernelSU Manager / Magisk app) and reboot. Stock behavior is fully restored — no permanent changes are made to your system partition.

PLEASE report any issues with as much information as you can gather!!!! Thank you

##  Technical Notes

1. **Patch pattern fragility**: The original patches were written against a modded APK that preserves `.line` debug directives in smali. Fixed by building a regex-based patcher that matches method signatures and tolerates structural differences.

2. **On-device decompilation blocked**: HyperOS 3 aggressively kills unregistered `app_process` instances. baksmali gets `SIGKILL`'d (exit 137) after ~450 files, well before reaching the target classes. This isn't OOM (7.6GB free) and persists even with `oom_score_adj -1000`, `setsid`, `nohup`, and phantom process killer disabled. Solved by moving decompilation to the laptop.

3. **Invisible /data/app/ override**: MiuiHome updates are stored in `/data/app/`, which Android prioritizes over `/product/priv-app/`. A perfectly patched and bind-mounted system APK gets silently ignored. The module's `service.sh` now detects and removes these updates on every boot.

## Credits/Whats next?

- **[AnyLauncher](https://github.com/tiann/AnyLauncher)** by weishu/tiann
- **[FuckMIUIGesture](https://github.com/HCGStudio/FuckMIUIGesture)** by HCGStudio
- **[QuickSwitch](https://github.com/nickaknudson/QuickSwitch)** by nickaknudson
- **XDA Forums** — [root gesture tutorial](https://xdaforums.com/t/root-tutorial-working-gestures-with-any-launcher-for-every-miui-hyperos-device.4667872/) and [xiaomi.eu community](https://xiaomi.eu/community/threads/forcing-gesture-navigation-on-foreign-launchers.76170/)

Hopefully with everyone's input we can build something alot cleaner & smaller. I dont see why we need to route through the system launcher at all & so will be building another daemon that strictly has its own gestures, so there is no reliance on the system launcher whatsoever. 


## Checksums (SHA256)

| File | SHA256 |
|------|--------|
| `HyperOS-Gesture-Nav-Fix-v1.0.zip` | `fa80e22365c8f4bcdb994bd221f4444b23f6f092cf0f570512401bbe3fe1c386` |
| `README.md` | `94b990930541da6f9bdaba6ac640ace7466f4d7442a2e7cf5ed45b6af04c8317` |
| `SETUP_LINUX.md` | `3cf8e06b9c794b05d255fee6ef8978d43154477e0137625716be55ea990764ae` |
| `SETUP_TERMUX.md` | `17571d575298991b8477229711a8c39bb11e1ae4e2221fa77ccf5e75cf2117b5` |
| `SETUP_WINDOWS.md` | `45ac3e16354c0d89bc2db87d526b6a1ba4ddaa344d99788f671121dda6828155` |
| `install.sh` | `cbb323184bb49f5c55631e1f1e36ccefd7698fcfb7df620c196a64661492d38e` |
| `install_termux.sh` | `8ffaf6edd877eecd31f7227cf70f0fbbb5c057c0404632544f4a18d44ab51f82` |
