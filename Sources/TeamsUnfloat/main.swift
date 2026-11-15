// teams-unfloat: minimizes Microsoft Teams' floating meeting window when it
// appears, run as a launchd service and controlled from the command line.

import AppKit

let usage = """
    usage: teams-unfloat <command>

      start          start the service (writes its launchd file if needed)
      stop           stop it, until `teams-unfloat start`, logins included
      restart        restart it
      status         is it running, does it have permission, what it sees
      logs [--last <time>]
                     follow the service's log, or show the last <time> (e.g. 1h)
      run            the service itself, in the foreground (what launchd runs)
      uninstall      stop the service and remove teams-unfloat
      version        print the version
    """

let args = Array(CommandLine.arguments.dropFirst())

func fail(_ message: String, _ code: Int32 = 1) -> Never {
    fputs("teams-unfloat: \(message)\n", stderr)
    exit(code)
}

switch args.first {
case "run":
    // run() never returns, so this constant keeps the daemon alive for the
    // closures that refer to it weakly.
    let daemon = Daemon()
    daemon.run()

case "start":
    let code = Service.start()
    guard code == 0 else { exit(code) }
    awaitService()

case "stop":
    exit(Service.stop())

case "restart":
    let code = Service.restart()
    guard code == 0 else { exit(code) }
    awaitService()

case "status":
    let label = Service.label
    let state = Service.state(label)
    let how = Service.isHomebrew ? "brew services" : "launchd"
    print("service:         \(label) (\(how), \(Service.plist(label)))")
    switch (state.loaded, state.pid) {
    case (true, let pid?): print("state:           running, pid \(pid)")
    case (true, nil): print("state:           loaded, not running (last exit \(state.lastExit ?? "?"))")
    default: print("state:           not loaded")
    }
    guard let answer = Control.request("status") else {
        print("\nThe service is not answering. Start it with `teams-unfloat start`; see `teams-unfloat logs`.")
        exit(3)
    }
    print(answer, terminator: "")
    exit(answer.contains("NOT ALLOWED") ? 4 : 0)

case "logs":
    var command = ["/usr/bin/log", "stream", "--style", "compact"]
    if args.count >= 3, args[1] == "--last" {
        command = ["/usr/bin/log", "show", "--style", "compact", "--last", args[2]]
    } else if args.count > 1 {
        fail("usage: teams-unfloat logs [--last <time>]", 2)
    }
    command += ["--predicate", "subsystem == \"\(Log.subsystem)\" AND process == \"teams-unfloat\""]
    let argv = command.map { strdup($0) } + [nil]
    execv(command[0], argv)
    fail("cannot run /usr/bin/log: \(String(cString: strerror(errno)))")

case "uninstall":
    exit(Service.uninstall())

case "version", "--version", "-v":
    print("teams-unfloat \(version)")

case nil, "help", "--help", "-h":
    print(usage)

default:
    fputs(usage + "\n", stderr)
    fail("unknown command `\(args[0])`", 2)
}

/// Waits for a just-started service to answer, then says what it still needs.
func awaitService() -> Never {
    // A restarted service needs a moment before the old one stops answering.
    usleep(300_000)
    for _ in 0..<30 {
        if let status = Control.request("status", timeout: 1) {
            if status.contains("NOT ALLOWED") {
                // The binary the service runs, which is what needs the
                // permission: under Homebrew, a copy, not this one.
                let binary = status.split(separator: "\n")
                    .first { $0.hasPrefix("binary:") }
                    .map { $0.dropFirst("binary:".count).trimmingCharacters(in: .whitespaces) }
                    ?? CommandLine.executable
                print("""

                    teams-unfloat needs Accessibility permission. In the window that opens, turn on \
                    "teams-unfloat" (or add \(binary) with +). It starts by itself \
                    within \(Int(Daemon.permissionInterval)) seconds of being allowed.
                    """)
                _ = Service.run("/usr/bin/open", [
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
                ])
            }
            exit(0)
        }
        usleep(100_000)
    }
    fail("started, but the service is not answering; see `teams-unfloat logs` and \(Service.logFile)")
}
