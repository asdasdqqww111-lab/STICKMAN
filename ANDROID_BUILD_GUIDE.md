# Android build guide — debug APK preparation

The project includes a preliminary `Android Debug` export preset for **arm64-v8a**. This is a debug test configuration, not a Play Store release. Its package ID `org.example.microworldliving` is a placeholder and must be changed before public distribution. The preset has not yet been exercised by an Android export in this environment. No APK or AAB exists here.

## Requirements on a build machine

- The **official Godot 4.7.2 stable** editor and matching export templates (Editor → Manage Export Templates).
- OpenJDK **17**.
- Android SDK with Platform-Tools 35.0.0 or later, Build-Tools **35.0.1**, Platform **35**, and Command-line Tools. Godot's 4.7 Android guide additionally lists CMake 3.10.2.4988404 and NDK 28.1.13356709; install those as documented, particularly for custom Gradle builds.
- In Godot Editor Settings → Export → Android, set the Java SDK Path and Android SDK Path. Configure or generate a local debug keystore using Godot's settings. Keep keystores and credentials out of the repository. Godot's export templates must match the editor version.

Official instructions: https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html

## Export and test

1. Open `project.godot` and allow all assets to import. Run the desktop and headless tests in `README.md` first.
2. Open Project → Export and select **Android Debug**. Resolve any validation errors in that dialog; configure the local debug keystore if requested. Choose **Export Project**, keep **Export With Debug** checked, and save an `.apk` outside the repository. Alternatively, after configuring the editor and creating the output directory, the command is:

   ```sh
   godot --headless --path . --editor --quit
   godot --headless --path . --export-debug "Android Debug" /absolute/path/to/micro-world-debug.apk
   ```

3. Verify the file actually exists and install on a compatible arm64 device with `adb install -r /absolute/path/to/micro-world-debug.apk`. Open it, check touch controls, gameplay and saving, close and reopen it, and record device/Android version and errors. A debug build is not a production release, and installation can fail if the same package ID is already installed with a different signing key.
4. For a store release, first complete the missing game systems and Android QA, choose an owned package ID, configure a private **release** signing key outside Git, use a Gradle build for AAB, and comply with Play policies. The debug key must not be used as a production signing identity.

## Status

This sandbox currently has no Godot executable, JDK, Android SDK, export templates, `adb`, or attached Android device. Outbound network restrictions block the GitHub release-asset host and Google's Android SDK host. The preset and instructions therefore remain **untested for export**; no performance, installation, or device compatibility is claimed. A remote CI build would require uploading the project and a build workflow to the user's GitHub repository and confirming the repository permits Actions.
