# Setup Guide: Windows

Complete setup from scratch. Assumes you have nothing installed.

## Prerequisites

### 1. ADB (Android Debug Bridge)

**Option A: Standalone (recommended)**
1. Download [Android Platform Tools](https://developer.android.com/tools/releases/platform-tools#downloads) — click "Download SDK Platform-Tools for Windows"
2. Extract the ZIP to `C:\platform-tools\`
3. Add to PATH:
   - Press `Win + X` > **System** > **Advanced system settings** > **Environment Variables**
   - Under **System variables**, find `Path`, click **Edit**
   - Click **New**, add `C:\platform-tools`
   - Click **OK** on all dialogs

**Option B: Via Scoop (package manager)**
```powershell
# Install Scoop first (if you don't have it):
irm get.scoop.sh | iex

scoop install adb
```

Verify (open a new terminal):
```powershell
adb version
```

### 2. Java

**Option A: Direct download**
1. Download [Eclipse Temurin JDK 17](https://adoptium.net/temurin/releases/?version=17&os=windows&arch=x64&package=jdk) — pick the `.msi` installer
2. Run the installer, check **"Set JAVA_HOME variable"** and **"Add to PATH"** during setup

**Option B: Via Scoop**
```powershell
scoop bucket add java
scoop install temurin17-jdk
```

Verify (open a new terminal):
```powershell
java -version
```

### 3. Python 3

**Option A: Direct download**
1. Download from [python.org](https://www.python.org/downloads/)
2. Run installer — **CHECK "Add python.exe to PATH"** at the bottom of the first screen
3. Click "Install Now"

**Option B: Via Scoop**
```powershell
scoop install python
```

Verify:
```powershell
python --version
```

### 4. apktool

1. Download `apktool.jar` from [apktool.org](https://apktool.org/) (click the big download button)
2. Download the Windows wrapper script: [apktool.bat](https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/windows/apktool.bat)
3. Place both `apktool.bat` and `apktool.jar` (rename the downloaded jar to exactly `apktool.jar`) in `C:\platform-tools\` (or any folder in your PATH)

Verify:
```powershell
apktool --version
```

### 5. smali

1. Download `smali-2.5.2.jar` from [Bitbucket releases](https://bitbucket.org/JesusFreke/smali/downloads/)
2. Place it in your project folder (or `C:\platform-tools\`)
3. Create a file called `smali.bat` in the same location with this content:
```bat
@echo off
java -jar "%~dp0smali-2.5.2.jar" %*
```

Verify:
```powershell
smali --version
```

### 6. Git Bash (recommended) or WSL

The installer script is written in bash. You have two options:

**Option A: Git Bash (easier)**
1. Download [Git for Windows](https://gitforwindows.org/)
2. Install with default settings
3. You now have **Git Bash** — a terminal that runs bash scripts on Windows

**Option B: WSL (Windows Subsystem for Linux)**
```powershell
# In PowerShell as Administrator:
wsl --install
# Restart, then follow the SETUP_LINUX.md guide inside WSL
```

### All-in-one via Scoop

```powershell
# Install Scoop
irm get.scoop.sh | iex

# Add Java bucket
scoop bucket add java

# Install everything
scoop install adb temurin17-jdk python git zip
```

Then manually download apktool and smali JARs as described above.

## Phone Preparation

### 1. Enable USB Debugging

1. Go to **Settings > About Phone**
2. Tap **OS Version** (or **MIUI Version**) 7 times to enable Developer Options
3. Go to **Settings > Additional Settings > Developer Options**
4. Enable **USB Debugging**

### 2. Install USB Driver

Windows usually needs a driver for your Xiaomi device:
1. Download [Universal ADB Driver](https://adb.clockworkmod.com/) or the [Xiaomi USB Driver](https://developer.android.com/studio/run/oem-usb)
2. Install it
3. Plug in your phone

### 3. Verify ADB Connection

```powershell
adb devices
```

You should see your device listed. If it says "unauthorized", check your phone for a popup and tap **Allow**. If nothing shows up, try a different USB cable or port.

### 4. Required Root Modules

Install on your phone via your root manager app:
- **DisableApkVerification** or **CorePatch**

## Installation

Open **Git Bash** (right-click desktop > "Git Bash Here", or find it in Start menu):

```bash
# Navigate to the project folder
cd /c/Users/YourName/Downloads/hyperos-gesture-fix

# Run the installer
./install.sh
```

If you get a "permission denied" error:
```bash
bash install.sh
```

The installer will:
1. Pull MiuiHome from your phone (~25MB)
2. Decompile it
3. Apply 6 patches
4. Reassemble
5. Build and install the module
6. Ask to reboot

After reboot, set any launcher as default. Gestures work immediately.

## Troubleshooting

### "adb is not recognized"
Close and reopen your terminal after adding ADB to PATH.

### "java is not recognized"
Close and reopen your terminal after installing Java. If it still doesn't work, manually set JAVA_HOME:
```powershell
# Find where Java is installed, then:
setx JAVA_HOME "C:\Program Files\Eclipse Adoptium\jdk-17.x.x-hotspot"
```

### "apktool: command not found" in Git Bash
Make sure `apktool.bat` and `apktool.jar` are in a folder that's in your PATH, or place them in the project folder and run:
```bash
java -jar apktool.jar d MiuiHome.apk -o decompiled
```

### Device not showing in "adb devices"
1. Try a different USB cable (use the one that came with your phone)
2. Try a different USB port (USB 2.0 ports sometimes work better)
3. Reinstall the USB driver
4. On your phone: revoke USB debugging authorizations in Developer Options, then re-enable USB debugging

## After a System Update

Just re-run:
```bash
./install.sh
```
