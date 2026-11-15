// The launchd side: the agent's file and reading launchctl's answer.

import Testing
@testable import teams_unfloat

@Suite("Service")
struct ServiceTests {
    @Test("the agent runs this binary's `run`, at login, restarted after a crash but not after a clean exit")
    func agent() {
        let agent = Service.agent(binary: "/Users/me/.local/bin/teams-unfloat")
        #expect(agent["Label"] as? String == "io.github.np25071984.teams-unfloat")
        #expect(agent["ProgramArguments"] as? [String] == ["/Users/me/.local/bin/teams-unfloat", "run"])
        #expect(agent["RunAtLoad"] as? Bool == true)
        #expect(agent["KeepAlive"] as? [String: Bool] == ["SuccessfulExit": false])
        #expect(agent["ProcessType"] as? String == "Interactive")
        #expect(agent["LimitLoadToSessionType"] as? String == "Aqua")
    }

    @Test("launchctl print: pid and last exit code from the service's own lines, not nested blocks")
    func parseRunning() {
        let output = """
            gui/501/io.github.np25071984.teams-unfloat = {
            \tactive count = 1
            \tpath = /Users/me/Library/LaunchAgents/io.github.np25071984.teams-unfloat.plist
            \tstate = running
            \tpid = 4242
            \tlast exit code = (never exited)
            \tendpoints = {
            \t\tpid = 1
            \t}
            }
            """
        let state = Service.parseState(output)
        #expect(state.loaded)
        #expect(state.pid == 4242)
        #expect(state.lastExit == "(never exited)")
    }

    @Test("loaded but not running: no pid")
    func parseStopped() {
        let state = Service.parseState("x = {\n\tstate = not running\n\tlast exit code = 1\n}")
        #expect(state.loaded)
        #expect(state.pid == nil)
        #expect(state.lastExit == "1")
    }
}

@Suite("Homebrew")
struct HomebrewTests {
    @Test("a binary in the Cellar, or the service's copy in var/teams-unfloat, belongs to Homebrew", arguments: [
        "/opt/homebrew/Cellar/teams-unfloat/1.0.0/bin/teams-unfloat",
        "/usr/local/Cellar/teams-unfloat/1.0.0/bin/teams-unfloat",
        "/opt/homebrew/var/teams-unfloat/teams-unfloat",
    ])
    func homebrewPaths(path: String) {
        #expect(Service.isHomebrewPath(path))
    }

    @Test("anywhere else, teams-unfloat runs its own agent", arguments: [
        "/Users/me/.local/bin/teams-unfloat",
        "/opt/teams-unfloat/bin/teams-unfloat",
        "/opt/homebrew/Cellar/other/1.0/bin/teams-unfloat",
    ])
    func otherPaths(path: String) {
        #expect(!Service.isHomebrewPath(path))
    }

    @Test("both the current and the older brew services label are recognised")
    func labels() {
        #expect(Service.brewLabels == ["sh.brew.teams-unfloat", "homebrew.mxcl.teams-unfloat"])
    }
}

@Suite("Status output")
struct DurationTests {
    @Test("durations", arguments: [
        (5, "5s"), (65, "1m 5s"), (3_725, "1h 2m"), (90_061, "1d 1h"),
    ])
    func duration(seconds: Int, text: String) {
        #expect(Daemon.duration(seconds) == text)
    }
}
