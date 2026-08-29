# iPad1VNC Responsibility Audit

This audit records existing iPad1VNC features that overlap another iPad1 suite application's intended responsibility.

## Decision rule

A feature should remain in iPad1VNC only when it is primarily about:
- RFB/VNC;
- VNC input/clipboard;
- VNC profiles/diagnostics;
- VNC discovery/WOL;
- Direct/TLS/SSH-tunnel transport needed to carry VNC;
- lightweight orchestration around the currently connected remote host.

Otherwise prefer delegation.

## Existing implementation audit

| Existing iPad1VNC capability | Long-term owner | Status |
|---|---|---|
| RFB 3.8 / VNC auth | iPad1VNC | Keep |
| RAW / Hextile / Tight | iPad1VNC | Keep |
| Direct/Trackpad/Precision/Drag Lock | iPad1VNC | Keep |
| Clipboard | iPad1VNC | Keep |
| TLSVnc/X509Vnc | iPad1VNC | Keep/fix |
| SSH tunnel for VNC | iPad1VNC | Keep |
| WOL | iPad1VNC | Keep |
| VNC-oriented LAN discovery | iPad1VNC | Keep |
| VNC profiles/quality/diagnostics | iPad1VNC | Keep/improve |
| Embedded interactive SSH terminal | iPad1Terminal | Transitional fallback |
| Terminal emulation/buffer UX for shell | iPad1Terminal | Transitional fallback |
| Shell-specific SSH key/connect UX | iPad1Terminal | Migrate when provider ready |
| Remote directory browser tied to current host | iPad1VNC | Keep lightweight |
| Remote Files mkdir/rename/delete | iPad1VNC orchestration | Keep small; do not expand |
| Download/upload engine | iPad1FTPDownloader | Transitional fallback |
| Transfer queue | iPad1FTPDownloader | Do not further productize in VNC |
| Pause/resume/cancel/retry | iPad1FTPDownloader | Do not further productize in VNC |
| Large transfer resume state | iPad1FTPDownloader | Migrate |
| Local folder picker/destination UI | iPad1Files | Delegate |
| Local upload-file picker | iPad1Files | Delegate |
| Local copy/move/delete/ZIP | iPad1Files | Never add to VNC |
| PDF/text preview | iPad1PDFReader | Never add to VNC |
| Shell-command macros | iPad1Terminal | Never add to VNC |
| RFB Quick Keys | iPad1VNC | Keep |

## Current provider blockers

### iPad1Terminal

Current project state is Local Terminal/PTTY first. SSH is not yet implemented and its own roadmap explicitly says not to jump directly to SSH.

Result:
- embedded iPad1VNC interactive SSH terminal cannot be removed yet;
- no new terminal-specific features should be added to it;
- migration begins only after iPad1Terminal owns stable SSH and a safe launch contract.

### iPad1FTPDownloader

The app is the suite network-transfer specialist, but iPad1VNC currently transfers through a custom authenticated HTTP Files API. Before delegating, verify that generic HTTP/Files-API transfer jobs fit the Downloader architecture and define a secret-safe job/profile reference. Do not put Files API tokens in URL schemes.

### iPad1Files

Use it for local path/file selection and local filesystem operations. Do not duplicate a filesystem browser inside iPad1VNC.

### iPad1PDFReader

Use it for supported document rendering after a local file exists. iPad1VNC must not add document preview code.

## Migration sequence

1. Preserve known-good iPad1VNC behavior.
2. Finish current TLSVnc diagnostics/request-state work.
3. Add explicit transport status.
4. Prepare provider-side capabilities independently.
5. Add cross-app contracts without secrets or arbitrary commands.
6. Add iPad1VNC delegation with fallback.
7. Validate each path on physical iPad 1.
8. Remove duplicated terminal/transfer code only after provider paths are repeatedly proven.

## Roadmap changes caused by this audit

Removed from iPad1VNC product roadmap:
- transfer queue UX expansion;
- pause/resume product polish;
- terminal feature expansion;
- local-file-management expansion;
- document preview;
- ZIP/archive behavior.

Retained or promoted in iPad1VNC roadmap:
- TLSVnc/X509Vnc correctness;
- Direct/TLS/SSH transport indicator;
- VNC Quick Keys;
- transport-aware profiles;
- adaptive VNC quality;
- connection health/diagnostics;
- lightweight suite launch actions;
- Remote Files simplification.

## Non-regression rule

Architecture cleanup must not break the known-good VNC path. A duplicate subsystem is removed only after the replacement provider has been physically validated on iPad 1.
