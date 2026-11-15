// What teams-unfloat decides, apart from the Accessibility and window-server
// calls that carry it out, so it can be tested without a desktop.

import CoreGraphics
import Foundation

enum Rules {
    /// Teams' floating meeting window is titled "Meeting compact view | <meeting>" [F1].
    static let floatingTitlePrefix = "Meeting compact view"

    /// Teams for macOS, the current app (not "classic" Teams) [F1].
    static let teamsBundleID = "com.microsoft.teams2"

    /// How far apart two frames may be and still be the same window: the window
    /// server and Accessibility report whole points, so less than one point.
    static let frameTolerance: CGFloat = 1

    /// Notifications can come while the meeting window is still leaving the
    /// screen, when nothing may be minimized yet, so each is followed by checks
    /// this long after it. They are the only timers: with no events, the
    /// service never wakes [F2, F21].
    static let settleDelays: [TimeInterval] = [0.3, 1]

    /// How long to give Teams between being hidden, its floating window being
    /// minimized and being shown again. Enough for the hide to take effect
    /// before the minimize, so that it has no animation [F22].
    static let hideSettle: TimeInterval = 0.05

    /// A floating window that appears this soon after a quiet minimize is
    /// minimized the plain way, in case showing Teams again is what made Teams
    /// open it: hiding again would go round in a loop [F20].
    static let quietRepeatGuard: TimeInterval = 2

    static func isFloatingWindow(title: String?) -> Bool {
        title?.hasPrefix(floatingTitlePrefix) == true
    }

    /// Whether to minimize a floating window now. Not when it is already
    /// minimized or you restored it from the Dock, and not while Teams is the
    /// active app: you are at Teams then, and Teams takes the floating window
    /// away itself [F3]. Not "a Teams window is on screen", since the meeting
    /// window counts as on screen even when another app covers it [F24].
    static func shouldMinimize(isMinimized: Bool, isKept: Bool, teamsIsActive: Bool) -> Bool {
        !isMinimized && !isKept && !teamsIsActive
    }

    /// Whether to minimize quietly: hide Teams, minimize, show Teams again,
    /// which has no animation [F22]. Only ever asked while Teams is not the
    /// active app, so hiding it takes no focus away [F23]. Not when Teams is
    /// already hidden, since showing it again would undo your ⌘H, and not soon
    /// after the last quiet minimize.
    static func shouldMinimizeQuietly(teamsIsHidden: Bool, secondsSinceLastQuiet: TimeInterval) -> Bool {
        !teamsIsHidden && secondsSinceLastQuiet >= quietRepeatGuard
    }

    /// Whether you are back at Teams, which ends a keep: Teams is the active
    /// app and its focused window is not the floating window. Restoring the
    /// floating window from the Dock makes Teams active too, and must not end
    /// the keep it starts [F5].
    static func isBackAtTeams(teamsIsActive: Bool, focusedWindowTitle: String?) -> Bool {
        teamsIsActive && !isFloatingWindow(title: focusedWindowTitle)
    }

    static func sameFrame(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) < frameTolerance && abs(a.minY - b.minY) < frameTolerance
            && abs(a.width - b.width) < frameTolerance && abs(a.height - b.height) < frameTolerance
    }
}

/// The floating window you restored from the Dock, which is left alone until
/// you are back at a Teams window or minimize it yourself. teams-unfloat never
/// restores a window and never minimizes the kept one, so both events are yours.
struct Keeper<Window: Equatable> {
    private(set) var kept: Window?

    func isKept(_ window: Window) -> Bool { kept == window }

    mutating func restoredFromDock(_ window: Window) { kept = window }

    /// Returns whether this ended a keep.
    mutating func minimized(_ window: Window) -> Bool {
        guard isKept(window) else { return false }
        kept = nil
        return true
    }

    /// Returns whether this ended a keep.
    mutating func backAtTeams() -> Bool {
        guard kept != nil else { return false }
        kept = nil
        return true
    }

    mutating func reset() { kept = nil }
}
