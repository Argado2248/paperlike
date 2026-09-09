import Foundation
import PaperlikeCore

/// Single source of truth for user state, persisted in UserDefaults.
/// Posts `SettingsStore.didChange` on the main thread after every change.
final class SettingsStore {
    static let shared = SettingsStore()
    static let didChange = Notification.Name("PaperlikeSettingsDidChange")

    private enum Key {
        static let filter = "filter"
        static let enabled = "enabled"
        static let excludeFromCapture = "excludeFromCapture"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.enabled: false,
            Key.excludeFromCapture: true,
        ])
        if let data = defaults.data(forKey: Key.filter),
           let decoded = try? JSONDecoder().decode(FilterSettings.self, from: data) {
            filter = decoded.clamped()
        } else {
            filter = .default
        }
        isEnabled = defaults.bool(forKey: Key.enabled)
        excludeFromCapture = defaults.bool(forKey: Key.excludeFromCapture)
    }

    var filter: FilterSettings {
        didSet {
            // Assigning inside didSet does not re-trigger the observer, so
            // clamp in place and carry on with the clamped value.
            let clamped = filter.clamped()
            if clamped != filter { filter = clamped }
            guard filter != oldValue else { return }
            if let data = try? JSONEncoder().encode(filter) {
                defaults.set(data, forKey: Key.filter)
            }
            notify()
        }
    }

    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            defaults.set(isEnabled, forKey: Key.enabled)
            notify()
        }
    }

    var excludeFromCapture: Bool {
        didSet {
            guard excludeFromCapture != oldValue else { return }
            defaults.set(excludeFromCapture, forKey: Key.excludeFromCapture)
            notify()
        }
    }

    private func notify() {
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
}
