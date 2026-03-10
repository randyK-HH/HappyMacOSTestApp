import SwiftUI
import HappyPlatformAPI

@main
struct HappyMacOSTestAppApp: App {
    @StateObject private var viewModel: TestAppViewModel

    init() {
        let repo = SettingsRepository()
        let settings = repo.loadGlobalSettings()
        let shim = MacBleShim()
        let timeSource = MacTimeSource()
        let api = HappyPlatformApiKt.createHappyPlatformApi(
            shim: shim,
            timeSource: timeSource,
            config: settings.toHpyConfig()
        )
        shim.callback = api.shimCallback
        let vm = TestAppViewModel(api: api, shim: shim)
        vm.globalSettings = settings
        _viewModel = StateObject(wrappedValue: vm)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .frame(minWidth: 700, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)
    }
}
