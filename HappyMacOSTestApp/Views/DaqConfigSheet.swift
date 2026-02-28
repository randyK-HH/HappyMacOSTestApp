import SwiftUI
import HappyPlatformAPI

struct DaqConfigSheet: View {
    let config: DaqConfigData
    let fingerDetectionOn: Bool?
    let onConfigure: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ConfigRow("Version", "\(config.version)")
                    ConfigRow("Mode", "\(config.modeString) (\(config.mode))")

                    Divider().padding(.vertical, 4)

                    ConfigRow("Ambient Light", "\(config.ambientLightEn ? "ON" : "OFF"), \(config.ambientLightPeriodMs) ms")
                    ConfigRow("Ambient Temp", "\(config.ambientTempEn ? "ON" : "OFF"), \(config.ambientTempPeriodMs) ms")
                    ConfigRow("Skin Temp", "\(config.skinTempEn ? "ON" : "OFF"), \(config.skinTempPeriodMs) ms")

                    Divider().padding(.vertical, 4)

                    ConfigRow("PPG Cycle Time", "\(config.ppgCycleTimeMs) ms")
                    ConfigRow("PPG Interval Time", "\(config.ppgIntervalTimeMs) ms")
                    ConfigRow("PPG On During Sleep", config.ppgOnDuringSleepEn ? "ON" : "OFF")
                    ConfigRow("PPG FSR", "\(config.ppgFsr)")
                    ConfigRow("PPG Stop Config", "\(config.ppgStopConfig)")
                    ConfigRow("PPG AGC Channel Config", "\(config.ppgAgcChannelConfig)")

                    Divider().padding(.vertical, 4)

                    ConfigRow("Compressed Sensing", config.compressedSensingEn ? "ON" : "OFF")
                    ConfigRow("CS Mode", "\(config.csModeString) (\(config.csMode))")

                    Divider().padding(.vertical, 4)

                    ConfigRow("Multi-Spectral", "\(config.multiSpectralEn ? "ON" : "OFF"), \(config.multiSpectralPeriodMs) ms")
                    ConfigRow("SF Max Latency", "\(config.sfMaxLatencyMs) ms")

                    Divider().padding(.vertical, 4)

                    ConfigRow("EDA Sweep", "\(config.edaSweepEn ? "ON" : "OFF"), \(config.edaSweepPeriodMs) ms")
                    ConfigRow("EDA Sweep Param Cfg", "\(config.edaSweepParamCfg)")

                    Divider().padding(.vertical, 4)

                    ConfigRow("Acc ULP", "\(config.accUlpEn)")
                    ConfigRow("Acc 2G During Sleep", config.acc2gDuringSleepEn ? "ON" : "OFF")
                    ConfigRow("Acc Inactivity Config", "\(config.accInactivityConfig)")

                    Divider().padding(.vertical, 4)

                    ConfigRow("Opp Sample", "\(config.oppSampleEn ? "ON" : "OFF"), \(config.oppSamplePeriodMs) ms")
                    ConfigRow("Opp Sample On-Time", "\(config.oppSampleOnTimeMs) ms")
                    ConfigRow("Opp Sample Alt Mode", "\(config.oppSampleAltMode)")

                    Divider().padding(.vertical, 4)

                    ConfigRow("Memfault Config", "\(config.memfaultConfig)")
                    ConfigRow("Sleep Thresh Config", "\(config.sleepThreshConfig)")
                    ConfigRow("Reset Ring Cfg", "\(config.resetRingCfg)")
                    ConfigRow("Daily DAQ Mode Cfg", "\(config.dailyDaqModeCfg)")

                    Divider().padding(.vertical, 8)

                    let fingerStr: String = {
                        switch fingerDetectionOn {
                        case true: return "ON"
                        case false: return "OFF"
                        default: return "Unknown"
                        }
                    }()
                    ConfigRow("Finger Detection", fingerStr)
                }
                .padding()
            }
            .navigationTitle("DAQ Configuration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Dismiss") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Configure") {
                        dismiss()
                        onConfigure()
                    }
                }
            }
        }
    }
}

private struct ConfigRow: View {
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
