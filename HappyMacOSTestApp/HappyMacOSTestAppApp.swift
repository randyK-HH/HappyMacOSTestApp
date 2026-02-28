import SwiftUI
import HappyPlatformAPI

@main
struct HappyMacOSTestAppApp: App {
    @StateObject private var viewModel: TestAppViewModel

    init() {
        let shim = MacBleShim()
        let timeSource = MacTimeSource()
        let api = HappyPlatformApiKt.createHappyPlatformApi(
            shim: shim,
            timeSource: timeSource,
            config: HpyConfig(
                commandTimeoutMs: 5000,
                skipFingerDetection: false,
                requestedMtu: 247,
                downloadBatchSize: 64,
                downloadMaxRetries: 1,
                preferL2capDownload: true,
                minRssi: -80
            )
        )
        shim.callback = api.shimCallback
        let vm = TestAppViewModel(api: api, shim: shim)
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
