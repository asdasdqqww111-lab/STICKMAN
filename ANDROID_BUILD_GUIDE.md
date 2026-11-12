# Android build guide — MICRO WORLD: LIVING

## The short version

You do not need to build anything: every push to this branch produces a downloadable APK and
attaches it to a GitHub Release.

1. Open the repository's **Releases** page and pick the newest `android-debug-*` tag.
2. Download `MICRO-WORLD-LIVING-<run>-debug.apk`.
3. `adb install -r MICRO-WORLD-LIVING-<run>-debug.apk`
4. Verify the download:

```bash
sha256sum MICRO-WORLD-LIVING-<run>-debug.apk       # compare with apk.sha256 in the same release
```

A verified build: run `43255276245` → **101,212,863 bytes**, SHA-256
`d43bfcf8afd54154c92346a315f8d16bdba803cefaaaa3742066fa98c058d9c8`, package
`com.microworld.living`, native libs for arm64-v8a / armeabi-v7a / x86_64.

## What the APK is (and is not)

| It is | It is not |
| --- | --- |
| A `--export-debug` build, signed with a **throwaway debug keystore generated per CI run** | Store-ready, or signed with any key you control |
| 96.5 MB, universal (all three ABIs) | Size-optimised |
| Verified to contain the game payload and manifest | Verified on physical hardware (no device existed in the build environment) |
| Installable on any Android 6+ arm64/armv7 device | Guaranteed to run at 60 FPS on any device — that is unmeasured |

## Reproduce the build locally

Requirements: **Godot 4.7.2** (editor + Android export templates), **JDK 17**, **Android SDK**
command-line tools with platform 35 and build-tools 35, and a debug keystore (Godot can generate one).

```bash
# 1. Editor settings: point Godot at Java + the Android SDK
#    Editor → Editor Settings → Export → Android
#      java_sdk_path    = /usr/lib/jvm/java-17-openjdk-amd64
#      android_sdk_path = $HOME/android-sdk

# 2. Create/confirm a debug keystore (Godot: Editor Settings → Export → Android → debug keystore)
~/.config/godot/editor_settings-4.7.tres   # must contain debug_keystore + debug_keystore_user/password

# 3. Import, then export
mkdir -p build
godot --headless --path . --import
godot --headless --path . --export-debug "Android Debug" build/microworld-living-debug.apk

# 4. Confirm it is real
ls -l build/microworld-living-debug.apk          # must be non-empty (CI checks this)
unzip -l build/microworld-living-debug.apk | grep -E "libgodot_android|assets/.*_data"
```

`tools/ci/build_android.sh` does exactly this and is what CI runs — read it as the canonical script.

## How CI does it (the environment this project actually validates)

`.github/workflows/android-build.yml`:

| Step | Detail |
| --- | --- |
| Godot | `tools/ci/install_godot.sh` with `WITH_TEMPLATES=1` — downloads 4.7.2 stable + export templates (1.28 GB) |
| JDK | Temurin **17** |
| Android SDK | `commandlinetools-linux-11076708_latest.zip`, then `sdkmanager` platform 35 + build-tools 35 |
| Keystore | generated at `~/.android/debug.keystore` with a fixed alias/password (no secret needed) |
| Export | `--export-debug "Android Debug" build/microworld-living-debug.apk` (no Gradle required) |
| Verification | zip listing checked for `lib/arm64-v8a/libgodot_android.so`, the embedded payload and the `com.microworld.living` package string in the binary manifest |
| Delivery | `apk.sha256`, artifact `microworld-living-debug-apk`, Release tag `android-debug-<run>` |

Nothing secret is committed: the debug keystore is created inside the runner and discarded.

## Making a signed **release** build (Play-ready)

Not done in this repo, because committing a keystore or its password is forbidden. To do it yourself:

```bash
keytool -genkeypair -v -keystore release.keystore -alias microworld \
  -keyalg RSA -keysize 2048 -validity 10000
```

Then, in Godot: **Project → Export → Android Release**, uncheck *Export With Debug*, set
`release keystore`, `release user`, `release password` in the preset's Android options (and add them
to `.gitignore` / CI secrets, never to `export_presets.cfg`), and export:

```bash
godot --headless --path . --export-release "Android Release" build/app-release.aab   # for Play
godot --headless --path . --export-release "Android Release" build/app-release.apk   # for sideload
```

Store submission additionally requires a 512×512 icon, a feature graphic, a privacy policy (this
build has **no network permission** and stores only local save data, which makes that easy), and a
`version/code` bump per upload.

## Device test checklist (still outstanding)

Whoever has hardware should run this and paste results into `TEST_REPORT.md`:

- [ ] Install on Android 9 and Android 13+ devices
- [ ] First launch: menu appears in landscape, **Continue is disabled** on a clean install
- [ ] New Game → world loads → joystick moves the player
- [ ] Attack, heavy attack, dodge, cast, interact all respond to touch
- [ ] Kill a monster → XP + loot; accept a quest from the registrar
- [ ] Settings → Performance overlay: record FPS at Havenbrook, in combat, in the barrow
- [ ] Save, kill the app, relaunch → Continue restores position, inventory, quests, rank
- [ ] Rotate the device / open the app switcher → the game survives or restores cleanly

## Known Android constraints

- **Min SDK is the template default (Android 6+)** because the Gradle-less export path does not
  expose a `min_sdk` override. Android 9 compatibility is therefore satisfied as a subset, not pinned.
- APK size is dominated by three copies of `libgodot_android.so` (~240 MB uncompressed → 96 MB
  zipped). Dropping x86_64 and armeabi-v7a in the preset cuts it by roughly half, at the cost of
  emulator/x86 support.
- The game requests **wake lock** and **vibrate** only; `internet` is explicitly `false`.
