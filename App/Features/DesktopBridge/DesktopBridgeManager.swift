import AppKit
import Foundation
import ApplicationServices
import Observation
import Shared

@MainActor
@Observable
final class DesktopBridgeManager {
    static let shared = DesktopBridgeManager()

    var isAccessibilityEnabled: Bool = false
    var isInputMonitoringEnabled: Bool = false
    var isRunning: Bool = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onDesktopRightClick: ((CGPoint) -> Void)?

    private init() {
        checkPermissions(prompt: false)
    }

    func checkPermissions(prompt: Bool = false) {
        let options = prompt ? ["AXTrustedCheckOptionPrompt": true] as CFDictionary : nil
        self.isAccessibilityEnabled = AXIsProcessTrustedWithOptions(options)

        // CGPreflightListenEventAccess is macOS 10.15+
        self.isInputMonitoringEnabled = CGPreflightListenEventAccess()

        if isAccessibilityEnabled && isInputMonitoringEnabled && !isRunning {
            startMonitoring()
        } else if (!isAccessibilityEnabled || !isInputMonitoringEnabled) && isRunning {
            stopMonitoring()
        }
    }

    func requestAccessibility() {
        checkPermissions(prompt: true)
    }

    func requestInputMonitoring() {
        CGRequestListenEventAccess()
        checkPermissions()
    }

    func startMonitoring() {
        guard isAccessibilityEnabled, isInputMonitoringEnabled, eventTap == nil else { return }

        let mask = (1 << CGEventType.rightMouseDown.rawValue) | (1 << CGEventType.rightMouseUp.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }

            let manager = Unmanaged<DesktopBridgeManager>.fromOpaque(refcon).takeUnretainedValue()

            if type == .rightMouseDown {
                let flags = event.flags
                let mouseLocation = event.unflippedLocation

                // Only intercept when Option key is held — normal right-click passes through to system
                guard flags.contains(.maskAlternate) else {
                    return Unmanaged.passUnretained(event)
                }

                NSLog("[DesktopBridge] Option+rightMouseDown at (%.0f, %.0f)", mouseLocation.x, mouseLocation.y)
                let isDesktop = manager.isPointOnDesktopBackground(mouseLocation)
                NSLog("[DesktopBridge] isDesktop = %@", isDesktop ? "YES" : "NO")
                if isDesktop {
                    manager.shouldEatNextRightMouseUp = true
                    DispatchQueue.main.async {
                        manager.onDesktopRightClick?(NSEvent.mouseLocation)
                    }
                    return nil
                } else {
                    manager.shouldEatNextRightMouseUp = false
                }
            } else if type == .rightMouseUp {
                if manager.shouldEatNextRightMouseUp {
                    manager.shouldEatNextRightMouseUp = false
                    return nil
                }
            }

            return Unmanaged.passUnretained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: refcon
        ) else {
            self.isInputMonitoringEnabled = false
            return
        }

        self.eventTap = tap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.isRunning = true
    }

    func stopMonitoring() {
        if let tap = eventTap, let source = runLoopSource {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            self.eventTap = nil
            self.runLoopSource = nil
        }
        self.isRunning = false
    }

    nonisolated(unsafe) private var shouldEatNextRightMouseUp = false

    nonisolated private func isPointOnDesktopBackground(_ point: CGPoint) -> Bool {
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &element)

        guard error == .success, let target = element else {
            NSLog("[DesktopBridge] AX error: %d", error.rawValue)
            return false
        }

        var pid: pid_t = 0
        let pidError = AXUIElementGetPid(target, &pid)
        guard pidError == .success, let runningApp = NSRunningApplication(processIdentifier: pid) else {
            NSLog("[DesktopBridge] failed to get PID")
            return false
        }

        let bundleId = runningApp.bundleIdentifier ?? "unknown"
        NSLog("[DesktopBridge] element belongs to: %@ (pid=%d)", bundleId, pid)

        guard bundleId == "com.apple.finder" else {
            return false
        }

        var roleCF: CFTypeRef?
        AXUIElementCopyAttributeValue(target, "AXRole" as CFString, &roleCF)
        let role = roleCF as? String ?? ""

        var subroleDirectCF: CFTypeRef?
        AXUIElementCopyAttributeValue(target, "AXSubrole" as CFString, &subroleDirectCF)
        let directSubrole = subroleDirectCF as? String ?? ""

        NSLog("[DesktopBridge] element role=%@ subrole=%@", role, directSubrole)

        // Desktop background on macOS 26 can appear as various AX elements
        if role == "AXScrollArea" {
            var winCF: CFTypeRef?
            AXUIElementCopyAttributeValue(target, "AXWindow" as CFString, &winCF)
            if winCF == nil {
                NSLog("[DesktopBridge] -> ScrollArea with no window = DESKTOP")
                return true
            }
        }

        // Also check: if the role is AXGroup or AXList on the desktop
        if role == "AXGroup" || role == "AXList" || role == "AXUnknown" {
            NSLog("[DesktopBridge] -> Desktop candidate role=%@, returning true", role)
            return true
        }

        var windowCF: CFTypeRef?
        AXUIElementCopyAttributeValue(target, "AXWindow" as CFString, &windowCF)
        guard let window = windowCF else {
            NSLog("[DesktopBridge] -> Finder element with no window = likely DESKTOP")
            return true
        }

        let windowElement = window as! AXUIElement
        var subroleCF: CFTypeRef?
        AXUIElementCopyAttributeValue(windowElement, "AXSubrole" as CFString, &subroleCF)
        let subrole = subroleCF as? String ?? ""

        var titleCF: CFTypeRef?
        AXUIElementCopyAttributeValue(windowElement, "AXTitle" as CFString, &titleCF)
        let title = titleCF as? String ?? ""

        NSLog("[DesktopBridge] window subrole=%@ title=%@", subrole, title)

        // The desktop window has special subroles or empty title
        if subrole == "AXSystemDialog" || subrole == "AXSystemFloatingWindow" || subrole == "AXUnknown" {
            if title.isEmpty || title == "Desktop" || title == "桌面" {
                NSLog("[DesktopBridge] -> DESKTOP via window subrole/title")
                return true
            }
        }

        // Fallback: Finder element without a standard window title might be desktop
        if title.isEmpty {
            NSLog("[DesktopBridge] -> DESKTOP via empty window title")
            return true
        }

        NSLog("[DesktopBridge] -> NOT desktop (window title=%@)", title)
        return false
    }
}
