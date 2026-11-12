# Environment audit — MICRO WORLD: LIVING

Date of audit: 2026-11-12. Every line was verified by running the command shown; nothing is assumed.

## 1. The development sandbox (where this work was done)

| Tool | Available? | Evidence | Consequence |
| --- | --- | --- | --- |
| Godot editor / runtime | **No** | `godot --version` → not found; no display server | Engine runs happen in CI only |
| JDK 17 | **No** | `java -version` → not found | Android export happens in CI only |
| Android SDK / build-tools / adb | **No** | `$ANDROID_HOME` unset, no `sdkmanager` | Same |
| `dl.google.com` (SDK + templates) | **Blocked** | connection refused/timeout | Cannot install the SDK locally |
| GitHub release asset CDN, `raw.githubusercontent.com` | **Blocked** | 403 / DNS failure | Cannot download binaries directly |
| `codeload.github.com` (repo zips) | **Allowed** | `curl -I` 200 | Asset fetching works |
| `github.com`, `api.github.com` | **Allowed** | `git ls-remote`, `gh api` succeed | Push / CI / Releases work |
| Python 3.11 + `gdparse` (gdtoolkit) | **Yes** | `gdparse --help` | Local GDScript syntax gatekeeping |
| Physical Android device | **None** | no `adb` devices | Device testing and real FPS are **unverifiable here** |

**Net effect:** no build, export or runtime could be produced inside the sandbox. All engine work was
therefore routed through GitHub Actions, and *every* result quoted in these documents comes from a
committed CI log rather than from local claims.

## 2. What GitHub Actions provides (the real toolchain)

| Component | Version | Source |
| --- | --- | --- |
| Runner | `ubuntu-latest` | GitHub-hosted |
| Godot | **4.7.2-stable** (editor + export templates) | `godotengine/godot-builds` release, pinned in `tools/ci/install_godot.sh` |
| JDK | Temurin **17.0.21** | `actions/setup-java` |
| Android cmdline-tools | `11076708_latest` | Google repository, downloaded at build time |
| Android platform / build-tools | **35** / **35** | `sdkmanager` |
| Python | 3.12 | runner image (for `tools/check_assets.py`) |

Godot download sizes confirmed during setup: editor zip 77.9 MB, export templates 1,281.3 MB,
Android template AAR 103.3 MB.

## 3. Environment reproducibility

- Engine version is **pinned**, not "latest": `tools/ci/install_godot.sh` hard-codes `4.7.2-stable`,
  and the project's feature tags require `4.7`.
- The APK build creates a **throwaway debug keystore per run**; no key material exists in the repo.
- No secrets are required for either workflow.
- Both workflows commit their raw logs to `.ci/` so a failing run is diagnosable from the repository
  itself (artifact and log blob CDNs are not reachable from the sandbox).

## 4. Environment gaps that affect the acceptance criteria

| Criterion | Sandbox status | Mitigation taken |
| --- | --- | --- |
| "Project opens in Godot without blocking errors" | Engine absent | CI imports the project and **fails on any `SCRIPT ERROR`**; run 43258628395+ is clean |
| "A real APK is produced" | SDK/blocked network | Built in Actions; Release `android-debug-6` with checksum attached |
| "Performance targets measured" | No device, no GPU | World-generation benchmark measured in CI; on-device overlay shipped; **targets explicitly not claimed** |
| "Tested on a device" | No device | Stated as untested in `TEST_REPORT.md` and `KNOWN_ISSUES.md` |

## 5. Things worth knowing before touching the code

- GDScript in 4.7 is strict about typed arrays: assigning a plain `Array` literal to an
  `Array[Dictionary]` property fails at runtime. Use `.assign()` (two live bugs came from this).
- Static functions on a `preload`ed script constant are **not** callable through `<Const>.`, so
  instantiating at runtime requires `(load("res://...") as GDScript).new()`.
- glTF imports keep bones inside `Skeleton3D`; a bone is not a `Node3D` you can parent to. Use
  `BoneAttachment3D`.
- `Sky.material` is read-only in 4.7 — call `set_material()`.
- The verify workflow and the Android workflow both push to the same branch; both retry
  `git pull --rebase` before publishing, or one silently loses its logs.
