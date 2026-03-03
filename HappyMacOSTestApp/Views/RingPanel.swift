import SwiftUI
import HappyPlatformAPI

struct RingPanel: View {
    let connId: Int32
    @EnvironmentObject var viewModel: TestAppViewModel

    @State private var showStatusSheet = false
    @State private var showDaqConfigSheet = false
    @State private var showDaqConfigureSheet = false
    @State private var showShareSheet = false
    @State private var showSyncFrameSheet = false

    var body: some View {
        let ring = viewModel.connectedRings[connId]

        if let ring = ring {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Header with ring name and disconnect
                    ringHeader(ring: ring)

                    // Reconnection Banner
                    if ring.isReconnecting {
                        reconnectionBanner(ring: ring)
                    }

                    // Device Info
                    if let info = ring.deviceInfo {
                        deviceInfoSection(info: info, ring: ring)
                    }

                    // Device Status
                    if let status = ring.lastStatus {
                        deviceStatusSection(status: status)
                    }

                    // DAQ Config
                    if let config = ring.daqConfig {
                        daqConfigSection(config: config)
                    }

                    // Commands
                    commandsSection(ring: ring)

                    // FW Update
                    FwUpdateSection(connId: connId, ring: ring, showShareSheet: $showShareSheet)

                    // Download
                    downloadSection(ring: ring)

                    // Event Log
                    EventLogSection(connId: connId)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .sheet(isPresented: $showStatusSheet) {
                if let status = ring.lastStatus {
                    DeviceStatusSheet(status: status, extendedStatus: ring.extendedStatus)
                        .frame(minWidth: 400, minHeight: 500)
                }
            }
            .sheet(isPresented: $showDaqConfigSheet) {
                if let config = ring.daqConfig {
                    DaqConfigSheet(
                        config: config,
                        fingerDetectionOn: ring.fingerDetectionOn,
                        onConfigure: {
                            showDaqConfigSheet = false
                            showDaqConfigureSheet = true
                        }
                    )
                    .frame(minWidth: 400, minHeight: 500)
                }
            }
            .sheet(isPresented: $showDaqConfigureSheet) {
                if let config = ring.daqConfig {
                    DaqConfigureSheet(
                        config: config,
                        fwVersion: ring.deviceInfo?.fwVersion,
                        onUpdate: { newConfig, applyImmediately in
                            viewModel.setDaqConfig(connId: connId, config: newConfig, applyImmediately: applyImmediately)
                            showDaqConfigureSheet = false
                        }
                    )
                    .frame(minWidth: 500, minHeight: 600)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                FileShareSheet(viewModel: viewModel, deviceId: ring.name)
                    .frame(minWidth: 400, minHeight: 400)
            }
            .sheet(isPresented: $showSyncFrameSheet) {
                SyncFrameSheet(
                    frameCount: ring.syncFrameCount,
                    reboots: ring.syncFrameReboots,
                    onCommit: { fc, rb in
                        viewModel.setSyncFrame(connId: connId, frameCount: fc, reboots: rb)
                    }
                )
                .frame(minWidth: 300, minHeight: 200)
            }
        } else {
            Text("Ring disconnected")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func ringHeader(ring: ConnectedRingInfo) -> some View {
        HStack {
            stateSection(ring: ring)
            Spacer()
            Button("Disconnect") {
                viewModel.disconnect(connId: connId)
            }
            .foregroundColor(.red)
            .font(.caption)
        }
    }

    private func stateSection(ring: ConnectedRingInfo) -> some View {
        let stateText: String = {
            if ring.state == .reconnecting && ring.reconnectRetryCount > 0 {
                return "\(ring.name) - RECONNECTING (\(ring.reconnectRetryCount)/64)"
            }
            if ring.state == .fwUpdateRebooting && ring.reconnectRetryCount > 0 {
                return "\(ring.name) - FW_UPDATE_REBOOTING (\(ring.reconnectRetryCount)/64)"
            }
            return "\(ring.name) - \(ring.state)"
        }()

        let stateColor: Color = {
            switch ring.state {
            case .ready, .downloading: return .blue
            case .waiting: return .orange
            case .handshaking, .connecting: return .orange
            case .reconnecting, .disconnected: return .red
            default: return .secondary
            }
        }()

        return Text(stateText)
            .font(.headline)
            .foregroundColor(stateColor)
            .fontWeight(.bold)
    }

    private func reconnectionBanner(ring: ConnectedRingInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            let bannerText = ring.state == .fwUpdateRebooting
                ? "Reconnecting after FW update..."
                : "Connection lost. Reconnecting..."
            Text(bannerText)
                .font(.subheadline)
                .fontWeight(.bold)
            Text("Attempt \(ring.reconnectRetryCount) of 64")
                .font(.caption)
            ProgressView(value: Float(ring.reconnectRetryCount), total: 64)
                .tint(.red)
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }

    private func deviceInfoSection(info: DeviceInfoData, ring: ConnectedRingInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(title: "Device Info")
            InfoRow(label: "Serial Number", value: info.serialNumber)
            InfoRow(label: "FW Version", value: info.fwVersion)
            InfoRow(label: "SW Version", value: info.swVersion)
            InfoRow(label: "Manufacturer", value: info.manufacturerName)
            InfoRow(label: "Model", value: info.modelNumber)
            InfoRow(label: "Firmware Tier", value: "\(info.firmwareTier)")
            InfoRow(label: "L2CAP Download", value: info.supportsL2capDownload ? "Supported" : "Not Available")
            if ring.ringSize > 0 {
                InfoRow(label: "Ring Size", value: "\(ring.ringSize)")
            }
            let colorName: String = {
                switch ring.ringColor {
                case 1: return "White"
                case 2: return "Black"
                case 3: return "Clay"
                case 0: return "Unknown"
                default: return "Unknown(\(ring.ringColor))"
                }
            }()
            InfoRow(label: "Ring Color", value: colorName)
        }
    }

    private func deviceStatusSection(status: DeviceStatusData) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(title: "Device Status")
            InfoRow(label: "Physical", value: status.phyString)
            InfoRow(label: "DAQ Mode", value: status.daqString)
            InfoRow(label: "Battery", value: "\(status.soc)% (\(status.batteryVoltage)mV)")
            InfoRow(label: "Unsynced Frames", value: "\(status.unsyncedFrames)")
            InfoRow(label: "Sync Position", value: status.syncString)
            InfoRow(label: "Clock Rate", value: status.clockRateString)
            InfoRow(label: "Notif Sender", value: status.notifSenderString)
        }
    }

    private func daqConfigSection(config: DaqConfigData) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionHeader(title: "DAQ Config")
            InfoRow(label: "Mode", value: config.modeString)
            InfoRow(label: "Version", value: "\(config.version)")
        }
    }

    private func commandsSection(ring: ConnectedRingInfo) -> some View {
        let isReady = ring.state == .ready || ring.state == .waiting

        return VStack(alignment: .leading, spacing: 2) {
            CommandSectionHeader(title: "Commands", commandStatus: ring.commandStatus)

            HStack(spacing: 4) {
                Button("Dev Status") {
                    viewModel.getDeviceStatus(connId: connId)
                    showStatusSheet = true
                }
                .buttonStyle(CommandButtonStyle())
                .disabled(!isReady)
                .opacity(isReady ? 1.0 : 0.4)

                Button("DAQ Config") {
                    viewModel.getDaqConfig(connId: connId)
                    showDaqConfigSheet = true
                }
                .buttonStyle(CommandButtonStyle())
                .disabled(!isReady)
                .opacity(isReady ? 1.0 : 0.4)
            }

            HStack(spacing: 4) {
                Button("Start DAQ") { viewModel.startDaq(connId: connId) }
                    .buttonStyle(CommandButtonStyle())
                    .disabled(!isReady)
                    .opacity(isReady ? 1.0 : 0.4)

                Button("Stop DAQ") { viewModel.stopDaq(connId: connId) }
                    .buttonStyle(CommandButtonStyle())
                    .disabled(!isReady)
                    .opacity(isReady ? 1.0 : 0.4)
            }

            HStack(spacing: 4) {
                Button("Identify") { viewModel.identify(connId: connId) }
                    .buttonStyle(CommandButtonStyle())
                    .disabled(!isReady)
                    .opacity(isReady ? 1.0 : 0.4)

                let fingerLabel: String = {
                    switch ring.fingerDetectionOn {
                    case true: return "Finger Det: ON"
                    case false: return "Finger Det: OFF"
                    default: return "Finger Det: ?"
                    }
                }()
                Button(fingerLabel) { viewModel.toggleFingerDetection(connId: connId) }
                    .buttonStyle(CommandButtonStyle())
                    .disabled(!isReady)
                    .opacity(isReady ? 1.0 : 0.4)
            }

            HStack(spacing: 4) {
                Button("Sync Frame") {
                    viewModel.getSyncFrame(connId: connId)
                    showSyncFrameSheet = true
                }
                .buttonStyle(CommandButtonStyle())
                .disabled(!isReady)
                .opacity(isReady ? 1.0 : 0.4)

                Button("Assert") { viewModel.assertDevice(connId: connId) }
                    .buttonStyle(CommandButtonStyle())
                    .disabled(!isReady)
                    .opacity(isReady ? 1.0 : 0.4)
            }
        }
    }

    private func downloadSection(ring: ConnectedRingInfo) -> some View {
        let isReady = ring.state == .ready || ring.state == .waiting
        let canStartDownload = isReady && (ring.deviceInfo?.firmwareTier ?? .tier0).ordinal >= FirmwareTier.tier1.ordinal
        let isDownloading = ring.isDownloading
        let isActivelyDownloading = ring.state == .downloading
        let isWaiting = ring.state == .waiting

        return VStack(alignment: .leading, spacing: 4) {
            DownloadSectionHeader(
                title: "Download",
                downloadState: ring.downloadState,
                onShare: !isDownloading ? { showShareSheet = true } : nil
            )

            if isActivelyDownloading {
                if ring.sessionDownloadTotal > 0 {
                    ProgressView(value: Float(ring.sessionDownloadProgress), total: Float(ring.sessionDownloadTotal))
                    let sessionSizeKb = ring.sessionDownloadProgress * 4  // each frame = 4096 bytes = 4 kB
                    let cumulativeSizeKb = ring.downloadProgress * 4
                    let transportLabel = ring.downloadTransport.isEmpty ? "" : "  (\(ring.downloadTransport))"
                    HStack {
                        Text("\(ring.sessionDownloadProgress) frames (\(sessionSizeKb)kB)\(transportLabel)")
                            .font(.caption)
                        Spacer()
                        Text("\(ring.downloadProgress) frames (\(cumulativeSizeKb)kB)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                } else {
                    ProgressView()
                        .controlSize(.small)
                    Text("Starting download...")
                        .font(.caption)
                }
            } else if isWaiting {
                let sizeKb = ring.downloadProgress * 4
                HStack {
                    Text("Waiting for data...")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Text("\(ring.downloadProgress) frames (\(sizeKb)kB)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            if ring.totalFramesDownloaded > 0 && !isDownloading {
                InfoRow(label: "Last Download", value: "\(ring.totalFramesDownloaded) frames")
            }

            HStack(spacing: 4) {
                let startEnabled = canStartDownload && !isDownloading
                Button("Start Download") { viewModel.startDownload(connId: connId) }
                    .buttonStyle(CommandButtonStyle())
                    .disabled(!startEnabled)
                    .opacity(startEnabled ? 1.0 : 0.4)

                Button("Stop Download") { viewModel.stopDownload(connId: connId) }
                    .buttonStyle(CommandButtonStyle(tint: isDownloading ? .red : .blue))
                    .disabled(!isDownloading)
                    .opacity(isDownloading ? 1.0 : 0.4)
            }
        }
    }
}

// MARK: - Reusable Components

struct SectionHeader: View {
    let title: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            Divider()
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.vertical, 1)
    }
}

struct CommandSectionHeader: View {
    let title: String
    let commandStatus: String?

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            Spacer()
            if let status = commandStatus {
                let color: Color = {
                    if status.contains("Success") { return .blue }
                    if status.contains("Timeout") { return .orange }
                    return .red
                }()
                Text(status)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
        }
        Divider()
    }
}

struct CommandButtonStyle: ButtonStyle {
    var tint: Color = .blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(configuration.isPressed ? tint.opacity(0.7) : tint)
            .foregroundColor(.white)
            .cornerRadius(6)
    }
}

struct SyncFrameSheet: View {
    let frameCount: UInt32
    let reboots: UInt32
    let onCommit: (UInt32, UInt32) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var frameCountText: String = ""
    @State private var rebootsText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Sync Frame")
                .font(.headline)

            Form {
                TextField("Reboots", text: $rebootsText)
                TextField("Frame Count", text: $frameCountText)
            }

            HStack {
                Button("Clear") {
                    frameCountText = "0"
                    rebootsText = "0"
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Commit") {
                    let fc = UInt32(frameCountText) ?? 0
                    let rb = UInt32(rebootsText) ?? 0
                    onCommit(fc, rb)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .onAppear {
            frameCountText = "\(frameCount)"
            rebootsText = "\(reboots)"
        }
    }
}

struct DownloadSectionHeader: View {
    let title: String
    let downloadState: String?
    let onShare: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            Spacer()
            if let state = downloadState {
                let color: Color = (state == "Downloading") ? .blue : (state == "Waiting" ? .orange : .secondary)
                Text(state)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            } else if let onShare = onShare {
                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        Divider()
    }
}
