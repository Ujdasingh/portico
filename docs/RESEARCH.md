# Research and engineering choices

Reviewed 14 October 2026. Compatibility reports are evidence for a specific combination of app, engine, hardware, and workflow; they are not blanket certification.

## Why build on Wine

Reimplementing Windows APIs, graphics, COM, services, printing, and architecture translation is a major systems project. A native manager around an existing engine is the practical first implementation. Portico improves setup, file handling, recovery, and visibility into failures. It cannot repair missing Windows APIs or unsupported kernel drivers through interface code.

[Gcenx's macOS Wine builds](https://github.com/Gcenx/macOS_Wine_builds) supply an engine supporting 32- and 64-bit Windows executables. The package must remain intact, including its libraries. The engine is separate from the native SwiftUI application. On this Apple silicon Mac, the x86 runtime uses Rosetta.

The [Homebrew wine-stable listing](https://formulae.brew.sh/cask/wine-stable) currently lists 11.0_1 and marks the cask disabled. Its [metadata](https://formulae.brew.sh/api/cask/wine-stable.json) supplies the pinned artifact digest; the upstream [notarization issue](https://github.com/Gcenx/macOS_Wine_builds/issues/168) explains a distribution problem that a wrapper should expose rather than conceal. Portico downloads directly from the upstream release, verifies the known digest, and never runs commands to disable platform security. Checksum verification establishes artifact identity, not compatibility or trustworthiness.

[Whisky](https://github.com/Whisky-App/Whisky) demonstrated a native SwiftUI interface but is archived. Its maintenance status makes it a poor long-term engine baseline for a new business app. [Sikarugir](https://github.com/Sikarugir-App/Sikarugir) shows the value of per-app wrappers and engine management. Portico was implemented independently; it does not copy their source or redistribute commercial engine components.

## Problems addressed in this implementation

| Problem | Implemented response | Remaining boundary |
| --- | --- | --- |
| Changing an engine can change a working environment | Per-app runtime paths and versioned managed downloads | An externally managed engine can still change at the same path |
| Apps rely on adjacent files and a particular working directory | Launch beside the executable; copy the whole portable app directory | Vendor installers may need extra Windows dependencies |
| Shared settings/dependencies conflict | One prefix per app | An app suite intentionally sharing components needs manual setup |
| Installer exits but leaves child processes active | Wait for Wine clients to exit before releasing the operation lock | Persistent services can keep a profile busy until explicitly stopped |
| Backing up live registry/data creates inconsistent snapshots | Idle check and a cross-process per-prefix lock | Independent external tools do not honor Portico's lock |
| Updates damage a working setup | Snapshot before rerunning an installer; staged restore with preserved old prefix | External folders and app-driven updates need separate protection |
| Spaces, shell characters, path escapes and symlinks cause errors | Argument arrays; executable containment checks; symlink-preserving copies | Windows software itself remains trusted code with user-level access |
| Generic “failed” messages make troubleshooting hard | Private session logs with a bounded viewer and targeted diagnostics | Logs are not a substitute for application-specific debugging |

## Tally-specific limits

[Tally's system recommendations](https://help.tallysolutions.com/recommended-system-configuration-for-tallyprime/) describe Windows requirements. Wine is a compatibility experiment outside that normal platform specification. A positive [CrossOver Tally compatibility report](https://www.codeweavers.com/compatibility/crossover/changelog/tally-9/?sort%5Blog_id%5D=%3Bsort%5Bcustomer_id%5D%3DASC) is encouraging but uses a different engine and does not certify this build.

[Tally licensing guidance](https://help.tallysolutions.com/licensing-best-practices/) still governs offline use and periodic revalidation. Portico cannot promise indefinite offline licensed operation or bypass activation.

[CodeWeavers' USB guidance](https://support.codeweavers.com/using-usb-devices-with-crossover) describes limits on Windows USB device support. Signature tokens and vendor kernel drivers need separate validation; a wrapper cannot assume they work. The selected upstream engine's published configuration also disables generic USB support. Printing, Excel integration, bank import/export, add-ons, and licensing are independent acceptance tests, not consequences of successfully opening the program.

## Runtime provenance

- Version: Wine 11.0_1 macOS package, reports `wine-11.0`.
- Download: https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.0_1/wine-stable-11.0_1-osx64.tar.xz
- SHA-256: `b50dc50ec7f41d58b115a6b685d4d1315ba3c797bd3aa0f49213f2703cb82388`.
- Complete package retained; no runtime libraries copied into Portico.app.
- Tally installer source: official Tally download utility, resolving to https://tallymirror.tallysolutions.com/download_centre/Rel7.2/TP/Full/setup.exe.

## Work required before calling this production-ready

Complete Tally installation and its accounting acceptance tests on copied data; investigate any resulting engine failures; validate peripherals and offline licence behavior; test recovery after power loss and low disk space; add signed/notarized distribution and a maintained runtime update policy. These are outstanding work, not claimed capabilities.
