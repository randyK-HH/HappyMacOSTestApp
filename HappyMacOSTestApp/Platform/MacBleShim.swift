import Foundation
import CoreBluetooth
import HappyPlatformAPI
import os.log

private let log = Logger(subsystem: "com.happyhealth.macostestapp", category: "MacBleShim")

// MARK: - UUID Constants

private let UUID_HPY_HCS        = CBUUID(string: "FF899C90-18AD-11EB-ADC1-0242AC120002")
private let UUID_HPY_CMD_RX     = CBUUID(string: "FF899F60-18AD-11EB-ADC1-0242AC120002")
private let UUID_HPY_CMD_TX     = CBUUID(string: "FF89A262-18AD-11EB-ADC1-0242AC120002")
private let UUID_HPY_STREAM_TX  = CBUUID(string: "FF89A366-18AD-11EB-ADC1-0242AC120002")
private let UUID_HPY_DEBUG_TX   = CBUUID(string: "FF89A438-18AD-11EB-ADC1-0242AC120002")
private let UUID_HPY_FRAME_TX   = CBUUID(string: "FF89A500-18AD-11EB-ADC1-0242AC120002")

private let UUID_DIS            = CBUUID(string: "180A")
private let UUID_DIS_SERIAL     = CBUUID(string: "2A25")
private let UUID_DIS_FW_VERSION = CBUUID(string: "2A26")
private let UUID_DIS_SW_VERSION = CBUUID(string: "2A28")
private let UUID_DIS_MANUFACTURER = CBUUID(string: "2A29")
private let UUID_DIS_MODEL      = CBUUID(string: "2A24")

private let UUID_SUOTA_SERVICE  = CBUUID(string: "D20697CB-FAB2-41F9-82C3-D36AF65FBB26")
private let UUID_SUOTA_MEM_DEV  = CBUUID(string: "D20697CC-FAB2-41F9-82C3-D36AF65FBB26")
private let UUID_SUOTA_GPIO_MAP = CBUUID(string: "D20697CD-FAB2-41F9-82C3-D36AF65FBB26")
private let UUID_SUOTA_MEM_INFO = CBUUID(string: "D20697CE-FAB2-41F9-82C3-D36AF65FBB26")
private let UUID_SUOTA_PATCH_LEN = CBUUID(string: "D20697CF-FAB2-41F9-82C3-D36AF65FBB26")
private let UUID_SUOTA_PATCH_DATA = CBUUID(string: "D20697D0-FAB2-41F9-82C3-D36AF65FBB26")
private let UUID_SUOTA_STATUS   = CBUUID(string: "D20697D1-FAB2-41F9-82C3-D36AF65FBB26")
private let UUID_SUOTA_L2CAP_PSM = CBUUID(string: "D20697D2-FAB2-41F9-82C3-D36AF65FBB26")
private let UUID_SUOTA_VERSION  = CBUUID(string: "D20697D3-FAB2-41F9-82C3-D36AF65FBB26")
private let UUID_SUOTA_MTU      = CBUUID(string: "D20697D4-FAB2-41F9-82C3-D36AF65FBB26")
private let UUID_SUOTA_PATCH_DATA_CHAR_SIZE = CBUUID(string: "D20697D5-FAB2-41F9-82C3-D36AF65FBB26")

private let charIdToUUID: [HpyCharId: (service: CBUUID, char: CBUUID)] = [
    .cmdRx:         (UUID_HPY_HCS, UUID_HPY_CMD_RX),
    .cmdTx:         (UUID_HPY_HCS, UUID_HPY_CMD_TX),
    .streamTx:      (UUID_HPY_HCS, UUID_HPY_STREAM_TX),
    .debugTx:       (UUID_HPY_HCS, UUID_HPY_DEBUG_TX),
    .frameTx:       (UUID_HPY_HCS, UUID_HPY_FRAME_TX),

    .disSerialNumber:     (UUID_DIS, UUID_DIS_SERIAL),
    .disFwVersion:        (UUID_DIS, UUID_DIS_FW_VERSION),
    .disSwVersion:        (UUID_DIS, UUID_DIS_SW_VERSION),
    .disManufacturerName: (UUID_DIS, UUID_DIS_MANUFACTURER),
    .disModelNumber:      (UUID_DIS, UUID_DIS_MODEL),

    .suotaMemDev:     (UUID_SUOTA_SERVICE, UUID_SUOTA_MEM_DEV),
    .suotaGpioMap:    (UUID_SUOTA_SERVICE, UUID_SUOTA_GPIO_MAP),
    .suotaMemInfo:    (UUID_SUOTA_SERVICE, UUID_SUOTA_MEM_INFO),
    .suotaPatchLen:   (UUID_SUOTA_SERVICE, UUID_SUOTA_PATCH_LEN),
    .suotaPatchData:  (UUID_SUOTA_SERVICE, UUID_SUOTA_PATCH_DATA),
    .suotaStatus:     (UUID_SUOTA_SERVICE, UUID_SUOTA_STATUS),
    .suotaL2capPsm:   (UUID_SUOTA_SERVICE, UUID_SUOTA_L2CAP_PSM),
    .suotaVersion:    (UUID_SUOTA_SERVICE, UUID_SUOTA_VERSION),
    .suotaMtu:        (UUID_SUOTA_SERVICE, UUID_SUOTA_MTU),
    .suotaPatchDataCharSize: (UUID_SUOTA_SERVICE, UUID_SUOTA_PATCH_DATA_CHAR_SIZE),
]

private let uuidToCharId: [CBUUID: HpyCharId] = {
    var map = [CBUUID: HpyCharId]()
    for (charId, loc) in charIdToUUID {
        map[loc.char] = charId
    }
    return map
}()

// MARK: - MacBleShim

final class MacBleShim: NSObject, PlatformBleShim, CBCentralManagerDelegate, CBPeripheralDelegate {

    var callback: ShimCallback?

    private var centralManager: CBCentralManager!
    private var peripherals = [Int32: CBPeripheral]()    // connId -> peripheral
    private var characteristics = [Int32: [CBUUID: CBCharacteristic]]()  // connId -> charUUID -> char
    private var l2capChannels = [Int32: CBL2CAPChannel]()
    private var l2capReceiveJobs = [Int32: DispatchWorkItem]()
    private let l2capQueue = DispatchQueue(label: "com.happyhealth.l2cap", qos: .userInitiated)
    private var lastManagerState: CBManagerState = .unknown

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - PlatformBleShim

    func scanStart() {
        guard centralManager.state == .poweredOn else {
            log.error("Cannot scan: Bluetooth not powered on (state=\(self.centralManager.state.rawValue))")
            return
        }
        log.info("Starting BLE scan with HCS filter")
        centralManager.scanForPeripherals(
            withServices: [UUID_HPY_HCS],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
    }

    func scanStop() {
        log.info("Stopping BLE scan")
        centralManager.stopScan()
    }

    func connect(connId: Int32, deviceHandle: Any) {
        guard let peripheral = deviceHandle as? CBPeripheral else {
            log.error("[conn\(connId)] connect: deviceHandle is not CBPeripheral")
            return
        }
        peripherals[connId] = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect(connId: Int32) {
        if let peripheral = peripherals[connId] {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        peripherals.removeValue(forKey: connId)
        characteristics.removeValue(forKey: connId)
    }

    func discoverServices(connId: Int32) {
        guard let peripheral = peripherals[connId] else { return }
        peripheral.discoverServices([UUID_HPY_HCS, UUID_DIS, UUID_SUOTA_SERVICE])
    }

    func writeCharacteristic(connId: Int32, charId: HpyCharId, data: KotlinByteArray, writeType: WriteType) {
        guard let peripheral = peripherals[connId],
              let loc = charIdToUUID[charId],
              let char = characteristics[connId]?[loc.char] else {
            log.error("[conn\(connId)] write: char not found for \(charId)")
            return
        }
        let swiftData = data.toSwiftData()
        let cbWriteType: CBCharacteristicWriteType = (writeType == .withResponse) ? .withResponse : .withoutResponse
        peripheral.writeValue(swiftData, for: char, type: cbWriteType)
    }

    func readCharacteristic(connId: Int32, charId: HpyCharId) {
        guard let peripheral = peripherals[connId],
              let loc = charIdToUUID[charId],
              let char = characteristics[connId]?[loc.char] else { return }
        peripheral.readValue(for: char)
    }

    func subscribeNotifications(connId: Int32, charId: HpyCharId, enable: Bool) {
        guard let peripheral = peripherals[connId],
              let loc = charIdToUUID[charId],
              let char = characteristics[connId]?[loc.char] else { return }
        peripheral.setNotifyValue(enable, for: char)
    }

    func requestMtu(connId: Int32, mtu: Int32) {
        // macOS negotiates MTU automatically; maximumWriteValueLength is not yet
        // accurate this early (returns default 20).  Pass through the requested
        // MTU so the log reflects the value the stack will actually use once
        // negotiation completes (confirmed by throughput measurements).
        callback?.onMtuChanged(connId: connId, mtu: mtu)
    }

    func readRssi(connId: Int32) {
        guard let peripheral = peripherals[connId] else { return }
        peripheral.readRSSI()
    }

    // MARK: - L2CAP

    func l2capOpen(connId: Int32, psm: Int32) {
        guard let peripheral = peripherals[connId] else {
            callback?.onL2capError(connId: connId, message: "No peripheral for connId=\(connId)")
            return
        }
        log.info("[conn\(connId)] Opening L2CAP channel PSM=\(psm)")
        peripheral.openL2CAPChannel(CBL2CAPPSM(psm))
    }

    func l2capStartReceiving(connId: Int32, expectedFrames: Int32) {
        guard let channel = l2capChannels[connId] else {
            callback?.onL2capError(connId: connId, message: "No L2CAP channel for connId=\(connId)")
            return
        }

        l2capReceiveJobs[connId]?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.l2capReceiveLoop(connId: connId, channel: channel, expectedFrames: Int(expectedFrames))
        }
        l2capReceiveJobs[connId] = workItem
        l2capQueue.async(execute: workItem)
    }

    private func l2capReceiveLoop(connId: Int32, channel: CBL2CAPChannel, expectedFrames: Int) {
        guard let inputStream = channel.inputStream else {
            callback?.onL2capError(connId: connId, message: "L2CAP input stream is nil")
            return
        }
        // Capture the work item locally — l2capClose() may remove it from the
        // dictionary on the main queue while this loop is running on l2capQueue.
        guard let workItem = l2capReceiveJobs[connId] else { return }

        let frameSize = 4096
        var buf0 = Data(count: frameSize)
        var buf1 = Data(count: frameSize)
        var bufState = 0
        var buf0Cnt = 0
        var buf1Cnt = 0
        var framesReceived = 0
        var runningCrc: UInt32 = 0xFFFFFFFF

        let readBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: 512)
        defer { readBuf.deallocate() }

        while !workItem.isCancelled {
            // Poll for available data so cancellation is checked promptly.
            // A blocking read() on a serial queue prevents subsequent work items
            // (e.g. a new receive loop after reconnection) from starting.
            while !inputStream.hasBytesAvailable {
                if workItem.isCancelled { return }
                Thread.sleep(forTimeInterval: 0.01)
            }
            let bytesRead = inputStream.read(readBuf, maxLength: 512)
            if bytesRead <= 0 { break }
            if bytesRead > 512 {
                log.error("[conn\(connId)] L2CAP read returned \(bytesRead) bytes (max 512), aborting")
                callback?.onL2capError(connId: connId, message: "L2CAP read overflow (\(bytesRead) bytes)")
                return
            }

            var offset = 0
            var remaining = bytesRead

            while remaining > 0 {
                if framesReceived >= expectedFrames {
                    // Accumulate CRC packet (5 bytes)
                    let residualCnt = (bufState == 0) ? buf0Cnt : buf1Cnt
                    let toCopy = min(remaining, 5 - residualCnt)
                    if toCopy > 0 {
                        let bufCnt = (bufState == 0) ? buf0Cnt : buf1Cnt
                        let bufSize = (bufState == 0) ? buf0.count : buf1.count
                        if bufCnt + toCopy > bufSize {
                            log.error("[conn\(connId)] L2CAP CRC replaceSubrange out of bounds: cnt=\(bufCnt) toCopy=\(toCopy) bufSize=\(bufSize)")
                            callback?.onL2capError(connId: connId, message: "L2CAP CRC buffer overflow")
                            return
                        }
                        let srcBuf = UnsafeBufferPointer(start: readBuf + offset, count: toCopy)
                        if bufState == 0 {
                            buf0.replaceSubrange(buf0Cnt..<buf0Cnt+toCopy, with: srcBuf)
                            buf0Cnt += toCopy
                        } else {
                            buf1.replaceSubrange(buf1Cnt..<buf1Cnt+toCopy, with: srcBuf)
                            buf1Cnt += toCopy
                        }
                        offset += toCopy
                        remaining -= toCopy
                    }
                    let newCnt = (bufState == 0) ? buf0Cnt : buf1Cnt
                    if newCnt >= 5 {
                        let crcBuf = (bufState == 0) ? buf0 : buf1
                        let receivedCrc = readUInt32LE(crcBuf, offset: 0)
                        let finalCrc = runningCrc ^ 0xFFFFFFFF
                        let crcValid = (finalCrc == receivedCrc)
                        log.info("[conn\(connId)] L2CAP CRC: computed=0x\(String(finalCrc, radix: 16)) received=0x\(String(receivedCrc, radix: 16)) valid=\(crcValid)")
                        callback?.onL2capBatchComplete(connId: connId, framesReceived: Int32(framesReceived), crcValid: crcValid)
                        return
                    }
                    break
                }

                if bufState == 0 {
                    let space = frameSize - buf0Cnt
                    let toCopy = min(remaining, space)
                    if toCopy <= 0 {
                        log.error("[conn\(connId)] L2CAP buf0 toCopy=\(toCopy) (space=\(space) remaining=\(remaining)), aborting")
                        callback?.onL2capError(connId: connId, message: "L2CAP buf0 overflow")
                        return
                    }
                    if buf0Cnt + toCopy > buf0.count {
                        log.error("[conn\(connId)] L2CAP buf0 replaceSubrange out of bounds: cnt=\(buf0Cnt) toCopy=\(toCopy) bufSize=\(buf0.count)")
                        callback?.onL2capError(connId: connId, message: "L2CAP buf0 range error")
                        return
                    }
                    let srcBuf = UnsafeBufferPointer(start: readBuf + offset, count: toCopy)
                    buf0.replaceSubrange(buf0Cnt..<buf0Cnt+toCopy, with: srcBuf)
                    buf0Cnt += toCopy
                    offset += toCopy
                    remaining -= toCopy

                    if buf0Cnt >= frameSize {
                        runningCrc = updateCrc32(runningCrc, data: buf0)
                        framesReceived += 1
                        callback?.onL2capFrame(connId: connId, frameData: buf0.toKotlinByteArray())
                        bufState = 1
                        buf1Cnt = 0
                    }
                } else {
                    let space = frameSize - buf1Cnt
                    let toCopy = min(remaining, space)
                    if toCopy <= 0 {
                        log.error("[conn\(connId)] L2CAP buf1 toCopy=\(toCopy) (space=\(space) remaining=\(remaining)), aborting")
                        callback?.onL2capError(connId: connId, message: "L2CAP buf1 overflow")
                        return
                    }
                    if buf1Cnt + toCopy > buf1.count {
                        log.error("[conn\(connId)] L2CAP buf1 replaceSubrange out of bounds: cnt=\(buf1Cnt) toCopy=\(toCopy) bufSize=\(buf1.count)")
                        callback?.onL2capError(connId: connId, message: "L2CAP buf1 range error")
                        return
                    }
                    let srcBuf = UnsafeBufferPointer(start: readBuf + offset, count: toCopy)
                    buf1.replaceSubrange(buf1Cnt..<buf1Cnt+toCopy, with: srcBuf)
                    buf1Cnt += toCopy
                    offset += toCopy
                    remaining -= toCopy

                    if buf1Cnt >= frameSize {
                        runningCrc = updateCrc32(runningCrc, data: buf1)
                        framesReceived += 1
                        callback?.onL2capFrame(connId: connId, frameData: buf1.toKotlinByteArray())
                        bufState = 0
                        buf0Cnt = 0
                    }
                }
            }
        }
    }

    func l2capClose(connId: Int32) {
        l2capReceiveJobs[connId]?.cancel()
        l2capReceiveJobs.removeValue(forKey: connId)
        l2capChannels[connId]?.inputStream?.close()
        l2capChannels[connId]?.outputStream?.close()
        l2capChannels.removeValue(forKey: connId)
        log.info("[conn\(connId)] L2CAP closed")
    }

    func l2capStreamSend(connId: Int32, psm: Int32, imageBytes: KotlinByteArray, blockSize: Int32, interBlockDelayMs: Int64, drainDelayMs: Int64) {
        l2capReceiveJobs[connId]?.cancel()

        let data = imageBytes.toSwiftData()
        let bs = Int(blockSize)
        let delay = TimeInterval(interBlockDelayMs) / 1000.0

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            guard let peripheral = self.peripherals[connId] else {
                self.callback?.onL2capSendError(connId: connId, message: "No peripheral")
                return
            }

            // Open a dedicated L2CAP channel for sending
            peripheral.openL2CAPChannel(CBL2CAPPSM(psm))

            // Wait for channel to be established
            for _ in 0..<100 {
                if self.l2capChannels[connId] != nil { break }
                Thread.sleep(forTimeInterval: 0.1)
            }

            guard let channel = self.l2capChannels[connId],
                  let outputStream = channel.outputStream else {
                self.callback?.onL2capSendError(connId: connId, message: "L2CAP channel not opened")
                return
            }

            let totalBlocks = (data.count + bs - 1) / bs

            for i in 0..<totalBlocks {
                if self.l2capReceiveJobs[connId]?.isCancelled == true { return }

                var block = Data(count: bs)
                let start = i * bs
                let end = min(start + bs, data.count)
                block.replaceSubrange(0..<(end - start), with: data[start..<end])

                block.withUnsafeBytes { ptr in
                    _ = outputStream.write(ptr.bindMemory(to: UInt8.self).baseAddress!, maxLength: bs)
                }

                self.callback?.onL2capSendProgress(connId: connId, blocksSent: Int32(i + 1), blocksTotal: Int32(totalBlocks))

                if i < totalBlocks - 1 {
                    Thread.sleep(forTimeInterval: delay)
                }
            }

            // Allow BLE stack to drain
            Thread.sleep(forTimeInterval: TimeInterval(drainDelayMs) / 1000.0)

            self.callback?.onL2capSendComplete(connId: connId)
        }

        l2capReceiveJobs[connId] = workItem
        l2capQueue.async(execute: workItem)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let previousState = lastManagerState
        lastManagerState = central.state
        log.info("Central manager state: \(central.state.rawValue)")

        // Handle BLE power-off: CoreBluetooth may NOT fire didDisconnectPeripheral
        // when BLE is toggled off, leaving ConnectionSlot unaware of the disconnect.
        // Explicitly notify onDisconnected to cancel stall timers and start reconnection.
        if central.state != .poweredOn && previousState == .poweredOn && !peripherals.isEmpty {
            log.warning("BLE powered off (state \(central.state.rawValue)) — notifying disconnect for \(self.peripherals.count) peripheral(s)")
            for (connId, _) in peripherals {
                characteristics.removeValue(forKey: connId)
                l2capClose(connId: connId)
                callback?.onDisconnected(connId: connId, status: -1)
            }
        }

        // Handle BLE power-on: re-issue connect for any peripherals the reconnection
        // loop is still tracking so the ConnectionSlot reconnect loop receives didConnect.
        if central.state == .poweredOn && previousState != .poweredOn && !peripherals.isEmpty {
            log.info("BLE restored (was state \(previousState.rawValue)) — re-issuing connect for \(self.peripherals.count) peripheral(s)")
            for (connId, peripheral) in peripherals {
                log.info("[conn\(connId)] Re-issuing connect after BLE power restore")
                centralManager.connect(peripheral, options: nil)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        guard !name.isEmpty else { return }

        var mfgData: KotlinByteArray? = nil
        if let rawData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data, rawData.count >= 2 {
            // Skip the 2-byte company ID to match Android behavior
            let payload = rawData.dropFirst(2)
            mfgData = Data(payload).toKotlinByteArray()
        }

        let address = peripheral.identifier.uuidString
        log.info("Scan found: \(name) (\(address)) rssi=\(RSSI)")
        callback?.onDeviceDiscovered(
            deviceHandle: peripheral,
            name: name,
            address: address,
            rssi: Int32(truncating: RSSI),
            manufacturerData: mfgData
        )
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let connId = connIdForPeripheral(peripheral) else { return }
        log.info("[\(connId)] Connected to \(peripheral.identifier)")
        callback?.onConnected(connId: connId)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard let connId = connIdForPeripheral(peripheral) else { return }
        let status = (error != nil) ? Int32(-1) : Int32(0)
        log.warning("[\(connId)] Disconnected (error=\(String(describing: error)))")
        characteristics.removeValue(forKey: connId)
        l2capClose(connId: connId)
        callback?.onDisconnected(connId: connId, status: status)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard let connId = connIdForPeripheral(peripheral) else { return }
        log.error("[\(connId)] Failed to connect: \(String(describing: error))")
        callback?.onDisconnected(connId: connId, status: -1)
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let connId = connIdForPeripheral(peripheral) else { return }
        if let error = error {
            log.error("[\(connId)] Service discovery error: \(error)")
            return
        }
        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let connId = connIdForPeripheral(peripheral) else { return }
        if let error = error {
            log.error("[\(connId)] Char discovery error for \(service.uuid): \(error)")
            return
        }

        if characteristics[connId] == nil {
            characteristics[connId] = [:]
        }
        for char in service.characteristics ?? [] {
            characteristics[connId]?[char.uuid] = char
        }

        // Check if all services have been discovered
        let allDiscovered = peripheral.services?.allSatisfy { svc in
            svc.characteristics != nil
        } ?? false

        if allDiscovered {
            var available = Set<HpyCharId>()
            if let charMap = characteristics[connId] {
                for (uuid, _) in charMap {
                    if let charId = uuidToCharId[uuid] {
                        available.insert(charId)
                    }
                }
            }
            log.info("[\(connId)] Services discovered: \(available.count) characteristics")
            callback?.onServicesDiscovered(connId: connId, availableChars: available)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let connId = connIdForPeripheral(peripheral) else { return }
        guard let charId = uuidToCharId[characteristic.uuid] else { return }

        if let error = error {
            if !characteristic.isNotifying {
                log.warning("[\(connId)] Characteristic read failed: \(charId) error=\(error.localizedDescription)")
                callback?.onCharacteristicReadFailed(connId: connId, charId: charId)
            }
            return
        }

        guard let value = characteristic.value else { return }

        if characteristic.isNotifying {
            callback?.onCharacteristicChanged(connId: connId, charId: charId, value: value.toKotlinByteArray())
        } else {
            callback?.onCharacteristicRead(connId: connId, charId: charId, value: value.toKotlinByteArray())
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let connId = connIdForPeripheral(peripheral) else { return }
        guard let charId = uuidToCharId[characteristic.uuid] else { return }
        let status: Int32 = (error == nil) ? 0 : -1
        callback?.onWriteComplete(connId: connId, charId: charId, status: status)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard let connId = connIdForPeripheral(peripheral) else { return }
        guard let charId = uuidToCharId[characteristic.uuid] else { return }
        let status: Int32 = (error == nil) ? 0 : -1
        callback?.onDescriptorWritten(connId: connId, charId: charId, status: status)
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard let connId = connIdForPeripheral(peripheral) else { return }
        if error == nil {
            callback?.onRssiRead(connId: connId, rssi: Int32(truncating: RSSI))
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
        guard let connId = connIdForPeripheral(peripheral) else { return }
        if let error = error {
            log.error("[\(connId)] L2CAP open error: \(error)")
            callback?.onL2capError(connId: connId, message: "L2CAP open failed: \(error.localizedDescription)")
            return
        }
        guard let channel = channel else {
            callback?.onL2capError(connId: connId, message: "L2CAP channel is nil")
            return
        }

        channel.inputStream?.open()
        channel.outputStream?.open()
        l2capChannels[connId] = channel
        log.info("[\(connId)] L2CAP channel opened (PSM=\(channel.psm))")
        callback?.onL2capConnected(connId: connId)
    }

    // MARK: - Helpers

    private func connIdForPeripheral(_ peripheral: CBPeripheral) -> Int32? {
        for (connId, p) in peripherals {
            if p.identifier == peripheral.identifier {
                return connId
            }
        }
        return nil
    }
}

// MARK: - Data <-> KotlinByteArray Conversions

extension KotlinByteArray {
    func toSwiftData() -> Data {
        var bytes = [UInt8](repeating: 0, count: Int(size))
        for i in 0..<Int(size) {
            bytes[i] = UInt8(bitPattern: get(index: Int32(i)))
        }
        return Data(bytes)
    }
}

extension Data {
    func toKotlinByteArray() -> KotlinByteArray {
        let kba = KotlinByteArray(size: Int32(count))
        for (i, byte) in enumerated() {
            kba.set(index: Int32(i), value: Int8(bitPattern: byte))
        }
        return kba
    }
}

// MARK: - CRC32

private let crc32Table: [UInt32] = {
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

private func updateCrc32(_ crcIn: UInt32, data: Data) -> UInt32 {
    var crc = crcIn
    for byte in data {
        let idx = Int((crc ^ UInt32(byte)) & 0xFF)
        crc = crc32Table[idx] ^ (crc >> 8)
    }
    return crc
}

private func readUInt32LE(_ data: Data, offset: Int) -> UInt32 {
    guard data.count >= offset + 4 else { return 0 }
    let b0 = UInt32(data[offset])
    let b1 = UInt32(data[offset + 1])
    let b2 = UInt32(data[offset + 2])
    let b3 = UInt32(data[offset + 3])
    return (b3 << 24) | (b2 << 16) | (b1 << 8) | b0
}
