# Development environment

Observed on 16 October 2026 (Asia/Manila). This record distinguishes installed tools from checks still running.

## Paths and isolation

- Workspace: `G:\Mlang Presyo`.
- Flutter SDK: `G:\DevTools\flutter` (exact stable tag `3.47.7`, official manifest commit `abaf9c523780a608bd46686fd5e53740a07077f8`). Official Git checkout complete; a sparse working tree omits development examples, engine source, and SDK tests while retaining runtime libraries, tool source, and application templates. `flutter --version` **PASS** (exit 0): Flutter 3.47.7, Dart 3.13.5 stable, DevTools 2.60.0. The pinned engine revision is `deb287481e3ce9468f3434937ced4240a70539ca`; Flutter reports its engine content hash as `d8a2d6c768c334d53e16277f837970ffa1e2de81`. The channel label is `[user-branch]` because this SDK is checked out at the exact official stable tag rather than a moving branch; it is not a beta/main release.
- Project Java: `G:\DevTools\jdk-17`; installed Eclipse Temurin 17.0.20.1+1, verified with `java -version`.
- Android SDK: `G:\DevTools\Android\Sdk`; installed command-line tools package 15859902, `sdkmanager --version` reports 22.0. The wrapper reports that `sdkmanager` is deprecated in favor of the included Android CLI, but remains functional. Installed components: platform-tools 37.0.1, Android API 36 and API 35 platforms revision 2, build-tools 36.0.0, NDK 28.2.13676358 and CMake 3.22.1. API 35/CMake were installed during the successful build using previously accepted terms; no new terms were automatically accepted. APK build and inspection passed; see `VERIFICATION.md`.
- Pub cache: `G:\DevCaches\pub`; Gradle cache: `G:\DevCaches\gradle`; Android user state: `G:\DevCaches\android`; temporary files: `G:\DevTemp`.
- Dot-source `scripts/env.ps1` before local build commands. It changes the current process environment only. No machine-wide PATH, Java, or SDK setting is changed.
- The pre-existing system JDK is Eclipse Temurin 25.0.3+9. It is preserved.
- Host: Microsoft Windows 11 Home, version 10.0.26300; approximately 4 GB RAM. C: had approximately 2.4 GB free and G: approximately 422 GB free before setup. Build/cache files use G:.

## Source verification

- Official Flutter release manifest: https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json
- Flutter 3.47.7 official release archive SHA-256: `c2c875da25a1a1448d18ee4e8f398b2f6fce888b4775d8f9130538e16d826cb4`. The 1.93 GB archive download was stopped at 48 MB to avoid unnecessary transfer; installation instead uses the exact official Git tag. The partial archive is not used as an installation input and is not claimed verified.
- Official Flutter Git source: https://github.com/flutter/flutter, tag `3.47.7`.
- Eclipse Adoptium metadata: https://api.adoptium.net/v3/assets/latest/17/hotspot?architecture=x64&image_type=jdk&os=windows
- JDK ZIP SHA-256: **PASS**, `e53a79c3c3d86865bd7e787903884331068e71321714ffd44f145785affc7cb0` matches the official metadata before extraction.
- Official Android tools: https://developer.android.com/studio#command-line-tools-only
- Android CLI ZIP SHA-256: **PASS**, `90ae805d20434428bffcb699c290860f19bb5f66a67e6b330067e3de801fb04a` matches the official download page before extraction.
- Pinned engine Dart archive: `https://storage.googleapis.com/flutter_infra_release/flutter/deb287481e3ce9468f3434937ced4240a70539ca/dart-sdk-windows-x64.zip`; **PASS**, downloaded 219,878,313 bytes and compared its MD5 against Google's `x-goog-hash` object metadata (`j2+61z5/dUb9RAsdWACgpA==`). Extracted with `tar.exe`; the cache stamp was written only after the extracted Dart executable returned 3.13.5 stable successfully.
- Verified Android build configuration/output: compileSdk/targetSdk 36, minimum API 24, Gradle 9.3.1, Kotlin 2.4.0 and NDK 28.2.13676358. The debug APK includes arm64-v8a, armeabi-v7a and x86_64 libraries.

## License and device boundaries

The old C: SDK contains an `android-sdk-license` file with previously accepted hash `24333f8a63b6825ea9c5514f83c2829b004d1fee`. This existing acceptance was copied unchanged for the same SDK license. SDK package installation proceeded without requesting new acceptance. No new terms were automatically accepted. Any newly required license acceptance remains an owner action.

Platform-tools was installed from Google's official `https://dl.google.com/android/repository/platform-tools-latest-windows.zip` while the larger SDK components downloaded. Local archive SHA-256: `45f4d63113e895ebde0c90f194099a4676b6ac653bd28d54314a9e022bbc1a99` (recorded artifact identity; not a separately supplied checksum comparison). `adb version` reports Android Debug Bridge 1.0.41, platform-tools 37.0.1-15733141, installed under the G: SDK. Initial `adb devices -l` completed successfully and returned no connected devices. The user subsequently directed the team to build the APK and leave physical-phone testing to them later. Device polling stopped. Physical-phone installation, offline restart, TalkBack, system picker, and manufacturer transfer checks are **NOT RUN**, intentionally deferred by the user rather than prerequisites to producing the APK.

## Setup observations

- Initial full Flutter checkout was interrupted because materializing 16,076 files on G: was slow. A new sparse checkout completed 2,228 required runtime/tool files; `git reset --hard HEAD` completed at the exact official tag. No existing app files were replaced by this SDK operation.
- Early overlapping wrapper commands selected an engine before the SDK index was complete. Those wrappers and the obsolete BITS job were canceled; bootstrap was restarted only after the tracked release engine file was verified. Other agents were asked to wait for an explicit readiness signal to avoid concurrent cache initialization.
- JDK and Android CLI archives were extracted with Windows `tar.exe` after PowerShell extraction proved slow.
- Flutter's generated default Android Gradle heap was 8 GB. The project uses a 1024 MiB heap, 512 MiB metaspace cap, one worker and in-process Kotlin compilation on this approximately 4 GB host. The APK build completed with that configuration; AGP/Kotlin compatibility deprecation warnings remain recorded.

Flutter 3.47.7 and Dart 3.13.5 are runnable. Dependency resolution, 29-file formatting, analysis and all 69 tests in the post-schema complete suite passed. SDK example/dev package metadata was restored after the first analyzer run exposed a missing sparse-checkout root. Gradle 9.3.1 uses the smaller official binary distribution with its official SHA-256 pinned in the wrapper configuration. The diagnostic APK build completed successfully after 1 hour 54 minutes 20 seconds including cold-cache compilation and downloads. Artifact, signing, alignment, permission and backup-rule inspection passed. Official Drift schema dump/helper generation and initial-schema verification also passed. Exact results are recorded in `VERIFICATION.md`. Physical-phone installation remains intentionally deferred; no phone result is inferred from host checks or the APK build.
