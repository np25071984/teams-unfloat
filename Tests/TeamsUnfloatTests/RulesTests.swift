// What happens to Teams' floating meeting window, and how it is minimized.

import CoreGraphics
import Testing
@testable import teams_unfloat

@Suite("Rules")
struct RulesTests {
    @Test("the floating window is recognised by its title, whatever the meeting is called", arguments: [
        "Meeting compact view | Meeting with Alex",
        "Meeting compact view | Weekly sync",
        "Meeting compact view",
    ])
    func floatingTitles(title: String) {
        #expect(Rules.isFloatingWindow(title: title))
    }

    @Test("the meeting window, other Teams windows and untitled windows are left alone", arguments: [
        "Meeting with Alex", "Calendar", "Chat | Alex", "", "Window",
    ])
    func otherTitles(title: String) {
        #expect(!Rules.isFloatingWindow(title: title))
    }

    @Test("a window with no title yet is not taken for the floating window")
    func noTitle() {
        #expect(!Rules.isFloatingWindow(title: nil))
    }

    @Test("a floating window that is showing, not kept, while another app is active, is minimized")
    func minimizes() {
        #expect(Rules.shouldMinimize(isMinimized: false, isKept: false, teamsIsActive: false))
    }

    @Test("one already minimized is left alone, so it is never minimized twice")
    func alreadyMinimized() {
        #expect(!Rules.shouldMinimize(isMinimized: true, isKept: false, teamsIsActive: false))
    }

    @Test("one you restored from the Dock stays")
    func kept() {
        #expect(!Rules.shouldMinimize(isMinimized: false, isKept: true, teamsIsActive: false))
    }

    @Test("nothing is minimized while Teams is the active app: you are at Teams, and Teams removes it itself")
    func atTeams() {
        #expect(!Rules.shouldMinimize(isMinimized: false, isKept: false, teamsIsActive: true))
    }

    @Test("a floating window is minimized quietly, with no animation")
    func quiet() {
        #expect(Rules.shouldMinimizeQuietly(teamsIsHidden: false, secondsSinceLastQuiet: 60))
    }

    @Test("not quietly when you hid Teams, since showing it again would undo your ⌘H")
    func notQuietWhenHidden() {
        #expect(!Rules.shouldMinimizeQuietly(teamsIsHidden: true, secondsSinceLastQuiet: 60))
    }

    @Test("not quietly again within 2 seconds, so a window Teams opens on being shown again cannot start a loop")
    func notQuietTwiceInARow() {
        #expect(!Rules.shouldMinimizeQuietly(teamsIsHidden: false, secondsSinceLastQuiet: 1.9))
        #expect(Rules.shouldMinimizeQuietly(teamsIsHidden: false, secondsSinceLastQuiet: 2))
    }

    @Test("you are back at Teams when it is active with the meeting or another Teams window focused")
    func backAtTeams() {
        #expect(Rules.isBackAtTeams(teamsIsActive: true, focusedWindowTitle: "Meeting with Alex"))
        #expect(Rules.isBackAtTeams(teamsIsActive: true, focusedWindowTitle: nil))
    }

    @Test("not when the floating window has focus, as after restoring it from the Dock, so the keep it starts lasts")
    func restoredIsNotBackAtTeams() {
        #expect(!Rules.isBackAtTeams(teamsIsActive: true, focusedWindowTitle: "Meeting compact view | Meeting with Alex"))
    }

    @Test("not while another app is active, even with the meeting window behind it on the same Space")
    func otherAppIsNotBackAtTeams() {
        #expect(!Rules.isBackAtTeams(teamsIsActive: false, focusedWindowTitle: "Meeting with Alex"))
    }

    @Test("frames less than a point apart are the same window, since both sources report whole points")
    func sameFrame() {
        let a = CGRect(x: 1263, y: 868, width: 465, height: 249)
        #expect(Rules.sameFrame(a, CGRect(x: 1263.5, y: 868, width: 465, height: 249)))
        #expect(!Rules.sameFrame(a, CGRect(x: 1264, y: 868, width: 465, height: 249)))
        #expect(!Rules.sameFrame(a, CGRect(x: 1263, y: 868, width: 1387, height: 867)))
    }
}

@Suite("Keeper")
struct KeeperTests {
    @Test("a window restored from the Dock is kept")
    func restoredIsKept() {
        var keeper = Keeper<Int>()
        keeper.restoredFromDock(1)
        #expect(keeper.isKept(1))
        #expect(!keeper.isKept(2))
    }

    @Test("minimizing the kept window yourself ends the keep, so it is minimized again next time")
    func minimizedByYou() {
        var keeper = Keeper<Int>()
        keeper.restoredFromDock(1)
        let ended = keeper.minimized(1)
        #expect(ended)
        #expect(!keeper.isKept(1))
    }

    @Test("another window being minimized, as the service does, does not end the keep")
    func otherMinimized() {
        var keeper = Keeper<Int>()
        keeper.restoredFromDock(1)
        let ended = keeper.minimized(2)
        #expect(!ended)
        #expect(keeper.isKept(1))
    }

    @Test("being back at Teams ends the keep, so leaving it again minimizes the floating window")
    func backAtTeams() {
        var keeper = Keeper<Int>()
        keeper.restoredFromDock(1)
        let ended = keeper.backAtTeams()
        #expect(ended)
        #expect(!keeper.isKept(1))
    }

    @Test("being back at Teams with nothing kept is not reported as a change, so it is not logged every check")
    func backAtTeamsWithNothingKept() {
        var keeper = Keeper<Int>()
        let ended = keeper.backAtTeams()
        #expect(!ended)
    }

    @Test("restoring a second window keeps that one instead: only the window you last restored stays")
    func lastRestoredWins() {
        var keeper = Keeper<Int>()
        keeper.restoredFromDock(1)
        keeper.restoredFromDock(2)
        #expect(keeper.isKept(2))
        #expect(!keeper.isKept(1))
    }
}
