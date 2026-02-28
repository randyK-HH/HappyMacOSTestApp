import Foundation
import HappyPlatformAPI

/// Manages KMP flow observation handles and cleans them up on deinit.
final class FlowCollector {
    private var handles = [Closeable]()

    func add(_ handle: Closeable) {
        handles.append(handle)
    }

    func cancelAll() {
        for handle in handles {
            handle.close()
        }
        handles.removeAll()
    }

    deinit {
        cancelAll()
    }
}
