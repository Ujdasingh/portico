# Privacy

Portico has no analytics, advertising SDK, account system, or automatic log upload.

Profiles, Wine environments, snapshots, and session logs are stored locally.
Logs may include usernames, filesystem paths, application output, and other
sensitive information. Inspect and redact them before sharing a report.

The optional Help → Support Report screen previews an allowlist of app/build and macOS versions, app architecture, library state, profile counts, and active-operation count. It excludes profile names, identifiers, paths, notes, company data, licence details, raw errors, and logs. Saving creates a local text file in the location you choose; it does not transmit the report.

When requested, the runtime downloader contacts GitHub and its release-download
infrastructure to retrieve Wine. Those services receive normal network request
metadata. Links to Tally or other documentation open the destination service.

Windows applications and Wine may make their own network requests. Portico does
not filter their traffic or promise that their files and data remain offline.
A Wine prefix is not a security sandbox.

Removing Portico.app does not remove its library. Back up business data before
managing library files. Portico currently provides no automatic log or snapshot
retention policy.

The compatibility screen reads hardware specifications and available library-volume storage locally. This information is not added to the support report or uploaded. Opening a publisher/reference link contacts that website through the browser. Removed app entries and their files remain local until you manage them yourself.
