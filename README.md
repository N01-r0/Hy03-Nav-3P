#Update V3.0:

-Changed to new vector hook module instead for easier compatability, please ignore instructions from below, they are for my sanity now

#Update V2.0:

# HyperOS Gesture Daemon

- This project now ships as a KernelSU/KernelSU next module with:
- a gesture daemon
- a lightweight overlay APK
- boot persistence
- automatic gesture-nav reapply

## Requirements

- HyperOS 2 or 3
- Android 13+
- Root
- KernelSU / KernelSU-Next

## Install

1. Install the latest `hyperos-gesture-daemon-ksu-*.zip` under releases. Flash via KernelSU/SUnext(optional) magisk.
2. Reboot.
3. Set your third-party launcher as default if needed.

## Behavior

- Third-party launcher active:
  custom gesture daemon + overlay run
- `com.miui.home` active:
  custom daemon + overlay park automatically
- Module enabled:
  gestural navigation is kept forced on

## Tested

- Tested on HyperOS 3
- Designed for HyperOS 2 / 3
- Tested launchers: Smart Launcher, Nova, Lawnchair, Niagara

## Notes

- This module does not use the real MiuiHome/Quickstep recents animation pipeline. This would be a seperate project entirely.
- If Xiaomi changes gesture/nav internals on a future build, I will update the module.
- NOT tested on Magisk, however much of the logic/expectations are the same, this isnt going to break anything, so if you're using magisk try it & then let me know via the issues tab if it doesnt work.

## Uninstall

Disable or uninstall the module in KernelSU, then reboot.







# HyperOS Gesture Navigation Fix (V1.0) (Previous Method)

**Native HyperOS gestures — back, home, recents — with any third-party launcher on rooted Xiaomi devices.**

> HyperOS 3 / MiuiHome 6.x · KernelSU, KernelSU-Next, Magisk, APatch

---

## Requirements

**Phone:** Root + APK signature bypass (`DisableApkVerification`, `CorePatch`, or similar)

**Computer:** `adb` · `apktool` · `smali` · `python3` · `zip`
→ Setup guides: [Linux](SETUP_LINUX.md) · [Windows](SETUP_WINDOWS.md) · [Termux](SETUP_TERMUX.md)

---

## Quick Start

Connect your device via USB with ADB debugging enabled, then:

```bash
git clone https://github.com/Or10n/hyperos-gesture-fix
cd hyperos-gesture-fix
./install.sh
```

Pulls your stock APK, patches it, builds and installs a KSU/Magisk module, prompts reboot. After reboot, set any launcher as default — gestures work natively.

**On-device (no computer needed):**
```bash
./install_termux.sh
```
> ⚠️ Termux installer is still in testing.

---

## How It Works

HyperOS bakes its entire gesture engine into `com.miui.home`. When any third-party launcher becomes default, MiuiHome tears down all gesture surfaces and forces 3-button nav.

The installer patches 6 points in MiuiHome's smali (so it never detects a launcher switch), then installs a module that bind-mounts the patched APK on boot, removes any OTA overrides, and monitors gesture settings every 5s. Regex-based matching — not byte patterns — makes it resilient across builds.

---

## Compatibility

| APK | Build | Result |
|---|---|---|
| Stock xiaomi.eu (Xiaomi 17 Ultra) | 6.01.05.2012 | ✅ 6/6 patches |
| Stock xiaomi.eu | 6.01.05.2007 | ✅ 6/6 patches |
| Kashi's Modded HyperOS Launcher v6.7 | 6.01.05.2235 | ✅ 6/6 patches |

**Tested on:** Xiaomi 17 Ultra · HyperOS 3 (Android 16) · xiaomi.eu Global · KernelSU-Next
**Launchers:** Smart Launcher 6, Lawnchair, Nova, Niagara

---

## Troubleshooting

**Gestures stopped after OTA?**
```bash
./install.sh   # re-patches the new APK
```

**MiuiHome crashing on boot?**
```bash
adb wait-for-device
adb shell "su -c 'touch /data/adb/modules/hyperos_gesture_nav/disable'"
adb reboot
```

**Verify it's working:**
```bash
adb shell "dumpsys input | grep GestureStub"          # expect: GestureStub, Left, Right
adb shell "pm path com.miui.home"                      # expect: /product/priv-app/MiuiHome/...
adb shell "settings get global force_fsg_nav_bar"      # expect: 1
adb shell "settings get secure navigation_mode"        # expect: 2
```

**Check daemon log:**
```bash
adb shell "su -c 'cat /data/adb/modules/hyperos_gesture_nav/daemon.log'"
```

**To revert:** Uninstall the module from KernelSU Manager / Magisk and reboot. No permanent system changes.

---

## Credits

- **[AnyLauncher](https://github.com/tiann/AnyLauncher)** by weishu/tiann
- **[FuckMIUIGesture](https://github.com/HCGStudio/FuckMIUIGesture)** by HCGStudio
- **[QuickSwitch](https://github.com/nickaknudson/QuickSwitch)** by nickaknudson
- **XDA** — [root gesture tutorial](https://xdaforums.com/t/root-tutorial-working-gestures-with-any-launcher-for-every-miui-hyperos-device.4667872/) · [xiaomi.eu community](https://xiaomi.eu/community/threads/forcing-gesture-navigation-on-foreign-launchers.76170/)

Issues and contributions welcome. Long-term goal: a standalone gesture daemon with zero dependency on the system launcher.

---

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

---

