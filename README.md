# teams-unfloat

Minimizes Microsoft Teams' floating meeting window on macOS, so it stops covering your work every time you leave the meeting.

## What Teams gets wrong

**The meeting follows you everywhere.** In a Teams call, switch to another Space or put another app in front, and Teams opens a small floating copy of the meeting over everything, on every Space. It sits on top of the window you went there to use, and Teams has no setting to turn it off.

## What this does

When the floating window appears, teams-unfloat minimizes it to the Dock, without the minimize animation. Your call goes on, and the meeting window stays where you left it.

- **Want it back?** Click it in the Dock. teams-unfloat leaves a window you restored alone until you go back to the meeting window or minimize it yourself.
- **Back at the meeting**, nothing is touched: Teams takes the floating window away itself.
- **Nothing else changes.** Only that one window is minimized, and Teams is never quit.

To skip the animation, teams-unfloat hides Teams for about a tenth of a second, minimizes the window while it is hidden, and shows Teams again. Teams is never the app you are using at that moment, so this takes no focus away. If you have hidden Teams yourself, the window is minimized the ordinary way, with the animation; see [IMPLEMENTATION.md](IMPLEMENTATION.md#non-goals-and-known-gaps).

## Is it for you?

teams-unfloat is a small open-source background service, with no app, Dock icon or menu bar. It works with the current Teams for macOS in English, and needs one permission, Accessibility.

It may not be what you want if you'd rather keep the floating window and just move it out of the way: Teams lets you drag it anywhere, and that's enough for some people.

## Install

Needs macOS 13 or later, on Apple Silicon or Intel. In Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/np25071984/teams-unfloat/main/install.sh | sh
```

This downloads the latest release, checks its checksum and signature, installs `~/.local/bin/teams-unfloat` and starts the service. From then on it starts at every login, and launchd restarts it if it crashes.

On first start, teams-unfloat asks for **Accessibility** permission and opens the right pane of System Settings. Turn on **teams-unfloat** there. If it is not listed, add `~/.local/bin/teams-unfloat` with **+** (⌘⇧G to type the path). The service checks every 5 seconds and starts by itself once allowed.

**Upgrade** by running the same command again. The service restarts on the new version and keeps its permission.

**Remove** it with `teams-unfloat uninstall`, which stops the service and removes the binary, its launchd file and its log. Remove **teams-unfloat** from the Accessibility list by hand.

To install a particular release, or somewhere other than `~/.local`, set `TEAMS_UNFLOAT_VERSION=v0.0.1` or `TEAMS_UNFLOAT_PREFIX=/opt/teams-unfloat` for `sh`, after the `|`. Keep the prefix the same from then on: macOS ties the permission to the binary's path.

Releases are signed with teams-unfloat's own self-signed certificate, not an Apple Developer ID, so they are not notarized. The installer is unaffected. A release archive downloaded with a browser is quarantined, and macOS refuses to run it until you clear that: `xattr -d com.apple.quarantine teams-unfloat`.

### With Homebrew

```bash
brew tap np25071984/teams-unfloat https://github.com/np25071984/teams-unfloat
brew trust np25071984/teams-unfloat
brew install teams-unfloat
brew services start teams-unfloat
```

Homebrew loads formulae from a tap only once you trust it, hence `brew trust`. Then turn on **teams-unfloat** in Accessibility; if it is not listed, add `$(brew --prefix)/var/teams-unfloat/teams-unfloat`, which is the copy the service runs. Upgrade with `brew upgrade teams-unfloat && brew services restart teams-unfloat`; the permission is kept. Remove with `brew services stop teams-unfloat && brew uninstall teams-unfloat && rm -rf $(brew --prefix)/var/teams-unfloat`.

Use either Homebrew or the installer, not both. To switch from the installer, run `teams-unfloat uninstall` first.

### Building from source

Needs the Xcode command line tools.

```bash
./build.sh                  # build and sign build/teams-unfloat
./build.sh --install        # also install ~/.local/bin/teams-unfloat and restart the service
./build.sh --universal      # Apple Silicon and Intel in one binary, as releases are
swift test                  # the decision logic
```

macOS ties the Accessibility permission to the binary's **path and signature**. Rebuilt and installed to the same path with the same certificate, teams-unfloat keeps it. Signed ad hoc, or swapped between a local build and a release, it needs granting again: remove the old entry with **−** and add the binary with **+**.

`build.sh` signs with `$TEAMS_UNFLOAT_SIGN_IDENTITY`, else the first *Developer ID Application*, *Apple Development* or *Teams Unfloat Dev* certificate in your keychain, else ad hoc. For local builds, create a self-signed certificate once: Keychain Access → Certificate Assistant → Create a Certificate…, name **Teams Unfloat Dev**, type **Code Signing**. It does not need to be marked as trusted.

## Commands

| Command | |
|---|---|
| `teams-unfloat start` | start the service, writing its launchd file if it is missing or points at another binary |
| `teams-unfloat stop` | stop it; it stays off, logins included, until `teams-unfloat start` |
| `teams-unfloat restart` | restart it |
| `teams-unfloat status` | launchd state, pid, permission, whether Teams is running, the floating window's state and how many were minimized. Exits 0 when running, 3 when not, 4 without permission |
| `teams-unfloat logs` | follow the service's log; `teams-unfloat logs --last 1h` shows the past hour |
| `teams-unfloat run` | the service in the foreground; what launchd runs |
| `teams-unfloat uninstall` | stop the service and remove teams-unfloat |
| `teams-unfloat version` | |

`status` asks the running service through a socket in the per-user temporary directory: run from a shell, a command gets the terminal's Accessibility permission, not the service's.

Installed with Homebrew, the service belongs to `brew services` (label `sh.brew.teams-unfloat`), and `start`, `stop` and `restart` hand over to it.

## Cost

About 8 MB of memory. It runs no timers of its own: it wakes only when something happens, such as Teams opening a window or you switching Spaces or apps, and then looks for the floating window three times within a second. In Activity Monitor that shows as 0.0% CPU and an energy impact of 0.

## How it works

The macOS and Teams behaviour it relies on, and how the code is wired to it: [IMPLEMENTATION.md](IMPLEMENTATION.md). The decision logic is covered by tests: `swift test`.

## Changelog

[CHANGELOG.md](CHANGELOG.md).

## License

MIT — see [LICENSE](LICENSE).

Microsoft Teams is a trademark of Microsoft. teams-unfloat is not affiliated with or endorsed by Microsoft.