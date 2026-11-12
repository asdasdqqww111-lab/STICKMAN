# Environment audit — 2026-11-11

- Working repository initially at commit `662497db86df43bdb511a7c1d7fba6b70063d0e3`, containing only `README.md`, with no uncommitted changes. Working branch: `arena/c632b8bc-stickman`.
- Linux x86_64, 2 CPUs, ~3.8 GiB RAM, ~20 GiB initially available. No installed Godot, Java, adb, sdkmanager or Gradle found on PATH; `JAVA_HOME`, `ANDROID_HOME` and `ANDROID_SDK_ROOT` unset.
- GitHub API latest stable release queried as `4.7.2-stable` on 2026-11-11. Its executable download redirects to `objects.githubusercontent.com`, which is outside the permitted outbound hosts, and failed. Source download from `codeload.github.com` succeeded. A headless Linux editor build from that source succeeded with a local SCons installation and disabled platform graphics/audio backends; see the test report for executed tests and warnings. This locally compiled test tool is outside the repository and is not an Android export template or release editor.
- No Android device, SDK, export templates or JDK were available for build/test.
