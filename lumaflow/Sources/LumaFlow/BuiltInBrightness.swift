import AppKit
import CoreGraphics
import Darwin

/// Built-in Apple Silicon displays currently require DisplayServices, a private macOS API.
/// Resolve symbols at runtime so unsupported systems fail gracefully rather than crash.
/// This backend does not support ordinary third-party DDC/CI external monitors.
final class BuiltInBrightness {
    private typealias Getter = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias Setter = @convention(c) (UInt32, Float) -> Int32
    private typealias CanChange = @convention(c) (UInt32) -> Bool

    private let library: UnsafeMutableRawPointer?
    private let getter: Getter?
    private let setter: Setter?
    private let canChange: CanChange?
    let displayID: CGDirectDisplayID

    init() {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        _ = CGGetActiveDisplayList(UInt32(ids.count), &ids, &count)
        displayID = ids.prefix(Int(count)).first(where: { CGDisplayIsBuiltin($0) != 0 }) ?? CGMainDisplayID()

        let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_NOW
        )
        library = handle
        if let handle, let sym = dlsym(handle, "DisplayServicesGetBrightness") {
            getter = unsafeBitCast(sym, to: Getter.self)
        } else {
            getter = nil
        }
        if let handle, let sym = dlsym(handle, "DisplayServicesSetBrightness") {
            setter = unsafeBitCast(sym, to: Setter.self)
        } else {
            setter = nil
        }
        if let handle, let sym = dlsym(handle, "DisplayServicesCanChangeBrightness") {
            canChange = unsafeBitCast(sym, to: CanChange.self)
        } else {
            canChange = nil
        }
    }

    deinit {
        if let library { dlclose(library) }
    }

    var isAvailable: Bool {
        guard getter != nil, setter != nil, CGDisplayIsBuiltin(displayID) != 0 else { return false }
        return canChange?(displayID) ?? true
    }

    func read() -> Float? {
        guard let getter else { return nil }
        var value: Float = 0
        guard getter(displayID, &value) == 0, value.isFinite,
              (0...1).contains(value) else { return nil }
        return value
    }

    @discardableResult
    func write(_ level: Float) -> Bool {
        guard let setter, isAvailable else { return false }
        let safeLevel = min(1, max(0.15, level))
        return setter(displayID, safeLevel) == 0
    }
}
