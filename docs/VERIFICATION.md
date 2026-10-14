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

- 13 automated tests pass, including library lifetime locking and malformed PE resource offsets.
- Native Portico UI reports TallyPrime 5.1 and 7.2 installed, with their installed tally.exe paths selected. The earlier installer-only observations above describe the first test session. Licence activation and accounting acceptance tests remain unverified.
- Real installed icons for both Tally versions and Wine Notepad were extracted and decoded locally.
- Windows sessions are checked on startup and monitored until they close; duplicate library writers are refused.
- The public build contains no personal library pointer; the configured local Applications copy is separate.
- Developer ID signing and notarization remain unverified because release credentials have not been supplied.
