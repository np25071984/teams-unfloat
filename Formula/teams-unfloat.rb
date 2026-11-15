class TeamsUnfloat < Formula
  desc "Minimizes Microsoft Teams' floating meeting window on macOS"
  homepage "https://github.com/np25071984/teams-unfloat"
  url "https://github.com/np25071984/teams-unfloat/releases/download/v0.0.1/teams-unfloat-macos.tar.gz"
  version "0.0.1"
  sha256 "76272f069873f3251b2dcc030dbdd9dc44340af5aaa3a0a993f195c36cf754e3"
  license "MIT"

  depends_on :macos

  # A prebuilt release, not a source build: macOS ties teams-unfloat's
  # Accessibility permission to its signature, and only the release build
  # carries the release certificate's. Homebrew building it would sign it ad hoc.
  def install
    bin.install "teams-unfloat"
  end

  # The permission is also tied to the binary's path, and the Cellar path
  # changes with every version. The service runs a copy at a path that does
  # not, so upgrades keep the permission. The old copy is replaced, never
  # rewritten in place.
  post_install_steps do
    copy "bin/teams-unfloat", "teams-unfloat/teams-unfloat.new", target_base: :var
    move "teams-unfloat/teams-unfloat.new", "teams-unfloat/teams-unfloat", source_base: :var, target_base: :var
  end

  service do
    run [var/"teams-unfloat/teams-unfloat", "run"]
    keep_alive successful_exit: false
    process_type :interactive
    log_path var/"log/teams-unfloat.log"
    error_log_path var/"log/teams-unfloat.log"
  end

  def caveats
    <<~EOS
      Start teams-unfloat now and at every login:
        brew services start teams-unfloat

      Then turn on "teams-unfloat" in System Settings > Privacy & Security >
      Accessibility. If it is not listed, add this file with +:
        #{var}/teams-unfloat/teams-unfloat

      After `brew upgrade teams-unfloat`, restart it on the new version:
        brew services restart teams-unfloat

      If you installed teams-unfloat with install.sh before, remove that copy first:
        ~/.local/bin/teams-unfloat uninstall

      To remove teams-unfloat completely:
        brew services stop teams-unfloat && brew uninstall teams-unfloat && rm -rf #{var}/teams-unfloat
    EOS
  end

  test do
    assert_equal "teams-unfloat #{version}", shell_output("#{bin}/teams-unfloat version").strip
  end
end
