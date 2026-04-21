import AppKit
import ApplicationServices
import Foundation

@MainActor
final class EventCaptureService {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: ((KeyEventRecord) -> Void)?

    func start(handler: @escaping (KeyEventRecord) -> Void) {
        stop()
        self.handler = handler

        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let service = Unmanaged<EventCaptureService>.fromOpaque(userInfo).takeUnretainedValue()
            if type == .tapDisabledByTimeout, let eventTap = service.eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown || type == .flagsChanged else {
                return Unmanaged.passUnretained(event)
            }

            let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = Int(event.flags.rawValue)
            let frontmostApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            let record = KeyEventRecord(
                id: UUID().uuidString.lowercased(),
                occurredAt: .now,
                keyCode: keyCode,
                modifierFlags: flags,
                eventType: type == .keyDown ? "keyDown" : "flagsChanged",
                sourceApp: frontmostApp
            )
            service.handler?(record)
            return Unmanaged.passUnretained(event)
        }

        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: pointer
        )

        guard let eventTap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        guard let runLoopSource else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
        handler = nil
    }
}
