import Foundation
import os

let version = "0.0.1"

extension CommandLine {
    /// This binary's absolute path, symlinks resolved: what launchd must run,
    /// and what macOS ties the Accessibility permission to [F7].
    static var executable: String {
        var size: UInt32 = 0
        _NSGetExecutablePath(nil, &size)
        var buffer = [CChar](repeating: 0, count: Int(size))
        guard _NSGetExecutablePath(&buffer, &size) == 0 else { return arguments[0] }
        var resolved = [CChar](repeating: 0, count: Int(PATH_MAX))
        return realpath(buffer, &resolved) != nil ? String(cString: resolved) : String(cString: buffer)
    }
}

// Everything goes to the unified log, at notice level or above so that
// `log stream` shows it without flags [F12]; `teams-unfloat logs` follows it.
enum Log {
    static let subsystem = "io.github.np25071984.teams-unfloat"
    private static let logger = Logger(subsystem: subsystem, category: "teams-unfloat")

    static func info(_ message: String) {
        logger.notice("\(message, privacy: .public)")
    }

    static func warn(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }
}
