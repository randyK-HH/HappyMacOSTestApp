import SwiftUI
import HappyPlatformAPI

struct DeviceStatusSheet: View {
    let status: DeviceStatusData
    let extendedStatus: ResponseParser.ExtendedDeviceStatus?
    var lastRssi: Int? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    Group {
                        StatusRow("Physical", status.phyString)
                        StatusRow("Charger", status.chargerStateString)
                        StatusRow("Charging", status.chargingStateString)
                        StatusRow("Charging Mode", status.chargingModeString)
                        StatusRow("Charge Blocked", status.chargerBlockedReasonString)
                        StatusRow("Charger Rev ID", "\(status.chargerRevId)")
                        StatusRow("Charger Status", status.chargerStatusString)
                    }

                    Divider().padding(.vertical, 4)

                    Group {
                        StatusRow("Battery", "\(status.soc)% (\(status.batteryVoltage) mV)")
                        StatusRow("RSSI", lastRssi.map { "\($0) dBm" } ?? "—")
                        StatusRow("DAQ", status.daqString)
                        StatusRow("Unsynced Frames", "\(status.unsyncedFrames)")
                        StatusRow("Sync", status.syncString)
                    }

                    Divider().padding(.vertical, 4)

                    Group {
                        StatusRow("Opportunistic", status.opportunisticSamplingStateString)
                        StatusRow("Opportunistic Time", "\(status.opportunisticStateTime)s")
                        StatusRow("Ship Mode", status.shipModeStatusString)
                        StatusRow("Sleep State", status.sleepStateString)
                        StatusRow("Pseudo Ring", status.pseudoRingOnOffString)
                        StatusRow("Boot Handshake", status.bootHandshakeFlagString)
                    }

                    Divider().padding(.vertical, 4)

                    Group {
                        StatusRow("SendUTC Flags", String(format: "0x%02X", status.sendUtcFlags))
                        StatusRow("Notif Sender", status.notifSenderString)
                        StatusRow("BLE CI", "\(status.bleCiValue) ms (inprog=\(status.bleCiUpdateInProgress))")
                        StatusRow("Clock Rate", status.clockRateString)
                    }

                    if let ext = extendedStatus {
                        Divider().padding(.vertical, 4)
                        Text("Extended")
                            .font(.caption)
                            .fontWeight(.bold)
                        StatusRow("BP State", ext.bpStateString)
                        StatusRow("BP Time Left", "\(ext.bpTimeLeftSec)s")
                    }
                }
                .padding()
            }
            .navigationTitle("Device Status")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Dismiss") { dismiss() }
                }
            }
        }
    }
}

private struct StatusRow: View {
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }

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
