import AppKit
import ApplicationServices
import Foundation

final class EventCaptureService {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var onEvent: ((KeyEventRecord) -> Void)?

    func start() {
        stop()

        let eventMask = 1 << CGEventType.keyDown.rawValue
        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: Self.eventTapCallback,
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
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let service = Unmanaged<EventCaptureService>.fromOpaque(userInfo).takeUnretainedValue()
        if type == .tapDisabledByTimeout, let eventTap = service.eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: true)
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        guard service.shouldRecordTextChangingKey(event: event) else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = service.normalizedModifierFlags(from: event.flags)
        let frontmostApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let record = KeyEventRecord(
            id: UUID().uuidString.lowercased(),
            occurredAt: .now,
            keyCode: keyCode,
            modifierFlags: flags,
            eventType: "keyDown",
            sourceApp: frontmostApp
        )
        service.onEvent?(record)
        return Unmanaged.passUnretained(event)
    }

    private func shouldRecordTextChangingKey(event: CGEvent) -> Bool {
        let flags = event.flags
        if flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskSecondaryFn) {
            return false
        }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        // Backspace removes text even though it is not printable.
        if keyCode == 51 {
            return true
        }

        // Exclude known non-text navigation/control keys.
        if keyCode == 48 || keyCode == 53 {
            return false
        }

        guard let nsEvent = NSEvent(cgEvent: event) else {
            return false
        }

        let characters = nsEvent.charactersIgnoringModifiers ?? nsEvent.characters ?? ""
        guard characters.count == 1, let scalar = characters.unicodeScalars.first else {
            return false
        }

        if CharacterSet.newlines.contains(scalar) || CharacterSet.whitespaces.contains(scalar) {
            return true
        }

        if CharacterSet.alphanumerics.contains(scalar) || CharacterSet.punctuationCharacters.contains(scalar) {
            return true
        }

        return CharacterSet.symbols.contains(scalar)
    }

    private func normalizedModifierFlags(from flags: CGEventFlags) -> Int {
        var normalized = 0

        if flags.contains(.maskShift) {
            normalized |= 1
        }
        if flags.contains(.maskAlternate) {
            normalized |= 2
        }
        if flags.contains(.maskControl) {
            normalized |= 4
        }
        if flags.contains(.maskCommand) {
            normalized |= 8
        }
        if flags.contains(.maskAlphaShift) {
            normalized |= 16
        }

        return normalized
    }
}
