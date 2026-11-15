# Implementation

What teams-unfloat must do, the macOS and Teams behaviour that dictates how, and how the code is wired to it. Every rule that looks arbitrary exists because of a platform fact in [Platform facts](#platform-facts); the code cites it as **[Fn]**.

[README.md](README.md) covers using teams-unfloat. The decision logic is specified by tests rather than prose: what gets minimized and when, how, the restored-window rule and the launchd file. Where a section says **Specified by** a test file, the test names state each rule and its reason, and `swift test` checks them. This document keeps what tests cannot reach: what macOS and Teams do, and how the pieces are wired to them.

## Required behaviour

- When Teams shows its floating meeting window and Teams is not the active app, minimize it.
- A floating window you restore from the Dock stays, until you are back at Teams (it is the active app, with a window other than the floating one focused) or minimize it yourself. Then the next floating window is minimized again.
- Minimize it without the minimize animation where possible.
- Never touch any other window, and never quit Teams. Teams is hidden only for the tenth of a second a quiet minimize takes.
- Cost nothing noticeable: no work at all between events, and no timer that runs on its own.

## Platform facts

Each is labelled *observed*, *documented* or *believed*. Relabel a fact when it is confirmed or disproved.

### Teams

- **F1.** Teams for macOS has the bundle ID `com.microsoft.teams2`. When the meeting window goes out of view (another Space, another app in front), Teams shows a floating window titled `Meeting compact view | <meeting title>`, with the Accessibility subrole `AXSystemDialog`, at window level 19 (normal windows are at 0), on every Space at once. Teams has no setting to turn it off. *(observed on Teams with Edge WebView 156; the setting's absence: documented by Microsoft's message center item MC1266027, which announces the window and no opt-out)*
- **F2.** Teams creates a new floating window each time the meeting window goes out of view. Accessibility posts `AXWindowCreated` for it with the title already set, within about a millisecond. *(observed)*
- **F3.** Teams keeps the floating window after the meeting window is back in view and takes it off screen itself. Accessibility still lists it, not minimized, so only the window server's on-screen list (`CGWindowListCopyWindowInfo` with `optionOnScreenOnly`) says whether it is showing. Window titles from that list need Screen Recording permission, so the floating window is matched by its frame against Accessibility's. *(observed; the titles: documented)*
- **F4.** The floating window exposes a close button through Accessibility, but pressing it does nothing. *(observed)*
- **F5.** Setting `kAXMinimizedAttribute` minimizes the floating window to the Dock, with the minimize animation, which System Settings offers as Genie or Scale and never off. Restoring it from the Dock posts `AXWindowDeminiaturized`. *(observed)*

### Permission, signing, launchd

- **F6.** The Accessibility permission belongs to the *responsible* process. Started by launchd, that is the binary itself. Started from a shell, it is the terminal app, whatever binary runs. *(observed)*
- **F7.** An unbundled binary's permission is keyed to its **path** and its code signature's designated requirement. Same path, same certificate: the permission survives rebuilds. Another path, or an ad-hoc signature (which changes with every build): it must be granted again. *(observed)*
- **F8.** If the binary has a reverse-DNS signing identifier, or an `Info.plist`, tccd files the permission under a **bundle ID**, then fails to find an app with that ID and denies. The entry shows in System Settings with a folder icon; turning it on does nothing. *(observed in scope, by the same author)*
- **F9.** An untrusted self-signed code-signing certificate works for `codesign` and gives a stable designated requirement. `security find-identity -v` hides untrusted certificates; without `-v` it lists them. *(observed)*
- **F10.** Overwriting a signed binary in place while it runs is widely reported to get the process killed, because the kernel caches the old signature. Replacing the file by rename gives the new binary a new inode and cannot hit this. *(believed)*
- **F11.** launchd agents do not inherit the shell's environment, and `$TMPDIR` can differ between them. *(documented)* `confstr(_CS_DARWIN_USER_TEMP_DIR)` gives the same directory to both. *(observed)*
- **F12.** `log stream` shows `notice` and above by default; `info` and `debug` messages are hidden. *(documented)*
- **F13.** An Accessibility entry for a path stays switched on when a binary signed with another certificate replaces the one at that path, but does not apply to it: `AXIsProcessTrusted` stays false until the entry is removed with **−** and the binary added again. `tccutil reset Accessibility` takes only bundle IDs, so it cannot remove a bare binary's entry. *(observed)*
- **F14.** `launchctl bootstrap` straight after `bootout` of the same label can fail transiently with an I/O error. *(believed)*

### Homebrew

- **F15.** Homebrew installs each version of a formula into its own Cellar directory, so the binary's real path changes with every upgrade. `var` is shared by all versions. *(observed)*
- **F16.** Homebrew 7 labels a formula's service `sh.brew.<name>`; services started by older versions keep `homebrew.mxcl.<name>`. `brew services stop` removes the agent's file. `brew upgrade` does not restart a running service. *(observed)*
- **F17.** A formula that installs a prebuilt, signed binary with `bin.install` leaves it byte for byte as released, signature intact. *(observed)*
- **F18.** Homebrew 7 refuses to load a formula from a third-party tap until the user runs `brew trust <tap>`. *(observed)*

### Windows that cannot be hidden another way

- **F19.** macOS keeps part of a window on screen when it is moved past an edge: about 40 points of a 465-point-wide window at the left or right, about 32 points at the bottom, and none above the menu bar. Teams' floating window ignores a size change. *(observed)*
- **F20.** Hiding Teams (as ⌘H does) is instant, with no animation, but hides every Teams window, the meeting window included. Unhidden, Teams draws the floating window before the meeting window. *(observed)*
- **F21.** When `AXWindowCreated` arrives for the floating window, the meeting window can still be on screen while a Space switch animates, so the window server's list is not yet final; it is a fraction of a second later. *(believed)*
- **F22.** A window of a hidden app minimized through Accessibility goes to the Dock with no animation, and stays minimized when the app is shown again; the app's other windows come back. Hide, minimize and unhide, 50ms apart, took about 100ms. *(observed on a TextEdit window in a screen recording, and on Teams' floating window by eye)*
- **F23.** Hiding the active app makes another app active, and showing it again does not make it active. *(observed)*
- **F24.** A window covered by another app's window is still in the window server's on-screen list. So with another app in front of the meeting window on the same Space, the meeting window counts as on screen while Teams shows the floating window over the other app. *(observed, in a phone video of the floating window over Slack)*
- **F25.** Screen recordings and screenshots do not capture Teams' floating window, so it can only be checked by eye or with a camera. *(observed)*

## Non-goals and known gaps

- **Animation in two cases.** When you have hidden Teams yourself, or within 2 seconds of the last quiet minimize, the window is minimized with the animation **[F5]**. Other ways to remove the window fail: moving it off screen leaves part of it showing **[F19]**, closing it does nothing **[F4]**, and making another app's window transparent or moving it between Spaces needs System Integrity Protection partly off.
- **Other languages.** The floating window is found by its English title **[F1]**. Teams in another language titles it differently, and teams-unfloat leaves it alone.
- **Classic Teams** (`com.microsoft.teams`) is not watched.
- **Several displays** have not been tried.

## Architecture

| Type | File | Job |
|---|---|---|
| `Rules`, `Keeper` | `Rules.swift` | The decisions: what is the floating window, whether to minimize it and whether quietly, the restored-window rule. Pure, tested |
| `Unfloater` | `Unfloater.swift` | Asks Accessibility and the window server, and acts on `Rules` |
| `Daemon` | `Daemon.swift` | `teams-unfloat run`: permission, signals, the control socket's answers |
| `Service` | `Service.swift` | launchd and `brew services`: start, stop, restart, status, uninstall |
| `Control` | `Control.swift` | The control socket |
| `main` | `main.swift` | The command line |

Everything runs on the main thread except the control socket's, which hands each request to the main thread.

## Unfloater

- Events, and nothing else, start work: an `AXObserver` on Teams for `AXWindowCreated` and `AXFocusedWindowChanged`; on each floating window `AXTitleChanged`, `AXWindowMiniaturized` and `AXWindowDeminiaturized` **[F2, F5]**; and `NSWorkspace` notifications for another Space, another active app, and an app launching or quitting.
- Each event runs a check at once and again 0.3s and 1s later, replacing the checks of the event before **[F21]**. A check minimizes a floating window that is on screen **[F3]**; a new floating window is minimized at once **[F2]**.
- Minimizing is quiet when `Rules` allows it: hide Teams, set `kAXMinimizedAttribute` 50ms later, unhide 50ms after that **[F22]**. Checks are skipped in between, when Teams' windows are hidden by teams-unfloat, not by you. Otherwise the window is minimized with the animation **[F5]**. Nothing is minimized while Teams is active, so hiding it never takes your focus **[F23]**.
- "At Teams" means Teams is the active app, not that a Teams window is on screen **[F24]**.
- `AXWindowDeminiaturized` on a floating window keeps it; `AXWindowMiniaturized` on the kept window, or Teams being active with another window focused, ends the keep **[F5]**.

**Specified by** `Tests/TeamsUnfloatTests/RulesTests.swift`.

## Service

### `teams-unfloat run` (Daemon)

1. If the control socket answers `ping`, another instance runs: exit 1.
2. `NSApplication.shared` with activation policy `.prohibited`: no Dock icon, no menu bar.
3. Open the control socket and install signal handlers: `SIGTERM` and `SIGINT` remove the socket and exit 0, so launchd does not restart it.
4. If `AXIsProcessTrusted()`: start. Otherwise call `AXIsProcessTrustedWithOptions` with the prompt once, which adds the binary to the list in System Settings, and poll every 5 seconds **[F6]**.
5. `NSApp.run()`.

### Control socket

`confstr(_CS_DARWIN_USER_TEMP_DIR)` + `teams-unfloat.sock`, mode 0600 **[F11]**. One request per connection: the client writes a command and a newline, reads text to EOF. `ping` answers `pong`; `status` answers version, pid, uptime, binary path, permission, Teams' pid, the floating window's state and how many were minimized. Commands run from a shell go through the socket because they have the terminal's permission, not the service's **[F6]**.

### launchd

Label `io.github.np25071984.teams-unfloat`, file `~/Library/LaunchAgents/<label>.plist`, domain `gui/<uid>`. The file's contents are **specified by** `Tests/TeamsUnfloatTests/ServiceTests.swift`: this binary's real path **[F7]** with `run`, start at login, restart after a crash but not a clean exit, interactive, GUI sessions only. Output outside the unified log goes to `~/Library/Logs/teams-unfloat.log`.

- **start**: write the file if its contents differ; bootstrap, or bootout and bootstrap if it changed, or kickstart if loaded and not running. Then wait for the socket; if the permission is missing, say so and open the Accessibility pane.
- **stop**: `bootout`, then remove the file, so it stays off at the next login until `start` writes it again.
- **restart**: as start if not loaded or changed, else `kickstart -k`.
- `bootstrap` is retried every 200ms for up to 3s **[F14]**.
- **uninstall**: bootout, remove the plist, the log and the binary.

`brew services` owns the service when its agent file exists (`sh.brew.teams-unfloat`, or `homebrew.mxcl.teams-unfloat` **[F16]**), or when the binary is Homebrew's: in a Cellar, or the service's copy in `var/teams-unfloat` (**specified by** `ServiceTests.swift`). Start, stop and restart then run `brew services <cmd> teams-unfloat`.

The formula, `Formula/teams-unfloat.rb` in this repository, installs the signed release rather than building from source, which would sign ad hoc **[F7, F17]**. Its post-install steps copy the binary to `var/teams-unfloat/teams-unfloat` by rename **[F10]**, and its service runs that copy: a path that stays the same across versions **[F15]**, so `brew upgrade` keeps the permission. Users trust the tap before installing **[F18]**.

### Logging

Unified log, subsystem `io.github.np25071984.teams-unfloat`, at `notice` **[F12]**: start, permission, each minimize and each change to the kept window.

### Build, sign, install

- `swift build -c release`, executable `teams-unfloat`, macOS 13+. Releases are universal.
- Sign with `--identifier teams-unfloat`: plain, no `Info.plist` **[F8]**. The identity is `$TEAMS_UNFLOAT_SIGN_IDENTITY`, else the first *Developer ID Application*, *Apple Development* or *Teams Unfloat Dev* certificate (`find-identity` without `-v` **[F9]**), else ad hoc with a warning **[F7]**.
- Releases: a pushed `v*` tag runs `.github/workflows/release.yml`, which checks the tag against `version`, runs the tests, imports the release certificate into a temporary keychain, builds universal, checks the designated requirement, and publishes `teams-unfloat-macos.tar.gz` with its SHA-256 and the version's `CHANGELOG.md` entry.
- `install.sh` downloads the archive and checksum, verifies the checksum, the signature and the exact designated requirement, installs by rename **[F10]** to `~/.local/bin/teams-unfloat`, and runs `teams-unfloat restart`.

### Release certificate

Releases are signed with a self-signed code-signing certificate named **teams-unfloat release**. Its key lives only in the GitHub `release` environment's secrets, `TEAMS_UNFLOAT_RELEASE_P12` (the exported `.p12`, base64) and `TEAMS_UNFLOAT_RELEASE_P12_PASSWORD`. The designated requirement it gives, `identifier "teams-unfloat" and certificate leaf = H"96a3c4436ab5214fb81368c710dc42215dfdfa99"`, is written in `install.sh` and `release.yml`, which refuse anything else. Losing the key means a new certificate, and every user granting the permission again **[F7]**.

## Constants

Named on the type that owns them, with the reason:

| Constant | Value | Where |
|---|---|---|
| Checks after an event | 0.3s, 1s | `Rules.settleDelays` **[F21]** |
| Steps of a quiet minimize | 50ms | `Rules.hideSettle` **[F22]** |
| No second quiet minimize within | 2s | `Rules.quietRepeatGuard` **[F20]** |
| Frame tolerance | 1pt | `Rules.frameTolerance` |
| Permission poll | 5s | `Daemon.permissionInterval` |
| Bootstrap retry | 200ms × 15 | `Service.bootstrap` **[F14]** |

## Verification

A change is done when `swift test` passes and these do, on a real desktop during a Teams call:

- [ ] Leaving the meeting's Space minimizes the floating window, once, with no animation and no flicker of other windows. Check by eye: recordings do not show the floating window **[F25]**.
- [ ] Putting another app in front of the meeting window, on the same Space, does the same.
- [ ] Going back to the meeting's Space leaves the meeting window alone.
- [ ] Restoring the floating window from the Dock keeps it while you move between other Spaces.
- [ ] After going back to Teams, leaving it again minimizes the floating window.
- [ ] Minimizing a kept window yourself, then leaving the meeting window again, minimizes the next one.
- [ ] `teams-unfloat status` shows the floating window's state and the count.
- [ ] Outside calls, and in a call while nothing changes, `top -pid <pid> -stats cpu,idlew` shows about 0% CPU and no idle wakeups.
- [ ] After `teams-unfloat stop` and logging out and in, the service is not running.