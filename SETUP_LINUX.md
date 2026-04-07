# Setup Guide: Linux

Complete setup from scratch. Assumes you have nothing installed.

## Prerequisites

### 1. ADB (Android Debug Bridge)

```bash
# Ubuntu/Debian
sudo apt install android-tools-adb

# Arch/Manjaro
sudo pacman -S android-tools

# Fedora
sudo dnf install android-tools
```

Verify:
```bash
adb version
# Should show: Android Debug Bridge version X.X.X
```

### 2. Java (needed by apktool and smali)

```bash
# Ubuntu/Debian
sudo apt install default-jdk

# Arch/Manjaro
sudo pacman -S jdk-openjdk

# Fedora
sudo dnf install java-17-openjdk-devel
```

Verify:
```bash
java -version
# Should show: openjdk version "17.x.x" or similar
```

### 3. apktool (APK decompilation)

```bash
# Ubuntu/Debian (22.04+)
sudo apt install apktool

# Arch/Manjaro
sudo pacman -S apktool

# Manual install (any distro):
wget https://raw.githubusercontent.com/iBotPeaches/Apktool/master/scripts/linux/apktool
wget https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_2.10.0.jar -O apktool.jar
sudo mv apktool apktool.jar /usr/local/bin/
sudo chmod +x /usr/local/bin/apktool /usr/local/bin/apktool.jar
```

Verify:
```bash
apktool --version
# Should show: 2.x.x or 3.x.x
```

### 4. smali (DEX assembler)

```bash
# Ubuntu/Debian
sudo apt install libsmali-java

# Arch/Manjaro
yay -S smali

# Manual install (any distro):
wget https://bitbucket.org/JesusFreke/smali/downloads/smali-2.5.2.jar -O /usr/local/bin/smali.jar
echo '#!/bin/sh' | sudo tee /usr/local/bin/smali
echo 'java -jar /usr/local/bin/smali.jar "$@"' | sudo tee -a /usr/local/bin/smali
sudo chmod +x /usr/local/bin/smali
```

Verify:
```bash
smali --version
# Should show: smali 2.x.x or 3.x.x
```

### 5. Python 3

```bash
# Usually pre-installed on Linux. If not:
# Ubuntu/Debian
sudo apt install python3

# Arch/Manjaro
sudo pacman -S python
```

Verify:
```bash
python3 --version
# Should show: Python 3.x.x
```

### 6. zip

```bash
# Ubuntu/Debian
sudo apt install zip

# Arch/Manjaro
sudo pacman -S zip
```

### All-in-one (Ubuntu/Debian)

```bash
sudo apt install android-tools-adb default-jdk apktool libsmali-java python3 zip
```

## Phone Preparation

### 1. Enable USB Debugging

1. Go to **Settings > About Phone**
2. Tap **OS Version** (or **MIUI Version**) 7 times to enable Developer Options
3. Go to **Settings > Additional Settings > Developer Options**
4. Enable **USB Debugging**

### 2. Verify ADB Connection

```bash
# Plug in your phone via USB
adb devices
```

You should see your device listed. If it says "unauthorized", check your phone for an authorization popup and tap **Allow**.

### 3. Required Root Modules

Make sure these are installed on your phone via your root manager app (KernelSU Manager / Magisk):

- **DisableApkVerification** or **CorePatch** — required because we modify the APK without re-signing it

## Installation

```bash
# Clone or download this project
cd hyperos-gesture-fix

# Run the installer
./install.sh
```

The installer will:
1. Pull MiuiHome from your phone (~25MB, takes 1 second)
2. Decompile it (~15 seconds)
3. Apply 6 patches (~1 second)
4. Reassemble (~15 seconds)
5. Build and install the module
6. Ask to reboot

After reboot, set any launcher as default. Gestures work immediately.

## After a System Update

Just re-run:
```bash
./install.sh
```
It patches the new APK fresh.
