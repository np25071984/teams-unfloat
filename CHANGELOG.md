# Changelog

## 0.0.1 — 2026-11-14

First release. teams-unfloat minimizes Microsoft Teams' floating meeting window when it appears, without the minimize animation, whether you leave the meeting for another Space or another app. A floating window you restore from the Dock stays until you go back to the meeting window or minimize it yourself. It wakes only on events, never on a timer, and `teams-unfloat stop` keeps it off until `teams-unfloat start`. Install with `curl -fsSL https://raw.githubusercontent.com/np25071984/teams-unfloat/main/install.sh | sh`, or with Homebrew: `brew tap np25071984/teams-unfloat https://github.com/np25071984/teams-unfloat`, `brew trust np25071984/teams-unfloat`, `brew install teams-unfloat`, `brew services start teams-unfloat`.