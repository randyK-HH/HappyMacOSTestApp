import Foundation

private let suotaHeaderSize = 36
private let maxFwImageSize = 327680  // 320 KB

enum FwImageStatus: CustomStringConvertible {
    case ok
    case badExtension
    case fileTooLarge
    case invalidSignature
    case fileSizeMismatch
    case crcMismatch
    case readError

    var description: String {
        switch self {
        case .ok: return "OK"
        case .badExtension: return "BAD_EXTENSION"
        case .fileTooLarge: return "FILE_TOO_LARGE"
        case .invalidSignature: return "INVALID_SIGNATURE"
        case .fileSizeMismatch: return "FILE_SIZE_MISMATCH"
        case .crcMismatch: return "CRC_MISMATCH"
        case .readError: return "READ_ERROR"
        }
    }
}

struct FwImageInfo {
    let fileName: String
    let fileSize: Int
    let version: String
    let codeSize: UInt32
}

final class FwImageReader {
    private(set) var imageBytes = Data()
    private(set) var imageInfo: FwImageInfo?

    func readAndValidate(url: URL) -> FwImageStatus {
        let fileName = url.lastPathComponent

        let ext = url.pathExtension.lowercased()
        if ext != "img" { return .badExtension }

        guard let data = try? Data(contentsOf: url) else { return .readError }

        if data.count > maxFwImageSize { return .fileTooLarge }

        return validateBytes(data, fileName: fileName)
    }

    func readAndValidateBytes(_ bytes: Data, fileName: String) -> FwImageStatus {
        let ext = (fileName as NSString).pathExtension.lowercased()
        if ext != "img" { return .badExtension }

        if bytes.count > maxFwImageSize { return .fileTooLarge }

        return validateBytes(bytes, fileName: fileName)
    }

    private func validateBytes(_ bytes: Data, fileName: String) -> FwImageStatus {
        // Validate signature: 0x70, 0x61
        guard bytes.count >= suotaHeaderSize,
              bytes[0] == 0x70,
              bytes[1] == 0x61 else {
            return .invalidSignature
        }

        // Validate code_size at offset 4 == (fileSize - 36)
        let codeSize = readUInt32LE(bytes, offset: 4)
        guard codeSize == UInt32(bytes.count - suotaHeaderSize) else {
            return .fileSizeMismatch
        }

        // Validate CRC at offset 8
        let imageCrc = readUInt32LE(bytes, offset: 8)
        let calcCrc = suotaUpdateCrc(0xFFFFFFFF, data: bytes, offset: suotaHeaderSize, length: Int(codeSize)) ^ 0xFFFFFFFF
        guard imageCrc == calcCrc else {
            return .crcMismatch
        }

        // Extract version string from header bytes 12-27
        let versionData = bytes[12..<28]
        let version = String(data: versionData, encoding: .utf8)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0")) ?? ""

        imageBytes = bytes
        imageInfo = FwImageInfo(fileName: fileName, fileSize: bytes.count, version: version, codeSize: codeSize)
        return .ok
    }

    func clear() {
        imageBytes = Data()
        imageInfo = nil
    }

    private func readUInt32LE(_ data: Data, offset: Int) -> UInt32 {
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let b3 = UInt32(data[offset + 3])
        return (b3 << 24) | (b2 << 16) | (b1 << 8) | b0
    }
}

// MARK: - CRC32

private let crc32Tab: [UInt32] = {
    var table = [UInt32](repeating: 0, count: 256)
    for i in 0..<256 {
        var crc = UInt32(i)
        for _ in 0..<8 {
            if crc & 1 != 0 {
                crc = (crc >> 1) ^ 0xEDB88320
            } else {
                crc = crc >> 1
            }
        }
        table[i] = crc
    }
    return table
}()

private func suotaUpdateCrc(_ crcIn: UInt32, data: Data, offset: Int, length: Int) -> UInt32 {
    var crc = crcIn
    for j in 0..<length {
        let idx = Int((crc ^ UInt32(data[j + offset])) & 0xFF)
        crc = crc32Tab[idx] ^ (crc >> 8)
    }
    return crc
}
