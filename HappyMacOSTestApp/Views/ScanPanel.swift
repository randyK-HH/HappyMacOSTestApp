import SwiftUI
import HappyPlatformAPI

struct ScanPanel: View {
    @EnvironmentObject var viewModel: TestAppViewModel
    @Binding var selectedConnId: Int32?
    @State private var showSettingsSheet = false
    @State private var sortTick = 0

    var body: some View {
        let connectedAddresses = Set(viewModel.connectedRings.values.map(\.address))
        let unconnectedDevices = viewModel.discoveredDevices.filter { !connectedAddresses.contains($0.address) }
        let sortedDevices = unconnectedDevices.sorted { $0.rssi > $1.rssi }

        ZStack {
            // Watermark background
            VStack {
                Spacer()
                Image("HappyWatermark")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 40)
                    .opacity(0.40)
                Spacer().frame(height: 4)
                Text("Happy Health")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.gray.opacity(0.55))
                Text("macOS Platform Test App")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.55))
                let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
                Text("v\(version)")
                    .font(.caption2)
                    .foregroundColor(.gray.opacity(0.50))
                Spacer().frame(height: 48)
            }

            VStack(spacing: 0) {
                // Scan toggle + Disconnect All buttons
                HStack(spacing: 4) {
                    Button(action: { viewModel.toggleScan() }) {
                        Text(viewModel.isScanning ? "Stop Scanning" : "Start Scanning")
                    }
                    .buttonStyle(CommandButtonStyle(tint: viewModel.isScanning ? .red : .blue))

                    Button(action: { viewModel.disconnectAll() }) {
                        Text("Disconnect All")
                    }
                    .buttonStyle(CommandButtonStyle())
                    .disabled(viewModel.connectedRings.isEmpty)
                    .opacity(viewModel.connectedRings.isEmpty ? 0.4 : 1.0)

                    Button(action: { showSettingsSheet = true }) {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                List {
                    // Connected Rings Section
                    if !viewModel.connectedRings.isEmpty {
                        Section("Connected Rings (\(viewModel.connectedRings.count))") {
                            ForEach(Array(viewModel.connectedRings.values).sorted(by: { $0.connId < $1.connId }), id: \.connId) { ring in
                                ConnectedRingCard(ring: ring)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if viewModel.isScanning { viewModel.toggleScan() }
                                        selectedConnId = ring.connId
                                    }
                            }
                        }
                    }

                    // Discovered Devices Section
                    Section("Discovered Devices (\(sortedDevices.count))") {
                        if let errorMsg = viewModel.scanErrorMessage {
                            Text(errorMsg)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        if sortedDevices.isEmpty && !viewModel.isScanning {
                            Text("No devices found. Tap 'Start Scanning' to search.")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }

                        if viewModel.isScanning && sortedDevices.isEmpty {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Scanning...")
                                    .font(.caption)
                            }
                        }

                        let _ = sortTick  // trigger re-sort on tick
                        ForEach(sortedDevices, id: \.address) { device in
                            DiscoveredDeviceRow(device: device)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.connect(device: device)
                                }
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheet(
                settings: viewModel.globalSettings,
                isPerRing: false,
                onSave: { viewModel.updateGlobalSettings($0) }
            )
        }
        .onReceive(Timer.publish(every: 3, on: .main, in: .common).autoconnect()) { _ in
            sortTick += 1
        }
    }
}

/// Convert a serial number to MAC address format (e.g. "FF2F81AFEF0C" -> "FF:2F:81:AF:EF:0C").
private func macFromSerial(_ serial: String) -> String {
    let hex = serial.uppercased().filter(\.isHexDigit)
    guard hex.count == 12 else { return serial }
    let chars = Array(hex)
    return stride(from: 0, to: 12, by: 2).map { String(chars[$0...$0+1]) }.joined(separator: ":")
}

private struct ConnectedRingCard: View {
    let ring: ConnectedRingInfo

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(ring.name)
                    .fontWeight(.bold)
                    .font(.caption)
                if let serial = ring.deviceInfo?.serialNumber, !serial.isEmpty {
                    Text(macFromSerial(serial))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(stateText)
                    .foregroundColor(stateColor)
                    .fontWeight(.medium)
                    .font(.caption)
                if let fw = ring.deviceInfo?.fwVersion {
                    Text("FW \(fw)")
                        .font(.caption2)
                }
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(Color.accentColor.opacity(0.1))
    }

    private var stateText: String {
        switch ring.state {
        case .connecting: return "Connecting..."
        case .handshaking: return "Handshaking..."
        case .ready: return "Ready"
        case .connectedLimited: return "Limited"
        case .downloading: return "Downloading"
        case .fwUpdating: return "FW Updating"
        case .reconnecting: return "Reconnecting..."
        default: return "\(ring.state)"
        }
    }

    private var stateColor: Color {
        switch ring.state {
        case .ready: return .blue
        case .connecting, .handshaking: return .orange
        default: return .secondary
        }
    }
}

private struct DiscoveredDeviceRow: View {
    let device: ScannedDeviceInfo

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.name)
                    .fontWeight(.medium)
                    .font(.caption)
            }
            Spacer()
            Text("\(device.rssi) dBm")
                .font(.caption2)
        }
    }
}
