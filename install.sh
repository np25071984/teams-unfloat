#!/bin/sh
# Installs or upgrades teams-unfloat from its latest GitHub release.
#
#   curl -fsSL https://raw.githubusercontent.com/np25071984/teams-unfloat/main/install.sh | sh
#
# Downloads the release, checks its checksum and signature, installs the
# binary to ~/.local/bin/teams-unfloat and starts (or restarts) the service.
# Running it again upgrades. Nothing else on the system is touched.
#
#   TEAMS_UNFLOAT_VERSION=v0.0.1   install that release instead of the latest
#   TEAMS_UNFLOAT_PREFIX=/opt/x    install to /opt/x/bin/teams-unfloat instead of ~/.local/bin
#
# Keep the prefix the same between upgrades: macOS ties the Accessibility
# permission to the binary's path, so a new path needs the permission again.
set -eu

repo="np25071984/teams-unfloat"
asset="teams-unfloat-macos.tar.gz"
prefix="${TEAMS_UNFLOAT_PREFIX:-$HOME/.local}"
target="$prefix/bin/teams-unfloat"

# Only releases signed with teams-unfloat's release certificate are installed.
# Set once the certificate exists; see "Release certificate" in IMPLEMENTATION.md.
release_signature='identifier "teams-unfloat" and certificate leaf = H"96a3c4436ab5214fb81368c710dc42215dfdfa99"'

fail() { echo "teams-unfloat install: $*" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || fail "teams-unfloat runs on macOS only"
command -v curl >/dev/null || fail "curl is required"

if [ -n "${TEAMS_UNFLOAT_VERSION:-}" ]; then
  url="https://github.com/$repo/releases/download/$TEAMS_UNFLOAT_VERSION/$asset"
else
  url="https://github.com/$repo/releases/latest/download/$asset"
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT INT TERM

echo "downloading $url"
curl -fsSL -o "$work/$asset" "$url" || fail "download failed"
curl -fsSL -o "$work/$asset.sha256" "$url.sha256" || fail "checksum download failed"
(cd "$work" && shasum -a 256 -c "$asset.sha256" >/dev/null 2>&1) || fail "checksum does not match"

tar -xzf "$work/$asset" -C "$work" teams-unfloat || fail "unexpected archive contents"
codesign --verify --strict "$work/teams-unfloat" 2>/dev/null || fail "the binary's signature is invalid"
signature="$(codesign -d -r- "$work/teams-unfloat" 2>&1 | sed -n 's/^designated => //p')"
[ "$signature" = "$release_signature" ] || fail "the binary is not signed by teams-unfloat's release certificate"

mkdir -p "$prefix/bin"
# Replaced by rename, never rewritten in place: a signed binary rewritten in
# place while it runs can be killed.
cp "$work/teams-unfloat" "$target.new"
chmod 755 "$target.new"
mv -f "$target.new" "$target"
echo "installed $target ($("$target" version))"

"$target" restart

case ":$PATH:" in
  *":$prefix/bin:"*) ;;
  *) echo
     echo "note: $prefix/bin is not on your PATH. Add it, or call $target directly." ;;
esac
