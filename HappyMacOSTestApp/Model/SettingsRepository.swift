import Foundation

final class SettingsRepository {
    private let defaults = UserDefaults.standard
    private let globalKey = "hpy_global_settings"
    private func ringKey(_ address: String) -> String { "hpy_ring_\(address)" }

    func loadGlobalSettings() -> AppSettings {
        guard let data = defaults.data(forKey: globalKey),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return .default }
        return settings
    }

    func saveGlobalSettings(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: globalKey)
        }
    }

    func loadRingOverrides(address: String) -> AppSettings? {
        guard let data = defaults.data(forKey: ringKey(address)),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return nil }
        return settings
    }

    func saveRingOverrides(address: String, settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: ringKey(address))
        }
    }

    func clearRingOverrides(address: String) {
        defaults.removeObject(forKey: ringKey(address))
    }

    func effectiveSettings(forAddress address: String) -> AppSettings {
        return loadRingOverrides(address: address) ?? loadGlobalSettings()
    }
}
