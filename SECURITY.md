# Security

teams-unfloat runs with the **Accessibility** permission, which lets it read every window's title and control windows. A flaw in it could expose what is on screen, so reports are welcome.

## Reporting a vulnerability

Report it privately through GitHub: [**Report a vulnerability**](https://github.com/np25071984/teams-unfloat/security/advisories/new). Please do not open a public issue.

Include the teams-unfloat version (`teams-unfloat version`), the macOS version, and the steps to reproduce. You should get an answer within a week.

## Supported versions

Only the latest release gets fixes.

## Verifying a release

Releases are signed with teams-unfloat's own certificate. `install.sh` refuses a binary unless its checksum matches and its designated requirement is exactly the one written in `install.sh`. To check a binary yourself: `codesign -d -r- ~/.local/bin/teams-unfloat`.

## What teams-unfloat touches

- **Reads:** the titles, positions and minimized state of Microsoft Teams' windows (Accessibility), and the on-screen window list.
- **Changes:** one thing, the minimized state of Teams' floating meeting window.
- **Writes:** its launchd file in `~/Library/LaunchAgents`, `~/Library/Logs/teams-unfloat.log`, and a control socket in the per-user temporary directory, readable by your user only.
- **Network:** none. Only `install.sh` downloads, from this repository's GitHub Releases.