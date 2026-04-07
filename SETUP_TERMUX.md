# Setup Guide: Termux (No Computer Needed)

Complete setup using only your phone. No laptop or desktop required.

## How This Works

Termux runs its own Linux environment with its own Java (OpenJDK), Python, and tools. Unlike Android's built-in `app_process`, Termux's Java runs unrestricted — so decompilation and reassembly work perfectly on-device.

## Prerequisites

### 1. Install Termux

**Use the F-Droid version** (the Play Store version is outdated and broken):

1. Download [Termux from F-Droid](https://f-droid.org/en/packages/com.termux/) or from [Termux GitHub Releases](https://github.com/termux/termux-app/releases)
2. Install and open Termux

### 2. Grant Root Access to Termux

In your root manager app (KernelSU Manager / Magisk):
1. Open the **Superuser** tab
2. Find **Termux** in the list
3. Grant root access

Verify in Termux:
```bash
su -c 'id'
# Should show: uid=0(root)
```

If `su` isn't found, install `tsu`:
```bash
pkg install tsu
```

### 3. Install Required Packages

Run these commands in Termux:

```bash
# Update package lists
pkg update && pkg upgrade -y

# Install everything needed
pkg install -y python openjdk-17 zip wget git
```

This installs:
- **Python 3** — runs the patcher
- **OpenJDK 17** — runs apktool and smali (Termux's own JVM, not Android's)
- **zip** — packages the module
- **wget/git** — for downloading tools

Verify:
```bash
python3 --version    # Python 3.x.x
java -version        # openjdk version "17.x.x"
zip --version        # Zip 3.x
```

### 4. Install apktool

Termux has apktool in its repos:
```bash
pkg install -y apktool
```

> **Note:** The apktool wrapper script has `#!/bin/bash` but Android has no `/bin/bash`.
> The install script handles this automatically by calling `bash apktool` instead.
> If you ever need to run apktool manually, use: `bash $(which apktool) d myfile.apk`

Verify:
```bash
bash $(which apktool) --version
# Should show: 2.9.3 or similar
```

### 5. Install smali/baksmali

Termux's `wget` often fails on some download sites due to SSL issues. The easiest approach:

**Option A — Download via your phone's browser (recommended):**
1. Open this URL in Chrome/Firefox on your phone:
   `https://github.com/baksmali/smali/releases/download/v2.5.2/smali-2.5.2.jar`
2. Save it to Downloads
3. In Termux:
```bash
mkdir -p ~/bin
cp /sdcard/Download/smali-2.5.2.jar ~/bin/smali.jar
```

**Option B — Download via curl in Termux:**
```bash
mkdir -p ~/bin
curl -L https://github.com/baksmali/smali/releases/download/v2.5.2/smali-2.5.2.jar -o ~/bin/smali.jar
```

Then create the wrapper script:
```bash
cat > ~/bin/smali << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
java -jar ~/bin/smali.jar "$@"
EOF
chmod +x ~/bin/smali
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/bin:$PATH"
```

Verify:
```bash
smali --version
# Should show: smali 2.5.2
```

### All-in-one copy-paste block

```bash
# Install packages
pkg update && pkg upgrade -y
pkg install -y python openjdk-17 apktool zip curl

# Install smali
mkdir -p ~/bin
curl -L https://github.com/baksmali/smali/releases/download/v2.5.2/smali-2.5.2.jar -o ~/bin/smali.jar
cat > ~/bin/smali << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
java -jar ~/bin/smali.jar "$@"
EOF
chmod +x ~/bin/smali
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
export PATH="$HOME/bin:$PATH"
```

## Phone Preparation

### Required Root Modules

Install on your phone via your root manager app (KernelSU Manager / Magisk):
- **DisableApkVerification** or **CorePatch** — required because we modify the APK without re-signing it

## Installation

### Download the project

```bash
# Option A: Git clone
cd ~
git clone https://github.com/YOUR_REPO/hyperos-gesture-fix.git
cd hyperos-gesture-fix

# Option B: Download ZIP and extract
# (transfer the ZIP to your phone, then in Termux:)
cp /storage/emulated/0/Download/hyperos-gesture-fix.zip ~/
cd ~
unzip hyperos-gesture-fix.zip
cd hyperos-gesture-fix
```

### Run the Termux installer

```bash
chmod +x install_termux.sh
./install_termux.sh
```

The installer will:
1. Copy MiuiHome directly from your system partition (no ADB needed)
2. Decompile it using Termux's Java (~20 seconds)
3. Apply 6 gesture patches (~1 second)
4. Reassemble DEX files (~30 seconds)
5. Build and install the KSU/Magisk module
6. Ask to reboot

After reboot, set any launcher as default. Gestures work immediately.

## Why Termux Works but Flashable ZIPs Don't

You might wonder: if on-device patching is possible in Termux, why not do it inside a flashable ZIP?

The difference is the **Java runtime**:
- **Flashable ZIP** uses Android's `app_process` / `dalvikvm` — HyperOS 3 aggressively kills these unregistered processes after ~3 seconds
- **Termux** uses its own **OpenJDK** (`/data/data/com.termux/files/usr/bin/java`) — runs as a normal Linux process that Android doesn't interfere with

Same tools, same patches, completely different runtime environment.

## Troubleshooting

### "Permission denied" when running the script
```bash
chmod +x install_termux.sh
bash install_termux.sh
```

### "su: not found"
```bash
pkg install tsu
# Then use 'tsu' instead of 'su' if needed
```

### "apktool: command not found"
Make sure `~/bin` is in your PATH:
```bash
export PATH="$HOME/bin:$PATH"
```

### apktool fails with "Exception in thread main"
Termux's Java might need more memory:
```bash
export _JAVA_OPTIONS="-Xmx512m"
```

### Storage permission issues
```bash
termux-setup-storage
# Tap "Allow" on the permission popup
```

## After a System Update

Just re-run:
```bash
cd ~/hyperos-gesture-fix
./install_termux.sh
```
