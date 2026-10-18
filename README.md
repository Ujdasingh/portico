# Portico

A native macOS workspace for Windows business applications, powered by Wine.

Portico manages installation, launch settings, separate Windows environments, local logs, and recovery snapshots. TallyPrime is the first tested application family. **Version 0.3 is a development preview, not a certified production accounting environment.**

## Features

- Native SwiftUI library with the installed applications’ own icons.
- EXE/MSI installation and portable-app folder import.
- Separate per-app Wine prefixes and remembered runtime paths.
- Checksum-verified download of a pinned Wine macOS release.
- Correct working directories and argument-array subprocess launching.
- Environment snapshots before installer changes, with SHA-256 integrity verification, staged restore, and a preserved previous copy.
- Per-environment operation locks and a library lifetime lock to prevent conflicting app instances.
- Reconnection to Windows sessions left running after Portico exits.
- Local session logs with readable diagnostics and scoped process shutdown.

## Requirements

- macOS 14 or later; Apple silicon is the hardware tested so far.
- Rosetta for the selected x86 Wine runtime on Apple silicon.
- Xcode command-line tools to build Portico from source.
- Your own licences for commercial Windows software.

The current Wine package is not notarized and its Homebrew cask is disabled. Portico does not disable Gatekeeper or remove quarantine. Some applications require additional dependencies such as GStreamer. See [runtime provenance and research](docs/RESEARCH.md).

## Build and run

```sh
./scripts/build.sh
open dist/Portico.app
```

Use **Runtime setup** to download the pinned engine or select a complete standalone Wine app. Run **Check engine**, then **Open Windows test**. Add an official installer through **Add Windows app**, complete its Windows setup, and select the installed executable if needed.

Use **Launch app** to start the application. Save and close its windows before making snapshots. Background Windows services can keep a profile busy; **Stop app** stops all processes in that profile and can discard unsaved work.

A Wine prefix separates configuration; it is **not a security sandbox**. Windows software has access to files available to your Mac account.

## Storage

The default library is `~/Library/Application Support/Portico`. It contains app profiles, Windows environments, runtimes, logs, and backups. Keep it on local storage with sufficient free space.

A marked `Portico Data` folder beside the app enables portable mode. The `.portable-library` marker must be present. `PORTICO_HOME` overrides the location for development. A locally configured installation can use the `PorticoLibraryPath` Info.plist key; public builds do not contain a personal library path. Runtime paths are currently absolute, so moving a prepared library requires updating those paths.

Backups include the prefix only. External folders, network shares, and symlink targets need independent backups. New backups record file hashes and symbolic-link destinations, verify the copied environment, and verify again before and after staging a restore. These checks detect accidental damage, not malicious replacement of both data and metadata. Older backups without integrity records remain on disk for manual recovery; automatic restore is disabled for them. There is no automatic retention policy. Restores preserve the previous prefix in a `before-restore-*` folder.

## TallyPrime

Install the release covered by your licence/TSS entitlement. Installation of 5.1 and 7.2 has been observed locally; full accounting, licensing, printing, integration, and offline acceptance testing is still outstanding. Portico does not activate licences, renew TSS, bypass entitlement checks, or migrate company data automatically.

Test using a disposable company or copied data. Data upgraded by a newer Tally release may not open safely in an older release. Keep a compatible backup.

## Test

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache" \
swift test --disable-sandbox
```

Use **Help → Support Report…** to preview and save basic diagnostics without including company data, licence details, app names, paths, or logs. Reports are local and are never uploaded automatically.

Tests cover subprocess arguments, locking, persistence failures, traversal/symlink containment, backup/restore, runtime validation, timeouts, and malformed executable icon resources. Fake runtime scripts verify backend contracts; they do not certify third-party app compatibility. CI runs the same tests and builds the app on macOS.

## Release status

Read [release requirements](docs/RELEASING.md), [verification](docs/VERIFICATION.md), [privacy](PRIVACY.md), and [security reporting](SECURITY.md). Apple Developer ID signing, notarization, a supported runtime distribution, and a completed application compatibility matrix are required before marketing this as production-ready.

## Rights

Copyright reserved. Public source visibility does not grant a licence to copy, modify, redistribute, or commercially exploit this project. See [LICENSE](LICENSE). Third-party software and trademarks remain subject to their owners’ terms. Wine, Tally installers, company data, licences, logs, and credentials are not included in this repository.

## App management and compatibility

- **Manage app → Uninstall program…** creates a verified prefix backup, then opens Wine’s Windows uninstaller for that environment. Complete or cancel the Windows dialog yourself. Some portable applications have no registered uninstaller. External data is not in the backup.
- **Remove from library…** hides an idle profile while retaining its environment, data, runtime and backups. **Removed apps → Recover** returns the same entry. This does not free storage or surrender a licence. Use a program's uninstaller to remove its installed files; Portico has no permanent environment deletion action.
- **This Mac & compatibility** reads chip, RAM, Metal GPU, macOS and free library-volume storage locally. Business/game tabs offer a small, dated guidance catalog with publisher/reference links. Memory/storage thresholds are conservative planning advice, not measured app requirements. The screen does not change existing runtime configuration, download anything, or upload hardware information.
- No Windows game is verified by Portico. Native alternatives, limited user reports, experimental cases and unsupported anti-cheat requirements are distinguished. CrossOver and Steam Deck results do not establish Portico compatibility.
