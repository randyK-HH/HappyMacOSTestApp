import Foundation

private let frameSize = 4096

final class FrameWriter {
    static var hpy2Folder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("BLE_HPY2_DATA")
    }

    static func hpy2Folder(forDevice deviceId: String) -> URL {
        return hpy2Folder.appendingPathComponent(deviceId)
    }

    private let queue = DispatchQueue(label: "com.happyhealth.framewriter", qos: .utility)
    private var fileHandle: FileHandle?
    private var outputUrl: URL?
    private(set) var totalFramesWritten: Int = 0

    var filePath: String? { outputUrl?.path }

    func ensureFileOpen(deviceId: String? = nil) {
        guard outputUrl == nil else { return }

        let folder = if let deviceId { Self.hpy2Folder(forDevice: deviceId) } else { Self.hpy2Folder }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let fileName = "data_\(timestamp).hpy2"
        let url = folder.appendingPathComponent(fileName)

        FileManager.default.createFile(atPath: url.path, contents: nil)
        fileHandle = try? FileHandle(forWritingTo: url)
        outputUrl = url
        totalFramesWritten = 0
    }

    func writeFrame(_ frameData: Data) {
        ensureFileOpen()
        queue.async { [weak self] in
            self?.fileHandle?.seekToEndOfFile()
            self?.fileHandle?.write(frameData)
            self?.totalFramesWritten += 1
        }
    }

    func discardFrames(_ count: Int) {
        guard count > 0 else { return }
        queue.async { [weak self] in
            guard let self = self, let handle = self.fileHandle else { return }
            let bytesToRemove = UInt64(count * frameSize)
            let currentLength = handle.seekToEndOfFile()
            if bytesToRemove <= currentLength {
                handle.truncateFile(atOffset: currentLength - bytesToRemove)
                self.totalFramesWritten = max(0, self.totalFramesWritten - count)
            }
        }
    }

    func closeFile() {
        try? fileHandle?.close()
        fileHandle = nil
        outputUrl = nil
    }

    func destroy() {
        closeFile()
    }
}
