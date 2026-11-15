// `teams-unfloat run`: the service itself, as launchd runs it.
//
// No Dock icon, no menu bar, no windows. SIGTERM and SIGINT quit.
//
// Accessibility: macOS gives the permission to whatever process launched the
// service. Started by launchd, that is this binary, identified by its path and
// signature [F6, F7]. Without the permission nothing works, so the service
// asks once, which adds it to the list in System Settings, then checks every
// few seconds and starts the moment it is allowed.

import AppKit

final class Daemon {
    private let unfloater = Unfloater()
    private var running = false
    private var permissionTimer: Timer?
    private var signals: [DispatchSourceSignal] = []
    private let launched = Date()

    /// No notification says the permission was granted, so it is polled; 5
    /// seconds is soon enough after flipping the switch, and rare enough to cost
    /// nothing.
    static let permissionInterval: TimeInterval = 5

    func run() -> Never {
        if Control.request("ping", timeout: 1) != nil {
            fputs("teams-unfloat: already running (\(Control.path))\n", stderr)
            exit(1)
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)

        guard Control.serve({ [weak self] in self?.answer($0) ?? "" }) else {
            fputs("teams-unfloat: cannot open the control socket at \(Control.path)\n", stderr)
            exit(1)
        }
        handleSignals()
        Log.info("teams-unfloat \(version) started, pid \(getpid())")

        if AXIsProcessTrusted() {
            start()
        } else {
            Log.warn("no Accessibility permission yet; checking every \(Int(Self.permissionInterval))s")
            // Adds teams-unfloat to the list in System Settings, so there is a switch to flip.
            _ = AXIsProcessTrustedWithOptions(
                [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
            waitForPermission()
        }

        app.run()
        exit(0)
    }

    private func start() {
        guard !running else { return }
        running = true
        permissionTimer?.invalidate()
        permissionTimer = nil
        unfloater.start()
        Log.info("watching for Teams' floating meeting window")
    }

    private func waitForPermission() {
        guard permissionTimer == nil else { return }
        permissionTimer = Timer.scheduledTimer(
            withTimeInterval: Self.permissionInterval, repeats: true
        ) { [weak self] _ in
            guard AXIsProcessTrusted() else { return }
            Log.info("Accessibility permission granted")
            self?.start()
        }
    }

    private func handleSignals() {
        for (sig, name) in [(SIGTERM, "SIGTERM"), (SIGINT, "SIGINT")] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler {
                Log.info("\(name): quitting")
                Control.removeSocket()
                exit(0)
            }
            source.resume()
            signals.append(source)
        }
    }

    // MARK: Control socket

    /// Called on the socket's thread; everything else runs on the main thread.
    private func answer(_ command: String) -> String {
        switch command {
        case "ping": return "pong\n"
        case "status": return DispatchQueue.main.sync { status() }
        default: return "unknown command: \(command)\n"
        }
    }

    private func status() -> String {
        let up = Int(Date().timeIntervalSince(launched))
        let teams = unfloater.teamsPID.map { "running, pid \($0)" } ?? "not running"
        return [
            "version:         \(version)",
            "pid:             \(getpid())",
            "uptime:          \(Self.duration(up))",
            "binary:          \(CommandLine.executable)",
            "accessibility:   \(AXIsProcessTrusted() ? "allowed" : "NOT ALLOWED (System Settings → Privacy & Security → Accessibility)")",
            "teams:           \(teams)",
            "floating window: \(running ? unfloater.floatingState : "waiting for Accessibility permission")",
            "minimized:       \(unfloater.minimizedCount) since start",
        ].joined(separator: "\n") + "\n"
    }

    static func duration(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m \(seconds % 60)s" }
        if seconds < 86400 { return "\(seconds / 3600)h \(seconds % 3600 / 60)m" }
        return "\(seconds / 86400)d \(seconds % 86400 / 3600)h"
    }
}
