# Verification — 14 October 2026

Host: Apple M1 Pro, macOS 15.8.1; native SwiftUI app built using Swift 6.2.4 in Swift 5 language mode. Selected engine: Wine 11.0_1, with Rosetta already available.

## Passed

- Debug and release builds; ad hoc local app signing.
- 10 automated backend tests, zero failures: checksum/diagnostics; executable discovery; path traversal and symlink rejection; foreign snapshot rejection; argument preservation and working directory; JSON round-trip/corruption preservation; incomplete runtime rejection; overlapping operation rejection; snapshot/restore preservation; subprocess timeout.
- Runtime archive SHA-256 matched its published pinned value.
- Portico's actual download flow completed and discovered the downloaded engine.
- Real Wine `cmd /c echo PORTICO_REAL_WINDOWS_OK` returned exit code 0 and the expected output.
- Portico created a real Wine environment and started Wine's Windows Notepad process. Its `.portico-ready` marker was written after initialization completed.
- Portico's Stop app action stopped that test environment. A misleading error after an intentional stop was found and corrected in the final source.
- Portico's native add-app and file-picker flow started the official TallyPrime 7.2 installer process in a second environment.
- The user confirmed that the Tally installation window is visible on the Mac.

The automated tests use controlled fake engine scripts for filesystem and subprocess contracts. They do not establish compatibility with TallyPrime or any other third-party Windows application.

## Not yet verified

The desktop automation tool could inspect Portico's native controls but did not expose Wine's windows. Notepad process creation is verified; its rendered contents and interaction are not. The user confirmed Tally's installer is visible, but installation completion, Tally launch, activation, accounting data operations, printing, exports, peripherals, performance, and sustained offline use have not been verified.

No production company data or licence credentials were used. No EULA was accepted by the agent. No Gatekeeper setting or quarantine attribute was changed.

## First Tally acceptance run

1. Finish the official installer in its Windows window, using the prefix's C: drive. Close installer/helper windows; select `tally.exe` if discovery does not select it.
2. Launch Tally and inspect rendering and keyboard navigation.
3. Create a disposable company or use an explicitly copied backup. Enter a sample voucher, close, relaunch, and verify it persisted.
4. Test PDF/printing, exports, required integrations, and licence behavior.
5. Close Tally and its background services. Create a Portico backup, make a harmless test change, restore, and check both restored data and preserved previous environment.
6. Repeat the required workflow offline within the app's licence conditions. Record exact Tally/engine/macOS versions and failures.

Do not infer that a startup success validates the rest of these steps.

## 0.2.0 hardening — 15 October 2026

- 15 automated tests pass, including library lifetime locking and malformed PE resource offsets.
- Native Portico UI reports TallyPrime 5.1 and 7.2 installed, with their installed tally.exe paths selected. The earlier installer-only observations above describe the first test session. Licence activation and accounting acceptance tests remain unverified.
- Real installed icons for both Tally versions and Wine Notepad were extracted and decoded locally.
- Windows sessions are checked on startup and monitored until they close; duplicate library writers are refused.
- The public build contains no personal library pointer; the configured local Applications copy is separate.
- Developer ID signing and notarization remain unverified because release credentials have not been supplied.

Startup file I/O runs off the main thread, and the environment idle probe rejects a nonzero wineserver result before snapshotting.

## 0.2.1 hardening — 18 October 2026

- The user reports that Tally is working in their existing setup. This is a user-reported result; the exact accounting, printing, licence, and offline workflows exercised have not been recorded.
- Backups now hash regular file contents, record directories and symbolic-link destinations without following external targets, and verify the copied tree before publishing snapshot metadata.
- Restore verifies the manifest digest, original backup, and staged copy before moving the current environment. Older snapshots remain preserved for manual recovery but cannot be restored automatically without integrity records.
- Failed backup and restore staging copies are cleaned up. Wine initialization no longer marks a prefix ready if the final wineserver wait fails.
- All 19 automated tests pass; the native release build and ad hoc signature verification pass. Regression tests cover damaged data, damaged manifests, legacy metadata, missing/extra entries, changed links, external-link isolation, and failed initialization.

The working installed application and its Tally environments have not been modified by this source update. Developer ID notarization and the broader release gates remain outstanding.

## 0.2.2 support and metadata hardening — 18 October 2026

- All 22 automated tests pass; native release build and ad hoc signature verification pass.
- Library load/save rejects duplicate profile identifiers and malformed executable/runtime paths. Failed validation preserves the existing metadata file.
- Help → Support Report previews an allowlist of versions, architecture, library state and counts. It never includes profile names, identifiers, filesystem paths, notes, licence details, raw errors, or logs. Export is a user-selected local text file; there is no upload. Tests check that private profile fields cannot enter the report.
- Installed 0.2.2 in Applications, preserving its configured library pointer and a rollback copy of the previous app. No Portico or Tally process was running before replacement.
- Native UI verification: report displays version 0.2.2/build 4, library ready, three profiles and zero active operations. TallyPrime 5.1 retains its original executable selection and pinned runtime. The library metadata checksum is unchanged after app startup. Tally was not launched, reinstalled, reactivated, or migrated during this update.
- Developer ID signing/notarization, supported runtime distribution and the remaining accounting/peripheral acceptance gates are still outstanding.

## 0.3.0 app management and compatibility — 18 October 2026

- All 27 tests pass. New tests check backup-before-uninstaller behavior, refusal without backup or idle confirmation, removed-profile metadata recovery and hardware-based guidance rules. The uninstaller process tests use a fake Wine fixture; an actual Windows uninstall was not executed against the user's apps.
- Release build and ad hoc signature verification pass. Installed in Applications with the existing library pointer and prior app retained for rollback. Library metadata checksum remains unchanged after startup/UI checks.
- Native UI shows Uninstall program and Remove from library, Removed apps navigation, and the new compatibility screen. The uninstall confirmation was inspected and cancelled. No app was uninstalled or hidden during verification.
- Hardware UI correctly detected the test Mac as Apple M1 Pro, 16 GB RAM, macOS 15.8.1, M1 Pro Metal GPU, approximately 58 GB free library-volume storage. Business and Games tabs and their references were inspected; screenshot layout verified.
- No Tally environment, runtime or licence configuration was changed. Native Mac recommendations and experimental Windows/game guidance are not compatibility guarantees.

## 0.3.1 uninstall launcher correction — 18 October 2026

Wine 11's no-argument uninstaller calls the Programs control panel and then unconditionally returns 1. Portico incorrectly interpreted this as failure. The launcher now uses `control.exe appwiz.cpl`, which opens the same applet with normal completion status. Real nonzero launcher/server failures remain errors. Panel completion is not proof that a program was removed.

References: [Wine uninstaller source](https://raw.githubusercontent.com/wine-mirror/wine/wine-11.0/programs/uninstaller/main.c), [Wine control source](https://raw.githubusercontent.com/wine-mirror/wine/wine-11.0/programs/control/control.c).

All 28 tests pass, including exact control-panel arguments and preservation of actual error exit codes. Release build and signature verification pass. Tests use controlled processes; the agent did not execute a Windows uninstall against the user's environments.

## 0.4.0 native macOS interface — 18 October 2026

- Replaced custom fixed sidebar and page header with NavigationSplitView, a native selectable sidebar, sidebar search and unified title-bar toolbar.
- Standard macOS button styles replace custom button rendering. Semantic system text/background/accent colors replace fixed light-only colors; the app now follows system appearance. Full dark-mode visual QA remains pending.
- Real extracted app icons are retained; missing icons use a neutral SF Symbol. Navigation and actions use consistent symbols with text or accessible labels/tooltips. Decorative app artwork is hidden from accessibility to avoid repeating nearby app names.
- Library overview shows installed apps instead of marketing artwork. App pages prioritize Open, group common tools and backups, and place launch details and removal actions in disclosure groups.
- All 28 existing automated tests pass. Native release build and ad hoc signature verification pass. Installed in Applications with library metadata unchanged and previous application retained. UI screenshot and interaction validation could not yet run because the Mac became locked; the user was asked to unlock it.

Design references: [Apple sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars), [buttons](https://developer.apple.com/design/human-interface-guidelines/buttons), [SF Symbols](https://developer.apple.com/design/human-interface-guidelines/sf-symbols), [toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars). The implementation uses macOS 14-compatible native controls, not newer-OS-only visual APIs.

## 0.4.1 UI verification and overview navigation fix — 19 October 2026

- Resumed native UI checks after the Mac was unlocked. All Apps did not clear the existing selection because a nil model selection conflicted with native List selection. Added a distinct, typed overview selection alongside app selections.
- Built and installed the fix, then verified All Apps opens the library overview and highlights its row. Selecting an overview card opens the matching app detail without launching it. Native sidebar hide/show works.
- Inspected dark-mode screenshots of app detail, overview and Add App dialog. Original installed icons, readable system colors and standard controls render correctly. Checked search/no-results, settings/management disclosures, compatibility sheet and Escape dismissal. No system appearance preference was changed; light-mode visual verification remains separate.
- Installed version 0.4.1 retains the library pointer, metadata checksum and a rollback copy of the previous app. Tally was not launched, stopped, uninstalled or reconfigured. Left the application on TallyPrime 5.1's detail page.
- Native release build and signature verification pass. This change is limited to view selection state and version metadata; manual interaction checks exercise the actual regression.

## 0.5.0 permanent app deletion — 19 October 2026

- Replaced library hiding/recovery with permanent Delete App. Previously hidden entries are visible again until explicitly deleted. Uninstall Program remains available.
- Deletion requires an idle environment and operation lock, validates all destinations before mutation, and removes only that profile’s environment, logs and backups. Shared runtimes and external symlink targets are preserved.
- All 30 tests pass, including scoped deletion, external-target preservation, redirected-path rejection and failed-idle-probe refusal. Release build and ad hoc signature verification pass.
- Installed 0.5.0 with the existing library pointer and unchanged metadata during bundle replacement. Verified the two remaining app entries, management buttons and permanent-deletion warning; cancelled the test dialog.
- The user-requested hidden older TallyPrime environment was deleted separately through the tested backend. TallyPrime 5.1 and the shared runtime remain. No Tally launch, licence change or reconfiguration was performed.
