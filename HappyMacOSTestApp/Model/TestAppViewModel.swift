import Foundation
import SwiftUI
import HappyPlatformAPI

struct ConnectedRingInfo: Identifiable {
    var id: Int32 { connId }
    let connId: Int32
    let name: String
    let address: String
    var state: HpyConnectionState
    var deviceInfo: DeviceInfoData?
    var lastStatus: DeviceStatusData?
    var extendedStatus: ResponseParser.ExtendedDeviceStatus?
    var daqConfig: DaqConfigData?
    var fingerDetectionOn: Bool? = true
    var isDownloading: Bool = false
    var downloadProgress: Int = 0
    var downloadTotal: Int = 0
    var sessionDownloadProgress: Int = 0
    var sessionDownloadTotal: Int = 0
    var downloadTransport: String = ""
    var totalFramesDownloaded: Int = 0
    var batchStartMs: TimeInterval = 0
    var commandStatus: String?
    var downloadState: String?
    var isFwUpdating: Bool = false
    var fwUpdateState: String?
    var fwBlocksSent: Int = 0
    var fwBlocksTotal: Int = 0
    var fwStartMs: TimeInterval = 0
    var fwUploadDoneMs: TimeInterval = 0
    var isReconnecting: Bool = false
    var reconnectRetryCount: Int = 0
    var ringSize: Int = 0
    var ringColor: Int = 0
    var syncFrameCount: UInt32 = 0
    var syncFrameReboots: UInt32 = 0
    var rssiWarningValue: Int?
    var lastRssi: Int?
}

struct LogEntry: Identifiable {
    static var counter: Int64 = 0
    let id: Int64
    let connId: Int32
    let message: String
    let timestamp: Date

    init(connId: Int32, message: String) {
        LogEntry.counter += 1
        self.id = LogEntry.counter
        self.connId = connId
        self.message = message
        self.timestamp = Date()
    }
}

@MainActor
final class TestAppViewModel: ObservableObject {

    let api: HappyPlatformApi
    private let shim: MacBleShim
    private let flowCollector = FlowCollector()

    @Published var connectedRings = [Int32: ConnectedRingInfo]()
    @Published var connectionLogs = [Int32: [LogEntry]]()
    private var logDeviceSerial = [Int32: String]()  // connId → serial of device in log buffer
    private var logDeviceName = [Int32: String]()     // connId → name for folder when saving
    @Published var faultCounts = [Int32: Int]()
    @Published var ncfCounts = [Int32: Int]()
    @Published var retryCounts = [Int32: Int]()
    @Published var reconnectionCounts = [Int32: Int]()
    // Track fc of first frame in current logging interval (from actual frame data)
    private var intervalStartFc = [Int32: Int]()
    @Published var discoveredDevices = [ScannedDeviceInfo]()
    @Published var isScanning: Bool = false

    // FW Update (per-connection)
    @Published var fwImageInfoMap = [Int32: FwImageInfo]()
    var fwImageBytesMap = [Int32: Data]()

    // Memfault
    @Published var memfaultReleases = [MemfaultRelease]()
    @Published var memfaultLoading = false
    @Published var memfaultError: String?
    @Published var memfaultHasMore = true
    @Published var memfaultDownloadingConnId: Int32? = nil
    @Published var memfaultDownloadVersion: String?
    private var memfaultNextPage = 1
    private let memfaultClient = MemfaultClient()

    // Scan error message (e.g. notification subscribe timeout)
    @Published var scanErrorMessage: String?
    private var scanErrorClearTask: Task<Void, Never>?

    // Settings
    let settingsRepo = SettingsRepository()
    @Published var globalSettings: AppSettings = .default
    private var ringOverrides = [String: AppSettings]()  // address → overrides

    // RSSI pre-flight check
    private var pendingRssiAction = [Int32: String]()
    @Published var rssiAlertConnId: Int32?
    @Published var rssiAlertValue: Int = 0

    // Sync Frame sheet trigger (per-connection)
    private var pendingSyncFrameConnId: Int32? = nil
    @Published var syncFrameSheetConnId: Int32? = nil

    // RSSI polling timers (10s interval per connection)
    private var rssiPollingTasks = [Int32: Task<Void, Never>]()
    private var lastLoggedRssi = [Int32: Int]()

    // Track connections that entered reconnecting (survives intermediate states)
    private var reconnectingConnIds = Set<Int32>()

    // Status clear timers
    private var statusClearTasks = [Int32: Task<Void, Never>]()

    // Per-connection frame writers
    private var frameWriters = [Int32: FrameWriter]()

    init(api: HappyPlatformApi, shim: MacBleShim) {
        self.api = api
        self.shim = shim

        // Watch events — use DispatchQueue.main for strict FIFO ordering
        // (independent Task instances are not guaranteed FIFO on MainActor)
        let eventsHandle = api.watchEvents { [weak self] event in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { [weak self] in
                    self?.handleEvent(event)
                }
            }
        }
        flowCollector.add(eventsHandle)

        // Watch discovered devices
        let devicesHandle = FlowWrappersKt.watchDevices(api.discoveredDevices) { [weak self] devices in
            Task { @MainActor [weak self] in
                self?.discoveredDevices = devices as? [ScannedDeviceInfo] ?? []
            }
        }
        flowCollector.add(devicesHandle)

        // Watch scanning state
        let scanHandle = FlowWrappersKt.watchBool(api.isScanning) { [weak self] scanning in
            Task { @MainActor [weak self] in
                self?.isScanning = scanning as? Bool ?? false
            }
        }
        flowCollector.add(scanHandle)
    }

    deinit {
        flowCollector.cancelAll()
        rssiPollingTasks.values.forEach { $0.cancel() }
        frameWriters.values.forEach { $0.destroy() }
    }

    // MARK: - Scanning

    func toggleScan() {
        if isScanning {
            api.scanStop()
        } else {
            api.scanStart()
        }
    }

    // MARK: - Connection

    func connect(device: ScannedDeviceInfo) {
        clearScanError()
        let connId = api.connect(deviceHandle: device.deviceHandle)
        guard connId != -1 else { return }
        connectedRings[connId] = ConnectedRingInfo(
            connId: connId,
            name: device.name,
            address: device.address,
            state: .connecting,
            ringSize: Int(device.ringSize),
            ringColor: Int(device.ringColor),
            lastRssi: Int(device.rssi)
        )
    }

    func disconnect(connId: Int32) {
        stopRssiPolling(connId: connId)
        lastLoggedRssi.removeValue(forKey: connId)
        intervalStartFc.removeValue(forKey: connId)
        frameWriters.removeValue(forKey: connId)?.destroy()
        fwImageInfoMap.removeValue(forKey: connId)
        fwImageBytesMap.removeValue(forKey: connId)
        // NOTE: logDeviceSerial and logDeviceName are intentionally preserved across
        // disconnect so the DeviceInfo handler can detect a device change on slot reuse
        // and auto-save/clear the old log.
        faultCounts.removeValue(forKey: connId)
        ncfCounts.removeValue(forKey: connId)
        retryCounts.removeValue(forKey: connId)
        reconnectionCounts.removeValue(forKey: connId)
        let _ = api.disconnect(connId: connId)
        connectedRings.removeValue(forKey: connId)
    }

    func disconnectAll() {
        let ids = Array(connectedRings.keys)
        for id in ids {
            disconnect(connId: id)
        }
    }

    // MARK: - Commands

    func identify(connId: Int32) {
        clearCommandStatus(connId: connId)
        let _ = api.identify(connId: connId)
    }

    func getDeviceStatus(connId: Int32) {
        clearCommandStatus(connId: connId)
        let _ = api.getDeviceStatus(connId: connId)
        let _ = api.getExtendedDeviceStatus(connId: connId)
    }

    func getDaqConfig(connId: Int32) {
        clearCommandStatus(connId: connId)
        let _ = api.getDaqConfig(connId: connId)
        let _ = api.getDeviceStatus(connId: connId)
    }

    func setDaqConfig(connId: Int32, config: DaqConfigData, applyImmediately: Bool) {
        clearCommandStatus(connId: connId)
        let _ = api.setDaqConfig(connId: connId, config: config, applyImmediately: applyImmediately)
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            let _ = api.getDaqConfig(connId: connId)
        }
    }

    func startDaq(connId: Int32) {
        clearCommandStatus(connId: connId)
        let _ = api.startDaq(connId: connId)
    }

    func stopDaq(connId: Int32) {
        clearCommandStatus(connId: connId)
        let _ = api.stopDaq(connId: connId)
    }

    func toggleFingerDetection(connId: Int32) {
        clearCommandStatus(connId: connId)
        guard let ring = connectedRings[connId] else { return }
        let currentlyOn = ring.fingerDetectionOn ?? false
        let _ = api.setFingerDetection(connId: connId, enable: !currentlyOn)
        updateRing(connId: connId) { $0.fingerDetectionOn = !currentlyOn }
    }

    func getSyncFrame(connId: Int32) {
        clearCommandStatus(connId: connId)
        pendingSyncFrameConnId = connId
        let _ = api.getSyncFrame(connId: connId)
    }

    func setSyncFrame(connId: Int32, frameCount: UInt32, reboots: UInt32) {
        clearCommandStatus(connId: connId)
        let _ = api.setSyncFrame(connId: connId, frameCount: frameCount, reboots: reboots)
    }

    func assertDevice(connId: Int32) {
        clearCommandStatus(connId: connId)
        let _ = api.assert(connId: connId)
    }

    // MARK: - Download

    func requestStartDownload(connId: Int32) {
        updateRing(connId: connId) { $0.rssiWarningValue = nil }
        pendingRssiAction[connId] = "download"
        let _ = api.readRssi(connId: connId)
    }

    private func proceedStartDownload(connId: Int32) {
        let deviceId = connectedRings[connId]?.name
        let writer = FrameWriter()
        writer.ensureFileOpen(deviceId: deviceId)
        frameWriters[connId] = writer
        updateRing(connId: connId) {
            $0.downloadProgress = 0
            $0.downloadTotal = 0
        }
        addLog(connId: connId, message: "HPY2 file: \(writer.filePath ?? "?")")
        let _ = api.startDownload(connId: connId)
    }

    func startDownload(connId: Int32) {
        proceedStartDownload(connId: connId)
    }

    func stopDownload(connId: Int32) {
        let _ = api.stopDownload(connId: connId)
        intervalStartFc.removeValue(forKey: connId)
        if let writer = frameWriters.removeValue(forKey: connId) {
            addLog(connId: connId, message: "HPY2 file closed: \(writer.totalFramesWritten) frames written")
            writer.destroy()
        }
        updateRing(connId: connId) { $0.rssiWarningValue = nil }
    }

    // MARK: - FW Update

    func loadFwImage(url: URL, connId: Int32) -> String? {
        let reader = FwImageReader()
        let status = reader.readAndValidate(url: url)
        if status != .ok { return "Image validation failed: \(status)" }
        fwImageBytesMap[connId] = reader.imageBytes
        fwImageInfoMap[connId] = reader.imageInfo
        return nil
    }

    func clearFwImage(connId: Int32) {
        fwImageBytesMap.removeValue(forKey: connId)
        fwImageInfoMap.removeValue(forKey: connId)
    }

    func requestStartFwUpdate(connId: Int32) {
        pendingRssiAction[connId] = "fwUpdate"
        let _ = api.readRssi(connId: connId)
    }

    private func proceedStartFwUpdate(connId: Int32) {
        guard let bytes = fwImageBytesMap[connId] else { return }
        let kba = bytes.toKotlinByteArray()
        let _ = api.startFwUpdate(connId: connId, imageBytes: kba)
    }

    func startFwUpdate(connId: Int32) {
        proceedStartFwUpdate(connId: connId)
    }

    func dismissRssiAlert() {
        rssiAlertConnId = nil
    }

    func cancelFwUpdate(connId: Int32) {
        let _ = api.cancelFwUpdate(connId: connId)
        updateRing(connId: connId) {
            $0.isFwUpdating = false
            $0.fwUpdateState = "Aborted/Recovering..."
            $0.fwBlocksSent = 0
            $0.fwBlocksTotal = 0
        }
    }

    // MARK: - Memfault

    func fetchMemfaultReleases() {
        memfaultReleases = []
        memfaultError = nil
        memfaultHasMore = true
        memfaultNextPage = 1
        loadMoreMemfaultReleases()
    }

    func loadMoreMemfaultReleases() {
        guard !memfaultLoading, memfaultHasMore else { return }
        memfaultLoading = true
        memfaultError = nil

        let page = memfaultNextPage
        Task {
            do {
                let response = try await memfaultClient.fetchReleases(page: page)
                memfaultReleases += response.releases
                memfaultHasMore = page < response.paging.pageCount
                memfaultNextPage += 1
            } catch {
                memfaultError = error.localizedDescription
            }
            memfaultLoading = false
        }
    }

    func downloadMemfaultRelease(version: String, connId: Int32) {
        memfaultDownloadingConnId = connId
        memfaultDownloadVersion = version
        memfaultError = nil

        Task {
            do {
                addLog(connId: connId, message: "Memfault: fetching artifact URL for \(version)...")
                let artifactUrl = try await memfaultClient.fetchArtifactUrl(version: version)

                addLog(connId: connId, message: "Memfault: downloading \(version)...")
                let bytes = try await memfaultClient.downloadArtifact(url: artifactUrl)

                addLog(connId: connId, message: "Memfault: validating \(version) (\(bytes.count) bytes)...")
                let reader = FwImageReader()
                let status = reader.readAndValidateBytes(bytes, fileName: "\(version).img")
                if status != .ok {
                    memfaultError = "Image validation failed: \(status)"
                    addLog(connId: connId, message: "Memfault: validation failed for \(version): \(status)")
                    memfaultDownloadingConnId = nil
                    memfaultDownloadVersion = nil
                    return
                }

                fwImageBytesMap[connId] = reader.imageBytes
                fwImageInfoMap[connId] = reader.imageInfo
                addLog(connId: connId, message: "Memfault FW image: \(reader.imageInfo?.fileName ?? "?"), version=\(reader.imageInfo?.version ?? "?"), \(reader.imageInfo?.fileSize ?? 0) bytes")
            } catch {
                memfaultError = error.localizedDescription
                addLog(connId: connId, message: "Memfault: error downloading \(version): \(error.localizedDescription)")
            }
            memfaultDownloadingConnId = nil
            memfaultDownloadVersion = nil
        }
    }

    // MARK: - File Management

    func listHpy2Files(deviceId: String? = nil) -> [URL] {
        let folder = if let deviceId { FrameWriter.hpy2Folder(forDevice: deviceId) } else { FrameWriter.hpy2Folder }
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files.filter { $0.pathExtension == "hpy2" }
            .sorted { (a, b) in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                return da > db
            }
    }

    func listEventLogFiles(deviceId: String? = nil) -> [URL] {
        let folder = if let deviceId { Self.eventLogFolder.appendingPathComponent(deviceId) } else { Self.eventLogFolder }
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files.filter { $0.pathExtension == "txt" }
            .sorted { (a, b) in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                return da > db
            }
    }

    static var eventLogFolder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("BLE_EVENT_LOGS")
    }

    func saveEventLog(connId: Int32) -> URL? {
        let deviceName = connectedRings[connId]?.name ?? logDeviceName[connId]
        return saveEventLogForDevice(connId: connId, deviceName: deviceName)
    }

    @discardableResult
    private func saveEventLogForDevice(connId: Int32, deviceName: String?) -> URL? {
        guard let logs = connectionLogs[connId], !logs.isEmpty else { return nil }

        let folder = if let deviceName { Self.eventLogFolder.appendingPathComponent(deviceName) } else { Self.eventLogFolder }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        let prefix = deviceName.map { "\($0.lowercased())_" } ?? ""
        let fileName = "\(prefix)event_log_\(timestamp).txt"
        let fileUrl = folder.appendingPathComponent(fileName)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss.SSS"

        var text = ""
        for entry in logs {
            let time = timeFormatter.string(from: entry.timestamp)
            text += "\(time)  \(entry.message)\n"
        }

        try? text.write(to: fileUrl, atomically: true, encoding: .utf8)
        addLog(connId: connId, message: "Event log auto-saved: \(fileName) (\(logs.count) entries)")
        return fileUrl
    }

    // MARK: - Event Handling

    private func handleEvent(_ event: HpyEvent) {
        if let e = event as? HpyEvent.StateChanged {
            let dlState: String? = {
                switch e.state {
                case .downloading: return "Downloading"
                case .waiting: return "Waiting"
                default: return nil
                }
            }()
            let reconnecting = e.state == .reconnecting ||
                (e.state == .fwUpdateRebooting && e.retryCount > 0)
            updateRing(connId: e.connId) { ring in
                ring.state = e.state
                ring.isDownloading = (e.state == .downloading || e.state == .waiting)
                ring.isFwUpdating = (e.state == .fwUpdating || e.state == .fwUpdateRebooting)
                if e.state == .downloading {
                    ring.batchStartMs = Date().timeIntervalSince1970 * 1000
                    ring.rssiWarningValue = nil
                }
                ring.downloadState = dlState
                if e.state == .ready { ring.fwUpdateState = nil }
                ring.isReconnecting = reconnecting
                ring.reconnectRetryCount = Int(e.retryCount)
            }
            if reconnecting {
                reconnectingConnIds.insert(e.connId)
            }
            if e.state == .ready {
                startRssiPolling(connId: e.connId)
                if reconnectingConnIds.remove(e.connId) != nil {
                    reconnectionCounts[e.connId, default: 0] += 1
                }
            }
            let maxRetries = effectiveMaxRetries(connId: e.connId)
            let retryStr = e.retryCount > 0 ? " (retry \(e.retryCount)/\(maxRetries))" : ""
            addLog(connId: e.connId, message: "State -> \(e.state)\(retryStr)")

            if e.state == .disconnected {
                reconnectingConnIds.remove(e.connId)
                stopRssiPolling(connId: e.connId)
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    connectedRings.removeValue(forKey: e.connId)
                }
            }
        }
        else if let e = event as? HpyEvent.DeviceInfo {
            // Auto-save and clear log if device changed on this slot
            if let oldSerial = logDeviceSerial[e.connId],
               oldSerial != e.info.serialNumber,
               let logs = connectionLogs[e.connId], !logs.isEmpty {
                let oldName = logDeviceName[e.connId]
                saveEventLogForDevice(connId: e.connId, deviceName: oldName)
                connectionLogs[e.connId] = []
                faultCounts[e.connId] = 0
                ncfCounts[e.connId] = 0
                retryCounts[e.connId] = 0
                reconnectionCounts[e.connId] = 0
                intervalStartFc.removeValue(forKey: e.connId)
            }
            logDeviceSerial[e.connId] = e.info.serialNumber
            logDeviceName[e.connId] = connectedRings[e.connId]?.name

            updateRing(connId: e.connId) { $0.deviceInfo = e.info }
            addLog(connId: e.connId, message: "DeviceInfo: serial=\(e.info.serialNumber), fw=\(e.info.fwVersion), model=\(e.info.modelNumber)")
        }
        else if let e = event as? HpyEvent.DeviceStatus {
            setCommandStatus(connId: e.connId, status: "(\(cmdHex(0x1E))) Success")
            updateRing(connId: e.connId) {
                $0.lastStatus = e.status
                $0.fingerDetectionOn = !e.status.needsSetFingerDetection
            }
            let s = e.status
            addLog(connId: e.connId, message: "DevStatus: \(s.phyString), DAQ=\(s.daqString), SOC=\(s.soc)%, unsynced=\(s.unsyncedFrames), sync=\(s.syncString), notif=\(s.notifSenderString), CI=\(s.bleCiValue)ms, inprog=\(s.bleCiUpdateInProgress)")
        }
        else if let e = event as? HpyEvent.ExtendedDeviceStatus {
            setCommandStatus(connId: e.connId, status: "(\(cmdHex(0x38))) Success")
            updateRing(connId: e.connId) { $0.extendedStatus = e.extStatus }
            addLog(connId: e.connId, message: "ExtDevStatus: bp=\(e.extStatus.bpStateString), timeLeft=\(e.extStatus.bpTimeLeftSec)s")
        }
        else if let e = event as? HpyEvent.DaqConfig {
            setCommandStatus(connId: e.connId, status: "(\(cmdHex(0x2B))) Success")
            updateRing(connId: e.connId) { $0.daqConfig = e.config }
            addLog(connId: e.connId, message: "DaqConfig: mode=\(e.config.modeString), version=\(e.config.version)")
        }
        else if let e = event as? HpyEvent.SyncFrame {
            setCommandStatus(connId: e.connId, status: "(\(cmdHex(0x1A))) Success")
            updateRing(connId: e.connId) {
                $0.syncFrameCount = UInt32(e.frameCount)
                $0.syncFrameReboots = UInt32(e.reboots)
            }
            if pendingSyncFrameConnId == e.connId {
                pendingSyncFrameConnId = nil
                syncFrameSheetConnId = e.connId
            }
            addLog(connId: e.connId, message: "SyncFrame: boot\(e.reboots):frame\(e.frameCount)")
        }
        else if let e = event as? HpyEvent.CommandResult {
            setCommandStatus(connId: e.connId, status: "(\(cmdHex(Int(e.commandId)))) Success")
            addLog(connId: e.connId, message: "CMD 0x\(String(format: "%02X", UInt8(bitPattern: e.commandId))) response [\(e.rawBytes.size)b]")
        }
        else if let e = event as? HpyEvent.DebugMessage {
            addLog(connId: e.connId, message: "DEBUG: \(String(data: e.message.toSwiftData(), encoding: .utf8) ?? "?")")
        }
        else if let e = event as? HpyEvent.Error {
            let status = (e.code == .commandTimeout) ? "Timeout" : "Error"
            setCommandStatus(connId: e.connId, status: status)
            addLog(connId: e.connId, message: "ERROR [\(e.code)]: \(e.message)")
            if e.code == .fwTransferFail {
                updateRing(connId: e.connId) {
                    $0.isFwUpdating = false
                    $0.fwUpdateState = nil
                    $0.fwBlocksSent = 0
                    $0.fwBlocksTotal = 0
                }
            }
            if e.code == .notificationSubscribeFail {
                let deviceName = connectedRings[e.connId]?.name ?? "Unknown"
                setScanError("Connection failed for \(deviceName): notification subscription timed out")
            }
        }
        else if let e = event as? HpyEvent.Log {
            addLog(connId: e.connId, message: e.message)
        }
        else if let e = event as? HpyEvent.DownloadBatch {
            let ring = connectedRings[e.connId]
            let startMs = ring?.batchStartMs ?? 0
            let nowMs = Date().timeIntervalSince1970 * 1000
            let elapsedMs = startMs > 0 ? nowMs - startMs : 0
            let throughput: String = elapsedMs > 0
                ? String(format: "%.1f KB/s", Double(e.framesInBatch) * 4096.0 / elapsedMs)
                : "N/A"
            updateRing(connId: e.connId) {
                $0.totalFramesDownloaded = Int(e.totalFramesDownloaded)
                $0.batchStartMs = nowMs
            }
            let rssiStr = e.rssi != nil ? ", RSSI=\(e.rssi!.intValue)" : ""
            let retryStr = e.retryCount > 0 ? ", retries=\(e.retryCount)" : ""
            let ncfStr = e.ncfCount > 0 ? ", NCF=\(e.ncfCount)" : ""
            addLog(connId: e.connId, message: "DownloadBatch: \(e.framesInBatch) frames, CRC=\(e.crcValid), \(throughput), \(e.transport)\(rssiStr)\(retryStr)\(ncfStr)")
            if e.ncfCount > 0 { ncfCounts[e.connId, default: 0] += Int(e.ncfCount) }
            if e.retryCount > 0 { retryCounts[e.connId, default: 0] += 1 }
        }
        else if let e = event as? HpyEvent.DownloadProgress {
            updateRing(connId: e.connId) {
                // framesDownloaded/framesTotal are already cumulative from the library
                $0.downloadProgress = Int(e.framesDownloaded)
                $0.downloadTotal = Int(e.framesTotal)
                $0.sessionDownloadProgress = Int(e.sessionFramesDownloaded)
                $0.sessionDownloadTotal = Int(e.sessionFramesTotal)
                $0.downloadTransport = e.transport
            }
            if intervalStartFc[e.connId] == nil {
                intervalStartFc[e.connId] = Int(e.currentFc)
            }
            if e.sessionFramesDownloaded % 8 == 0 || e.sessionFramesDownloaded == e.sessionFramesTotal {
                let startFc = intervalStartFc.removeValue(forKey: e.connId) ?? Int(e.currentFc)
                let rebootFlag = Int(e.currentFc) < startFc ? " *" : ""
                addLog(connId: e.connId, message: "D/L Prog: \(e.sessionFramesDownloaded)/\(e.sessionFramesTotal) (\(e.transport)) (fc:\(startFc)-\(e.currentFc))\(rebootFlag)")
            }
        }
        else if let e = event as? HpyEvent.DownloadFrame {
            frameWriters[e.connId]?.writeFrame(e.frameData.toSwiftData())
        }
        else if let e = event as? HpyEvent.DownloadInterrupted {
            if let writer = frameWriters[e.connId], e.framesToDiscard > 0 {
                writer.discardFrames(Int(e.framesToDiscard))
                addLog(connId: e.connId, message: "Download interrupted: discarding \(e.framesToDiscard) partial-batch frames")
            }
        }
        else if let e = event as? HpyEvent.DownloadComplete {
            addLog(connId: e.connId, message: "DownloadComplete: \(e.sessionFrames) frames")
            let cumulative = connectedRings[e.connId]?.downloadProgress ?? 0
            addLog(connId: e.connId, message: "Cumulative: \(cumulative) frames")
        }
        else if let e = event as? HpyEvent.FwUpdateProgress {
            let fwState = e.bytesWritten < e.totalBytes ? "Uploading" : "Finalizing"
            let now = Date().timeIntervalSince1970 * 1000
            updateRing(connId: e.connId) {
                $0.isFwUpdating = true
                $0.fwUpdateState = fwState
                $0.fwBlocksSent = Int(e.bytesWritten) / 240
                $0.fwBlocksTotal = Int(e.totalBytes) / 240
                if $0.fwStartMs == 0 { $0.fwStartMs = now }
                if fwState == "Finalizing" && $0.fwUploadDoneMs == 0 { $0.fwUploadDoneMs = now }
            }
            if Int(e.bytesWritten) % (240 * 25) == 0 || e.bytesWritten == e.totalBytes {
                addLog(connId: e.connId, message: "FW: \(Int(e.bytesWritten) / 240)/\(Int(e.totalBytes) / 240) blocks")
            }
        }
        else if let e = event as? HpyEvent.FwUpdateComplete {
            let ring = connectedRings[e.connId]
            let now = Date().timeIntervalSince1970 * 1000
            let uploadSec = (ring != nil && ring!.fwStartMs > 0 && ring!.fwUploadDoneMs > 0)
                ? Int((ring!.fwUploadDoneMs - ring!.fwStartMs) / 1000) : 0
            let totalSec = (ring != nil && ring!.fwStartMs > 0)
                ? Int((now - ring!.fwStartMs) / 1000) : 0
            updateRing(connId: e.connId) {
                $0.isFwUpdating = false
                $0.fwUpdateState = nil
                $0.fwBlocksSent = 0
                $0.fwBlocksTotal = 0
                $0.fwStartMs = 0
                $0.fwUploadDoneMs = 0
            }
            addLog(connId: e.connId, message: "FW update complete: \(e.newFwVersion) (upload: \(uploadSec)s, total: \(totalSec)s)")
        }
        else if let e = event as? HpyEvent.RssiRead {
            updateRing(connId: e.connId) { $0.lastRssi = Int(e.rssi) }
            let rssi = Int(e.rssi)
            let minRssi = effectiveMinRssi(connId: e.connId)
            let action = pendingRssiAction.removeValue(forKey: e.connId)
            if action == "download" {
                addLog(connId: e.connId, message: "RSSI: \(rssi) dBm")
                lastLoggedRssi[e.connId] = rssi
                if e.rssi > minRssi {
                    proceedStartDownload(connId: e.connId)
                } else {
                    rssiAlertConnId = e.connId
                    rssiAlertValue = rssi
                }
            } else if action == "fwUpdate" {
                addLog(connId: e.connId, message: "RSSI: \(rssi) dBm")
                lastLoggedRssi[e.connId] = rssi
                if e.rssi > minRssi {
                    proceedStartFwUpdate(connId: e.connId)
                } else {
                    rssiAlertConnId = e.connId
                    rssiAlertValue = rssi
                }
            } else {
                // From library auto-check or 10s poll
                let ring = connectedRings[e.connId]
                if ring?.state == .waiting && e.rssi <= minRssi {
                    updateRing(connId: e.connId) { $0.rssiWarningValue = rssi }
                } else {
                    updateRing(connId: e.connId) { $0.rssiWarningValue = nil }
                }
                let prev = lastLoggedRssi[e.connId]
                let crossedBelow = prev != nil && prev! > minRssi && rssi <= minRssi
                let crossedAbove = prev != nil && prev! <= minRssi && rssi > minRssi
                let bigDelta = prev == nil || abs(rssi - prev!) >= 10
                if crossedBelow || crossedAbove || bigDelta {
                    let suffix: String
                    if crossedBelow { suffix = " (below threshold \(minRssi) dBm)" }
                    else if crossedAbove { suffix = " (above threshold \(minRssi) dBm)" }
                    else { suffix = "" }
                    addLog(connId: e.connId, message: "RSSI: \(rssi) dBm\(suffix)")
                    lastLoggedRssi[e.connId] = rssi
                }
            }
        }
        else if let e = event as? HpyEvent.MemfaultComplete {
            addLog(connId: e.connId, message: "Memfault drain complete: \(e.chunksDownloaded) new chunks")
            let ring = connectedRings[e.connId]
            if let serial = ring?.deviceInfo?.serialNumber {
                uploadMemfaultChunks(connId: e.connId, serial: serial)
            }
        }
    }

    private func uploadMemfaultChunks(connId: Int32, serial: String) {
        let chunks = api.getMemfaultChunks(connId: connId)
        guard !chunks.isEmpty else { return }
        let swiftChunks = chunks.compactMap { ($0 as? KotlinByteArray)?.toSwiftData() }
        let totalBytes = swiftChunks.reduce(0) { $0 + $1.count }
        addLog(connId: connId, message: "Memfault: uploading \(swiftChunks.count) chunks (\(totalBytes) bytes)...")

        Task {
            do {
                let code = try await memfaultClient.uploadChunks(deviceSerial: serial, chunks: swiftChunks)
                if code == 202 {
                    api.markMemfaultChunksUploaded(connId: connId)
                    addLog(connId: connId, message: "Memfault: upload complete (HTTP 202)")
                } else {
                    addLog(connId: connId, message: "Memfault: upload failed (HTTP \(code)), chunks retained")
                }
            } catch {
                addLog(connId: connId, message: "Memfault: upload failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    private func startRssiPolling(connId: Int32) {
        rssiPollingTasks[connId]?.cancel()
        rssiPollingTasks[connId] = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                guard !Task.isCancelled else { break }
                let _ = self?.api.readRssi(connId: connId)
            }
        }
    }

    private func stopRssiPolling(connId: Int32) {
        rssiPollingTasks.removeValue(forKey: connId)?.cancel()
    }

    private func cmdHex(_ cmd: Int) -> String {
        String(format: "%02X", UInt8(cmd & 0xFF))
    }

    private func setScanError(_ message: String) {
        scanErrorMessage = message
        scanErrorClearTask?.cancel()
        scanErrorClearTask = Task {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            if !Task.isCancelled {
                scanErrorMessage = nil
                scanErrorClearTask = nil
            }
        }
    }

    func clearScanError() {
        scanErrorClearTask?.cancel()
        scanErrorClearTask = nil
        scanErrorMessage = nil
    }

    private func clearCommandStatus(connId: Int32) {
        statusClearTasks[connId]?.cancel()
        statusClearTasks.removeValue(forKey: connId)
        updateRing(connId: connId) { $0.commandStatus = nil }
    }

    private func setCommandStatus(connId: Int32, status: String) {
        updateRing(connId: connId) { $0.commandStatus = status }
        statusClearTasks[connId]?.cancel()
        statusClearTasks[connId] = Task {
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            if !Task.isCancelled {
                updateRing(connId: connId) { $0.commandStatus = nil }
                statusClearTasks.removeValue(forKey: connId)
            }
        }
    }

    private func updateRing(connId: Int32, transform: (inout ConnectedRingInfo) -> Void) {
        guard var ring = connectedRings[connId] else { return }
        transform(&ring)
        connectedRings[connId] = ring
    }

    func addLog(connId: Int32, message: String) {
        let entry = LogEntry(connId: connId, message: message)

        if connId >= 0 {
            var logs = connectionLogs[connId] ?? []
            logs.append(entry)
            if logs.count > 10000 { logs = Array(logs.suffix(10000)) }
            connectionLogs[connId] = logs

            if message.hasPrefix("ERROR") {
                faultCounts[connId, default: 0] += 1
            }
        }
    }

    // MARK: - Settings

    func loadSettings() {
        globalSettings = settingsRepo.loadGlobalSettings()
    }

    func updateGlobalSettings(_ settings: AppSettings) {
        globalSettings = settings
        settingsRepo.saveGlobalSettings(settings)
    }

    func effectiveSettings(forAddress address: String) -> AppSettings {
        return ringOverrides[address] ?? globalSettings
    }

    func getRingSettings(address: String) -> AppSettings {
        return settingsRepo.loadRingOverrides(address: address) ?? globalSettings
    }

    func updateRingSettings(address: String, settings: AppSettings) {
        ringOverrides[address] = settings
        settingsRepo.saveRingOverrides(address: address, settings: settings)
    }

    func resetRingSettings(address: String) {
        ringOverrides.removeValue(forKey: address)
        settingsRepo.clearRingOverrides(address: address)
    }

    func hasRingOverrides(address: String) -> Bool {
        return settingsRepo.loadRingOverrides(address: address) != nil
    }

    private func effectiveMinRssi(connId: Int32) -> Int32 {
        if let address = connectedRings[connId]?.address {
            return Int32(effectiveSettings(forAddress: address).minRssi)
        }
        return Int32(globalSettings.minRssi)
    }

    private func effectiveMaxRetries(connId: Int32) -> Int {
        if let address = connectedRings[connId]?.address {
            return effectiveSettings(forAddress: address).maxReconnectRetries
        }
        return globalSettings.maxReconnectRetries
    }
}
