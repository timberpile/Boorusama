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
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Git](https://git-scm.com/downloads)

### Android development

1. Clone the repository:
```bash
git clone https://github.com/khoadng/Boorusama.git
cd Boorusama
```
2. Install dependencies and generate boilerplate code:
```bash
./init.sh
```
3. Connect an Android device or emulator and list the available devices:
```bash
flutter devices
```
4. Run the app on the selected Android device:
```bash
flutter run -d <android-device-id>
```
Or build an APK and install it manually:
```bash
./build.sh apk --flavor prod
```

### Native Windows desktop builds

The Windows target is a native desktop application. In addition to Flutter,
install the following on Windows:

- Git and a Bash environment such as Git Bash, because the setup and code
  generation scripts are Bash scripts.
- Visual Studio or Visual Studio Build Tools with **Desktop development with
  C++**, an MSVC toolset, a Windows 10/11 SDK, and **C++ ATL**. ATL provides
  `atlbase.h`, which is required by the Windows implementation of
  `flutter_local_notifications`.
- CMake, Rust/Cargo, Meson, Ninja, and NASM. The vendored `libavif` package
  builds its native `dav1d` and `libyuv` dependencies locally.
- Network access for Dart packages and the native media dependencies. The
  media-kit Windows plugin may bootstrap NuGet on its first build.

The repository contains an `.fvmrc`. If FVM is not installed, disable it for
this checkout and initialize the project from PowerShell:

```powershell
$env:BOORUSAMA_USE_FVM = "false"
bash ./init.sh
```

Use the Windows workflow wrapper for development and hot reload:

```powershell
.\scripts\windows.ps1 run
```

Build a Windows application without launching it with:

```powershell
.\scripts\windows.ps1 build
```

For release mode, append `-Configuration release`:

```powershell
.\scripts\windows.ps1 run -Configuration release
.\scripts\windows.ps1 build -Configuration release
```

The executable is written under `build/windows/x64/runner/`.

The same commands are available through **Terminal → Run Task** in VS Code:

- `Windows: Run`
- `Windows: Build`
- `Windows: Clean`

If this checkout was previously initialized in a Linux dev container, run
`flutter pub get` on Windows before building. Flutter's generated plugin links
are platform-specific and should not be reused between Linux and Windows.

The wrapper temporarily maps the repository's parent directory to a short
drive letter while Flutter runs to avoid Windows native-build path limits. If
the default `B:` drive is already in use, choose another drive:

```powershell
.\scripts\windows.ps1 run -DriveLetter Z
```

The wrapper detects CMake caches created under a different path and cleans
generated Flutter state before continuing. You can also run
`.\scripts\windows.ps1 clean` explicitly.

### Dev container

The included dev container provides the toolchain required to build and debug
the Android app. Select the **Standard** configuration for the main checkout,
then build an APK with:

```bash
bash .devcontainer/build-android.sh
```

To debug on an emulator or USB-connected device managed by a Windows host,
start the host ADB bridge before opening the container:

```powershell
.\.devcontainer\start-host-adb.ps1
```

Then run inside the container, optionally passing a device ID:

```bash
bash .devcontainer/run-android.sh [device-id]
```

Stop the host ADB bridge when debugging is finished:

```powershell
.\.devcontainer\stop-host-adb.ps1
```

There are also `release` versions available for `build-android.sh` and `run-android.sh`.

#### Git worktrees

On Windows, run **Tasks: Run Task** in VS Code and choose a **Worktrees** task
to create, reopen, or remove a worktree. Removal retains its branch and shared
dependency caches, and refuses worktrees with uncommitted files. Creating or
reopening a worktree also initializes its dependencies and generated code. New
worktrees use the next available short name (`w1`, `w2`, and so on) to keep
Windows native build paths manageable; explicit names remain supported when
running the script directly.

Use a Git version that supports `git worktree add --relative-paths`. Keep linked
worktrees under `.worktrees/` so their Git metadata resolves on both the host and
inside the container:

```bash
git config worktree.useRelativePaths true
git worktree add .worktrees/my-feature -b feature/my-feature
```

Open `.worktrees/my-feature` and select the **Worktree** dev container
configuration. Each checkout has isolated build output while dependency downloads
are shared.

Repair an existing worktree before opening it in the container:

```bash
git worktree repair --relative-paths .worktrees/my-feature
```

Remove it through Git when finished:

```bash
git worktree remove .worktrees/my-feature
```

Manual Git removal retains generated Docker volumes. The Windows removal task
also removes private volumes when their ownership can be verified from the dev
container. Avoid broad forced cleanup commands such as `git clean -fdx` around
`.worktrees/`.

## Releasing

Releases are built and packaged using the manual **GitHub release** workflow in `.github/workflows/github-release.yml`.

The workflow builds release artifacts for all supported platforms:

- Android APKs
- Linux `.tar.gz`
- Linux AppImage
- Windows `.zip`
- iOS `.ipa`
- macOS `.dmg`

It then creates a **draft GitHub Release** containing all generated artifacts and `boorusama-update.json`.

### Versioning

Fork releases use the upstream version as their base with a fork-specific prerelease suffix.

Example:

```text
4.5.0-timberpile.1+186
```

The corresponding Git tag is:

```text
v4.5.0-timberpile.1
```

The build number after `+` must increase with every release.

For multiple releases based on the same upstream version:

```text
4.5.0-timberpile.1+186
4.5.0-timberpile.2+187
4.5.0-timberpile.3+188
```

After updating to a new upstream version, reset the fork release number while continuing to increment the build number:

```text
4.6.0-timberpile.1+189
```

### Creating a release

1. Update the version in `pubspec.yaml`:

   ```yaml
   version: 4.5.0-timberpile.1+186
   ```

2. Add a matching section to `CHANGELOG.md` describing the changes in the release.

3. Commit the release preparation changes.

4. Create and push the release tag:

   ```bash
   git tag v4.5.0-timberpile.1
   git push origin develop
   git push origin v4.5.0-timberpile.1
   ```

5. On GitHub, open:

   **Actions → GitHub release → Run workflow**

   Set:

   ```text
   release_tag: v4.5.0-timberpile.1
   prerelease: false
   recreate_release: false
   ```

   Enable `prerelease` when publishing an experimental or preview build.

   `recreate_release` should normally remain disabled. It can be enabled when intentionally rebuilding an existing release and tag.

6. Wait for all platform builds to succeed.

   The workflow checks out the specified tag, so every artifact is built from the exact same commit.

7. Open the newly created **draft release** under GitHub Releases.

   Verify the release notes and attached artifacts, then publish the release manually.

### iOS

The GitHub workflow builds the iOS IPA with `--no-codesign`.

The resulting IPA is therefore unsigned and is primarily suitable for sideloading workflows that perform their own signing. Normal App Store or signed iOS distribution requires a separate Apple signing setup.

## Translation

Translations are managed via [Weblate](https://weblate.org/en/).

<a href="https://hosted.weblate.org/engage/boorusama/">
<img src="https://hosted.weblate.org/widget/boorusama/multi-auto.svg" alt="Translation status" />
</a>

## Feedback & Issues
Feel free to send me feedback on [Discord](https://discord.gg/tvyYVxjfBr) or [file an issue](https://github.com/khoadng/Boorusama/issues/new). Feature requests are always welcome.

## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.
