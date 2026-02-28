import Foundation
import HappyPlatformAPI

final class MacTimeSource: NSObject, PlatformTimeSource {
    func getUtcTimeSeconds() -> Int64 {
        return Int64(Date().timeIntervalSince1970)
    }

    func getGmtOffsetHours() -> Int32 {
        return Int32(TimeZone.current.secondsFromGMT() / 3600)
    }
}
