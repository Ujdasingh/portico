# Release requirements

## Current status

Version 0.4.0 is a source-available development preview with copyright reserved.
A public repository and passing tests do not establish commercial readiness.
There is no production-support SLA or guarantee that an arbitrary Windows app works.

## Engineering checks completed locally

- Backup integrity manifests, verification before replacement, and cleanup of failed staging copies.
- Native release build and ad hoc signature verification.
- Unit tests for process, persistence, recovery, locking, deferred library preparation, and PE icon parsing.
- Background library loading keeps the window responsive during protected-folder access.
- Actual icon extraction from installed TallyPrime 5.1, 7.2, and Wine Notepad.
- Runtime checksum/download and real Windows command execution.
- Separate installation of TallyPrime 5.1 and 7.2 observed.
- No business data, licences, runtimes, or credentials included in source publishing.

## Distribution procedure

The default `scripts/build.sh` produces an ad hoc signed app for local testing.
It does not produce a notarized customer release. To create a notarized archive:

```sh
SIGNING_IDENTITY='Developer ID Application: Your Company (TEAMID)' \
NOTARY_PROFILE='your-existing-keychain-profile' \
./scripts/package-release.sh
```

Use your own Apple Developer membership, identity, and preconfigured notarytool
keychain profile. Never put certificate private keys or Apple credentials in Git.
The script builds, enables hardened runtime, signs, submits for notarization,
staples, verifies, and creates a checksum. It stops if required credentials are
absent or a local library path is embedded. This pipeline has not yet been run
with a real Developer ID or notarization account. Artifacts are host-architecture
builds; Intel support and universal builds require separate validation.

Only publish a binary after the release gates below pass. Do not package the
workspace library or downloaded third-party applications with the app.

## Outstanding release gates

1. Establish a maintained, appropriately licensed and signed runtime supply chain.
   The pinned upstream runtime currently has notarization/distribution limitations;
   notarizing Portico alone does not notarize Wine or solve those limitations.
2. Complete an acceptance matrix on supported macOS/hardware combinations: clean
   installation, rendering, keyboard navigation, licensing, save/close/reopen,
   printing, exports, integrations, offline workflows, and representative app sizes.
3. Exercise interruption, full disk, power loss, corrupted backups, and migration
   recovery. Validate external-data backup guidance with realistic deployments.
4. Validate accessibility, localization, download cancellation, backup retention,
   library relocation, and application lifecycle behavior under real user workloads.
5. Decide pricing, support ownership, rights to distribute dependencies, terms,
   product privacy commitments, and trademark clearance. Current copyright is
   reserved; public visibility does not grant third-party reuse rights.
6. Review notarized release artifacts on a clean Mac with normal Gatekeeper settings.

## Security and privacy review before every publication

Inspect `git ls-files`, staged diffs, and the archive contents. No personal home
paths, app libraries, licence files, logs, credentials, downloaded executables,
or company data should be included. Use a GitHub noreply address for publication
if the maintainer's private email should not appear in commit metadata.
