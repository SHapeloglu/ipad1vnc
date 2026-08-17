# NEW_CHAT.md

## Purpose

Use this file to start a fresh ChatGPT / Claude / coding-agent conversation without needing the old long conversation.

## Copy/paste prompt

```text
We are continuing the iPad1VNC project from GitHub repository SHapeloglu/ipad1vnc.

Before making any code changes, read these repository files in this order:
1. SESSION.md
2. TASKS.md
3. ARCHITECTURE.md
4. AGENTS.md
5. CLAUDE.md
6. BUILD.md
7. SERVER.md
8. TESTING.md
9. ROADMAP.md
10. CHANGELOG.md

Important project constraints:
- target is iPad 1 / iOS 5.1.1 / armv7 / jailbroken
- only ~256 MB RAM
- Theos legacy build, TARGET iphone:clang:6.1:5.1
- preserve RAW/Hextile/Tight fallback paths
- Tight already worked on the real iPad against TigerVNC
- do not use modern iOS APIs without legacy compatibility handling
- do not store VNC password or Files token in plaintext NSUserDefaults
- SSH Tunnel is the known-good secure path
- VeNCrypt/X509Vnc is experimental
- do not call a feature complete until it passes physical-device testing

Current source line is v2.2.0-beta3.

The immediate task is the first unchecked P0 item in TASKS.md. Do not redesign the project or restart from scratch. Continue from the repository state and update SESSION.md / TASKS.md / CHANGELOG.md after meaningful progress.

When giving shell instructions, clearly separate commands for WSL, the iPad, and the Ubuntu/Contabo server. Give exact standalone commands without copied shell prompts.
```

## Expected agent behavior

A new agent should **not ask the user to retell the project history** if these files are available.

The repository documentation is the source of truth for:
- current version
- known-good features
- pending runtime tests
- build environment
- server architecture
- legacy iOS constraints

If documentation and source conflict, inspect the source and update the documentation after establishing the actual state.
