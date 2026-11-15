# teams-unfloat

Minimizes Microsoft Teams' floating meeting window on macOS, run as a launchd service. One Swift package, no dependencies.

```bash
swift test                          # the decision logic
./build.sh                          # release build, signed, into build/teams-unfloat
./build.sh --install                # install to ~/.local/bin and restart the service
teams-unfloat status | logs         # the running service
```

## Where things are written down

Each fact lives in one place. Do not repeat it in another. `CLAUDE.md` only imports this file; edit this one.

| What | Where |
|---|---|
| Decision logic: what is the floating window, when and how to minimize it, the restored-window rule, the launchd file | a test in `Tests/TeamsUnfloatTests`, named after the rule and its reason |
| What macOS and Teams do, and how the code is wired to them | `IMPLEMENTATION.md` |
| How to use teams-unfloat | `README.md` |
| What changed in a release | `CHANGELOG.md` |
| The project page, np25071984.github.io/teams-unfloat | `docs/index.html`: a short pitch that links to `README.md` for details. Its "What Teams gets wrong" is the README's, copied: change both together |

## Rules

- **A behaviour change comes with a test.** Keep decision logic in the pure types (`Rules`, `Keeper`, the static functions on `Service`), not in `Unfloater`, which calls macOS, so it can be tested without a desktop. A new rule gets a test whose name states the rule and why.
- **`IMPLEMENTATION.md` changes only for platform facts and wiring.** Do not copy into it what a test specifies; point to the test file. A newly found macOS or Teams behaviour becomes a numbered fact labelled *observed*, *documented* or *believed*, and the code that depends on it cites it as **[Fn]**. Relabel a fact when it is confirmed or disproved.
- **Constants are named.** A number in the code that matters gets a `static let` with a comment on why it has that value, on the type that owns it.
- **No history in the docs.** No "used to", earlier designs or release numbers outside `CHANGELOG.md`.
- **Signing.** The binary is signed with the plain identifier `teams-unfloat` and carries no `Info.plist`; anything else breaks the Accessibility permission (`IMPLEMENTATION.md`, F8). Search certificates without `find-identity -v` (F9). Install by rename, never in place (F10).
- **Check on the real desktop** what tests cannot: after a change to how windows are found or minimized, `./build.sh --install` and try it in a Teams call, or ask the user to.

## Releasing

Bump `version` in `Sources/TeamsUnfloat/Support.swift`, add a dated entry to `CHANGELOG.md`, and say what an upgrading user has to do if anything.

Once the release PR is merged, tag its merge commit and push the tag. Check the commit first:

```bash
git tag -a vX.Y.Z <merge commit> -m "teams-unfloat X.Y.Z: <one line>"
git push origin vX.Y.Z
```

The tag runs `.github/workflows/release.yml`, which builds, signs and publishes the release that `install.sh` installs. It fails, publishing nothing, if `version` does not match the tag or `CHANGELOG.md` has no entry for it. Signing needs the `release` environment's secrets, `TEAMS_UNFLOAT_RELEASE_P12` and `TEAMS_UNFLOAT_RELEASE_P12_PASSWORD`; never put that certificate anywhere else.

Then update `Formula/teams-unfloat.rb` in a PR: `url` and `version` to the new tag, `sha256` to the one in the release's `teams-unfloat-macos.tar.gz.sha256`. Homebrew users get the release only once that is merged.