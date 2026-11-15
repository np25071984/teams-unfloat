// Watches Microsoft Teams and minimizes its floating meeting window.
//
// Only events wake it: Teams creating or retitling a window, the focused
// window changing, another app becoming active, another Space. Each runs a
// check at once and two more shortly after [F2, F21]; with no events there is
// no work at all. What to do is decided in Rules and Keeper; this class only
// asks macOS and acts.

import AppKit
import ApplicationServices

final class Unfloater {
    private var observer: AXObserver?
    private var observedPID: pid_t = 0
    private var keeper = Keeper<AXUIElement>()
    /// Floating windows watched for being minimized and restored, so the ones
    /// open before the service started are watched too.
    private var watched: [AXUIElement] = []
    /// The checks that follow the latest event; a newer event replaces them.
    private var settleChecks: [DispatchWorkItem] = []
    /// Between hiding Teams and showing it again, when its windows say nothing
    /// about where you are.
    private var minimizingQuietly = false
    private var lastQuietMinimize = Date.distantPast
    private(set) var minimizedCount = 0

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.event() }
        }
        event()
    }

    // MARK: State for `status`

    var teamsPID: pid_t? { Self.teams()?.processIdentifier }

    /// The floating window as `teams-unfloat status` describes it.
    var floatingState: String {
        guard let pid = teamsPID else { return "Teams is not running" }
        let windows = floatingWindows(pid: pid)
        guard !windows.isEmpty else { return "none" }
        if windows.contains(where: keeper.isKept) { return "kept: you restored it from the Dock" }
        if windows.contains(where: { !Self.isMinimized($0) && isOnScreen($0, pid: pid) }) { return "showing" }
        return "minimized or out of view"
    }

    // MARK: Checks

    /// Checks now, then again after each of `Rules.settleDelays`.
    private func event() {
        check()
        settleChecks.forEach { $0.cancel() }
        settleChecks = Rules.settleDelays.map { delay in
            let item = DispatchWorkItem { [weak self] in self?.check() }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return item
        }
    }

    private func check() {
        guard !minimizingQuietly else { return }
        guard let app = Self.teams() else {
            observedPID = 0
            keeper.reset()
            watched.removeAll()
            return
        }
        let pid = app.processIdentifier
        observe(pid: pid)
        let windows = floatingWindows(pid: pid)
        guard !windows.isEmpty else {
            watched.removeAll()
            return
        }
        if Rules.isBackAtTeams(teamsIsActive: app.isActive, focusedWindowTitle: focusedWindowTitle(pid: pid)),
           keeper.backAtTeams() {
            Log.info("back at Teams; the floating window is minimized again next time")
        }
        for window in windows {
            if !watched.contains(window) {
                watch(window)
                watched.append(window)
            }
            if isOnScreen(window, pid: pid) { minimize(window, pid: pid, via: "check") }
        }
        watched.removeAll { !windows.contains($0) }
    }

    private func minimize(_ window: AXUIElement, pid: pid_t, via source: String) {
        guard !minimizingQuietly,
              Rules.isFloatingWindow(title: Self.title(window)),
              let app = NSRunningApplication(processIdentifier: pid),
              Rules.shouldMinimize(
                isMinimized: Self.isMinimized(window), isKept: keeper.isKept(window),
                teamsIsActive: app.isActive)
        else { return }
        minimizedCount += 1
        guard Rules.shouldMinimizeQuietly(
            teamsIsHidden: app.isHidden, secondsSinceLastQuiet: Date().timeIntervalSince(lastQuietMinimize))
        else {
            Self.setMinimized(window)
            Log.info("minimized the floating window (\(source))")
            return
        }
        // Hidden, Teams' windows are off screen, and a window minimized then
        // goes to the Dock with no animation. Shown again, Teams brings back
        // its other windows and leaves that one in the Dock [F22].
        minimizingQuietly = true
        lastQuietMinimize = Date()
        app.hide()
        DispatchQueue.main.asyncAfter(deadline: .now() + Rules.hideSettle) { [weak self] in
            Self.setMinimized(window)
            DispatchQueue.main.asyncAfter(deadline: .now() + Rules.hideSettle) {
                app.unhide()
                self?.minimizingQuietly = false
                Log.info("minimized the floating window quietly (\(source))")
            }
        }
    }

    // MARK: Notifications

    private func observe(pid: pid_t) {
        guard pid != observedPID else { return }
        if let old = observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(old), .defaultMode)
            observer = nil
        }
        keeper.reset()
        watched.removeAll()
        var created: AXObserver?
        guard AXObserverCreate(pid, Self.callback, &created) == .success, let new = created else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let app = AXUIElementCreateApplication(pid)
        guard AXObserverAddNotification(new, app, kAXWindowCreatedNotification as CFString, refcon) == .success
        else { return }
        // The meeting window losing focus to another Teams window can bring the
        // floating window back without a new one.
        AXObserverAddNotification(new, app, kAXFocusedWindowChangedNotification as CFString, refcon)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(new), .defaultMode)
        observer = new
        observedPID = pid
        Log.info("watching Teams, pid \(pid)")
    }

    /// A floating window's title, which can come after it is created, and its
    /// being minimized and restored, which say what you did with it [F5].
    private func watch(_ window: AXUIElement) {
        guard let observer else { return }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXTitleChangedNotification, kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification] {
            AXObserverAddNotification(observer, window, name as CFString, refcon)
        }
    }

    private static let callback: AXObserverCallback = { _, element, notification, refcon in
        guard let refcon else { return }
        Unmanaged<Unfloater>.fromOpaque(refcon).takeUnretainedValue()
            .handle(notification as String, element)
    }

    private func handle(_ name: String, _ element: AXUIElement) {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        switch name {
        case kAXWindowCreatedNotification:
            watch(element)
            minimize(element, pid: pid, via: "new window")
            event()
        case kAXTitleChangedNotification:
            minimize(element, pid: pid, via: "title")
            event()
        case kAXFocusedWindowChangedNotification:
            event()
        case kAXWindowDeminiaturizedNotification where Rules.isFloatingWindow(title: Self.title(element)):
            keeper.restoredFromDock(element)
            Log.info("keeping the floating window: restored from the Dock")
        case kAXWindowMiniaturizedNotification:
            if keeper.minimized(element) {
                Log.info("you minimized the floating window; it is minimized again next time")
            }
        default:
            break
        }
    }

    // MARK: macOS

    private static func teams() -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: Rules.teamsBundleID).first
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    private static func title(_ window: AXUIElement) -> String? {
        attribute(window, kAXTitleAttribute) as? String
    }

    private static func isMinimized(_ window: AXUIElement) -> Bool {
        (attribute(window, kAXMinimizedAttribute) as? Bool) == true
    }

    private static func setMinimized(_ window: AXUIElement) {
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }

    private static func frame(of window: AXUIElement) -> CGRect? {
        guard let p = attribute(window, kAXPositionAttribute), let s = attribute(window, kAXSizeAttribute),
              CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var origin = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &origin),
              AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private func focusedWindowTitle(pid: pid_t) -> String? {
        guard let window = Self.attribute(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute) else { return nil }
        return Self.title(window as! AXUIElement)
    }

    private func floatingWindows(pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        let windows = Self.attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
        return windows.filter { Rules.isFloatingWindow(title: Self.title($0)) }
    }

    /// Frames of Teams' windows on the current Space, from the window server:
    /// only it knows whether the floating window is showing [F3].
    private func onScreenFrames(pid: pid_t) -> [CGRect] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { info in
            guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  let bounds = info[kCGWindowBounds as String] as? NSDictionary else { return nil }
            return CGRect(dictionaryRepresentation: bounds)
        }
    }

    private func isOnScreen(_ window: AXUIElement, pid: pid_t) -> Bool {
        guard let target = Self.frame(of: window) else { return false }
        return onScreenFrames(pid: pid).contains { Rules.sameFrame($0, target) }
    }
}
