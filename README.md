<p align="center">
 <img align="center" width=100% alt="Boorusama Logo" src="https://user-images.githubusercontent.com/19619099/177544952-1d963e91-5c6d-40d2-b731-bf84b63aa246.png" />
</p>

[![License](https://img.shields.io/badge/license-GPLv3-blue)](https://www.gnu.org/licenses/gpl-3.0) 
[![Discord](https://img.shields.io/discord/817638254571946006?label=&logo=discord&logoColor=ffffff&color=5865F2)](https://discord.gg/tvyYVxjfBr) 

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.degenk.boorusama">
    <img align="center"  width="140" alt="Boorusama Logo" src="http://i.imgur.com/mtGRPuM.png" />
  </a>
</p>

## Overview

**Boorusama Timber** is a private-use fork of Boorusama by Nguyen Duc Khoa. It
retains the original project's authorship and identifies Timberpile's changes
separately.

Boorusama is an unofficial, cross-platform client for major booru imageboards. It covers all core functionality and gives you total control over your experience with extra features like bulk downloads, favorite tags, advanced blacklisting, and more.

![Banner_1](./images/banner_2.png)  
![Banner_2](./images/banner_1.png)

## Features

Supported imageboards:
- Danbooru
- Gelbooru 0.2.5, Gelbooru 0.1, Gelbooru 0.2
- e621ng
- e-shushuu
- Zerochan
- Moebooru
- Nozomi.la
- Shimmie2
- Sankaku
- Philomena
- Szurubooru
- Hydrus Network
- Hybooru
- anime-pictures

## Installation

### Prerequisites

- [FVM](https://fvm.app/)
- [Git](https://git-scm.com/downloads)

### Steps

1. Clone the repository:

```bash
git clone https://github.com/timberpile/Boorusama.git
cd Boorusama
```

2. Install dependencies and generate boilerplate code:

```bash
./init.sh
```

3. Connect to an Android device or emulator and run the app:

```bash
fvm flutter run --flavor dev
```

Or build an APK and install it manually:

```bash
./build.sh apk --flavor prod
```

### Run on a physical Android device from WSL 2

Flutter running in WSL needs its own Linux Android SDK. A Windows Android SDK
cannot be used as the Linux build toolchain.

#### Set up the WSL Android toolchain

Install the native prerequisites:

```bash
sudo apt update
sudo apt install -y \
  android-sdk-platform-tools-common \
  curl \
  meson \
  nasm \
  openjdk-17-jdk \
  unzip \
  usbutils
```

Install the current stable [Rust toolchain](https://rustup.rs/) if `cargo` is
not already available.

Download the **Linux Android Command Line Tools** from the
[Android Studio download page](https://developer.android.com/studio), then
extract the archive so the resulting path is:

```text
~/Android/Sdk/cmdline-tools/latest/bin/android
```

For example, place the downloaded ZIP in `~/Downloads`, then run:

```bash
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

mkdir -p "$ANDROID_HOME/cmdline-tools/latest"
unzip ~/Downloads/commandlinetools-linux-*_latest.zip \
  -d /tmp/android-command-line-tools
mv /tmp/android-command-line-tools/cmdline-tools/* \
  "$ANDROID_HOME/cmdline-tools/latest/"
```

Add the following to `~/.bashrc`, then run `source ~/.bashrc`:

```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$HOME/fvm/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
```

Install the Android components used by this repository:

```bash
android --sdk="$ANDROID_HOME" sdk install \
  platform-tools \
  platforms/android-36 \
  build-tools/36.0.0 \
  ndk/28.2.13676358

fvm flutter config --android-sdk "$ANDROID_HOME"
fvm flutter doctor --android-licenses
fvm flutter doctor -v
```

Google has deprecated `sdkmanager` in favor of `android sdk`. Flutter might
still invoke `sdkmanager` while checking licenses; its deprecation warning is
harmless.

If `android/local.properties` already contains a Windows SDK path, replace its
`sdk.dir` entry with the WSL path:

```properties
sdk.dir=/home/<user>/Android/Sdk
```

`android/local.properties` is machine-local and must not be committed.

#### Attach the phone to WSL

Enable **Developer options** and **USB debugging** on the phone. Install
[usbipd-win](https://learn.microsoft.com/windows/wsl/connect-usb) from an
Administrator PowerShell if necessary:

```powershell
winget install --interactive --exact dorssel.usbipd-win
```

With the phone connected, share it once from an Administrator PowerShell:

```powershell
usbipd list
usbipd bind --busid 4-4
```

Replace `4-4` with the phone's BUSID from `usbipd list`.

`bind` is persistent. With a WSL terminal open, attach the phone from a normal
PowerShell each time it is plugged in or WSL is restarted:

```powershell
usbipd attach --wsl --busid 4-4
```

While attached to WSL, the USB device is unavailable to Windows. The BUSID
usually remains stable when using the same USB port, but `usbipd list` shows
the current value.

#### Run the debug app

Unlock the phone, accept its RSA debugging prompt, and verify the connection
inside WSL:

```bash
adb devices -l
fvm flutter devices
```

The device must be listed as `device`, not `unauthorized`. Launch the `dev`
flavor with its device ID:

```bash
fvm flutter run --flavor dev -d DEVICE_ID
```

Replace `DEVICE_ID` with the identifier printed by `fvm flutter devices`.

The flavor is required because the Android project defines both `dev` and
`prod`. The dev build uses the application ID
`com.timberpile.boorusama.dev`, so it can coexist with a production build.

If the phone is missing, check `usbipd list` in Windows and `lsusb` in WSL. If
ADB reports insufficient permissions, ensure the
`android-sdk-platform-tools-common` package is installed, restart WSL, attach
the phone again, and retry `adb devices -l`.

## Translation

Translations are managed via [Weblate](https://weblate.org/en/).

<a href="https://hosted.weblate.org/engage/boorusama/">
<img src="https://hosted.weblate.org/widget/boorusama/multi-auto.svg" alt="Translation status" />
</a>

## Feedback & Issues
Feel free to send me feedback on [Discord](https://discord.gg/tvyYVxjfBr) or [file an issue](https://github.com/khoadng/Boorusama/issues/new). Feature requests are always welcome.

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.
