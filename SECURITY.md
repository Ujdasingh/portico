# Security

Portico is a development preview. Do not use it to run untrusted executables or
as the only backup for business-critical data.

Report vulnerabilities through the repository's private vulnerability reporting
feature. Do not publish credentials, licences, company data, or unredacted logs
in an issue. Include the Portico version, macOS and architecture, relevant
reproduction steps, and a minimal synthetic example where possible.

## Boundaries

- Wine environments separate settings, not operating-system permissions.
- Download checksums identify the pinned artifact, not its trustworthiness.
- The upstream runtime is separate software with its own security lifecycle.
- Prefix operation locks coordinate Portico clients; independent Windows or
  filesystem tools do not honor those locks.
- Local library files and externally selected runtimes are trusted local input.
- No supported-version security SLA is offered during the preview.
