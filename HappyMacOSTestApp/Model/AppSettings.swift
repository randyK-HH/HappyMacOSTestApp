import Foundation
import HappyPlatformAPI

struct AppSettings: Codable, Equatable {
    // Transport
    var preferL2cap: Bool = true
    var use96MHzClock: Bool = false

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
    var fwUpdateUseGatt: Bool = false
    var interBlockDelayMs: Int = 30
    var drainDelayMs: Int = 2000

    static let `default` = AppSettings()

    private var memfaultMinIntervalMs: Int64 {
        switch memfaultIntervalIndex {
        case 1: return 600_000      // 10 min
        case 2: return 1_200_000    // 20 min
        case 3: return 1_800_000    // 30 min
        case 4: return 3_600_000    // 60 min
        case 5: return Int64.max    // Never
        default: return 0           // Every connection
        }
    }

    func toHpyConfig() -> HpyConfig {
        return HpyConfig(
            commandTimeoutMs: 5000,
            skipFingerDetection: !fingerDetectionOnConnect,
            requestedMtu: 247,
            downloadBatchSize: Int32(batchSize),
            downloadMaxRetries: 1,
            preferL2capDownload: preferL2cap,
            l2capClockByte: use96MHzClock ? 0x02 : 0x01,
            minRssi: Int32(minRssi),
            downloadStallTimeoutMs: Int64(stallTimeoutSec) * 1000,
            reconnectMaxAttempts: Int32(maxReconnectRetries),
            downloadFailsafeIntervalMs: Int64(failsafeTimerMin) * 60 * 1000,
            memfaultMinIntervalMs: memfaultMinIntervalMs,
            autoReconnect: autoReconnect,
            fwStreamInterBlockDelayMs: Int64(interBlockDelayMs),
            fwStreamDrainDelayMs: Int64(drainDelayMs),
            fwUpdateUseGatt: fwUpdateUseGatt
        )
    }

    // Memfault interval display options
    static let memfaultIntervalOptions = ["Every connection", "10 min", "20 min", "30 min", "60 min", "Never"]

    // Picker options
    static let minRssiOptions = [-60, -70, -75, -80, -85, -90, -95, -100]
    static let batchSizeOptions = [8, 16, 32, 64, 128]
    static let stallTimeoutOptions = [15, 30, 45, 60, 90, 120]
    static let failsafeTimerOptions = [6, 11, 16, 21, 26, 31, 41, 51, 61]
    static let maxRetriesOptions = [8, 16, 32, 64, Int(Int32.max)]
    static let interBlockDelayOptions = [10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60]
    static let drainDelayOptions = [1000, 2000, 3000, 4000, 5000, 6000, 7000]
}
