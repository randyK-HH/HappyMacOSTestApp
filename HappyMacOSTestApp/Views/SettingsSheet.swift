import SwiftUI

struct SettingsSheet: View {
    @State var settings: AppSettings
    let isPerRing: Bool
    let onSave: (AppSettings) -> Void
    var onResetToGlobal: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text(isPerRing ? "Ring Settings" : "Global Settings")
                .font(.headline)
                .padding(.top, 16)

            Form {
                Section("Transport") {
                    Toggle("Prefer L2CAP", isOn: $settings.preferL2cap)
                    Toggle("L2CAP Clock: 96 MHz", isOn: $settings.use96MHzClock)
                }

                Section("Scan / Connection") {
                    Picker("Min RSSI", selection: $settings.minRssi) {
                        ForEach(AppSettings.minRssiOptions, id: \.self) { val in
                            Text("\(val) dBm").tag(val)
                        }
                    }

                    Toggle("Auto-Reconnect", isOn: $settings.autoReconnect)

                    Picker("Max Reconnect Retries", selection: $settings.maxReconnectRetries) {
                        ForEach(AppSettings.maxRetriesOptions, id: \.self) { val in
                            Text(val == Int(Int32.max) ? "Unlimited" : "\(val)").tag(val)
                        }
                    }
                }

                Section("Download") {
                    Picker("Batch Size", selection: $settings.batchSize) {
                        ForEach(AppSettings.batchSizeOptions, id: \.self) { val in
                            Text("\(val)").tag(val)
                        }
                    }

                    Picker("Stall Timeout", selection: $settings.stallTimeoutSec) {
                        ForEach(AppSettings.stallTimeoutOptions, id: \.self) { val in
                            Text("\(val)s").tag(val)
                        }
                    }

                    Picker("Failsafe Timer", selection: $settings.failsafeTimerMin) {
                        ForEach(AppSettings.failsafeTimerOptions, id: \.self) { val in
                            Text("\(val) min").tag(val)
                        }
                    }
                }

                Section("Handshake") {
                    Toggle("Finger Detection on Connect", isOn: $settings.fingerDetectionOnConnect)

                    Picker("Memfault Interval", selection: $settings.memfaultIntervalIndex) {
                        ForEach(0..<AppSettings.memfaultIntervalOptions.count, id: \.self) { idx in
                            Text(AppSettings.memfaultIntervalOptions[idx]).tag(idx)
                        }
                    }
                }

                Section("FW Update") {
                    Toggle("FW Update: GATT", isOn: $settings.fwUpdateUseGatt)

                    Picker("Inter-Block Delay", selection: $settings.interBlockDelayMs) {
                        ForEach(AppSettings.interBlockDelayOptions, id: \.self) { val in
                            Text("\(val) ms").tag(val)
                        }
                    }

                    Picker("Drain Delay", selection: $settings.drainDelayMs) {
                        ForEach(AppSettings.drainDelayOptions, id: \.self) { val in
                            Text("\(val) ms").tag(val)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                if isPerRing, let onReset = onResetToGlobal {
                    Button("Reset to Global Defaults") {
                        onReset()
                        dismiss()
                    }
                    .foregroundColor(.red)
                }

                Spacer()

                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Save") {
                    onSave(settings)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 400, minHeight: 500)
    }
}
