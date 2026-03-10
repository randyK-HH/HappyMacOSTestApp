import Foundation
import HappyPlatformAPI

struct AppSettings: Codable, Equatable {
    // Transport
    var preferL2cap: Bool = true

    // Scan / Connection
    var minRssi: Int = -80
    var autoReconnect: Bool = true
    var maxReconnectRetries: Int = 64

    // Download
    var batchSize: Int = 64
    var stallTimeoutSec: Int = 60
    var failsafeTimerMin: Int = 21

    // Handshake
    var fingerDetectionOnConnect: Bool = true
    var memfaultIntervalIndex: Int = 0  // 0=Every connection, 1=Hourly, 2=Never

    // FW Update
    var interBlockDelayMs: Int = 30
    var drainDelayMs: Int = 2000

    static let `default` = AppSettings()

    func toHpyConfig() -> HpyConfig {
        return HpyConfig(
            commandTimeoutMs: 5000,
            skipFingerDetection: !fingerDetectionOnConnect,
            requestedMtu: 247,
            downloadBatchSize: Int32(batchSize),
            downloadMaxRetries: 1,
            preferL2capDownload: preferL2cap,
            minRssi: Int32(minRssi)
        )
    }

    // Memfault interval display options
    static let memfaultIntervalOptions = ["Every connection", "Hourly", "Never"]

    // Picker options
    static let minRssiOptions = [-60, -65, -70, -75, -80, -85, -90, -95, -100]
    static let batchSizeOptions = [8, 16, 32, 64, 128]
    static let stallTimeoutOptions = [30, 45, 60, 90, 120]
    static let failsafeTimerOptions = [5, 10, 15, 21, 30, 45, 60]
    static let maxRetriesOptions = [8, 16, 32, 64, 128, 256]
    static let interBlockDelayOptions = [0, 10, 20, 30, 50, 100]
    static let drainDelayOptions = [500, 1000, 1500, 2000, 3000, 5000]
}
