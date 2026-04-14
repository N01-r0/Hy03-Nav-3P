
# Update 3.1.0

- Added support for native haptics
- Logic added for smoother recents 

# Scoped for V3.2:

- Swipe to go home is instantaneous. This needs correction
- Home bs recents reliant on NavstubView -- Needs native path instead
-- Recents flashes home, due to reliance above. Logic needs further correction to improve this or cancel it out completely. 


# Update V3.0 whats new?

- Changed to new vector hook module instead for easier compatability, works on rooted xiaomi devices running HyperOS2/3. Runs using new vector 101 API.

## Set up
- Ensure you have Lsposed installed with api version 101 or 100
- Download apk from releases, install, open & set recommended scopes
- Reboot

# Uninstall
- You can uninstall the apk or via lsposed & then reboot. 


# Please be advised that this is still in testing phases so some compatability might not work. Test on your own accord.

- Please if you have time to submit an issue, I would really encourage this. Ensure to include what V OS you're running & the actual issue you're having.

# Update V2.0:

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








---

