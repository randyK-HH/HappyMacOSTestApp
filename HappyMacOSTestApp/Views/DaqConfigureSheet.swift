import SwiftUI
import HappyPlatformAPI

struct DaqConfigureSheet: View {
    let config: DaqConfigData
    let fwVersion: String?
    let onUpdate: (DaqConfigData, Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var applyImmediately = true
    @State private var mode: String
    @State private var ambientLightEn: Bool
    @State private var ambientLightPeriodMs: String
    @State private var ambientTempEn: Bool
    @State private var skinTempEn: Bool
    @State private var skinTempPeriodMs: String
    @State private var ppgCycleTimeMs: String
    @State private var ppgIntervalTimeMs: String
    @State private var ppgOnDuringSleepEn: Bool
    @State private var ppgFsr: String
    @State private var ppgStopConfig: String
    @State private var ppgAgcChannelConfig: String
    @State private var compressedSensingEn: Bool
    @State private var csMode: String
    @State private var multiSpectralEn: Bool
    @State private var multiSpectralPeriodMs: String
    @State private var sfMaxLatencyMs: String
    @State private var edaSweepEn: Bool
    @State private var edaSweepPeriodMs: String
    @State private var edaSweepParamCfg: String
    @State private var accUlpEn: String
    @State private var acc2gDuringSleepEn: Bool
    @State private var accInactivityConfig: String
    @State private var oppSampleEn: Bool
    @State private var oppSamplePeriodMs: String
    @State private var oppSampleOnTimeMs: String
    @State private var oppSampleAltMode: String
    @State private var memfaultConfig: String
    @State private var sleepThreshConfig: String
    @State private var resetRingCfg: String
    @State private var dailyDaqModeCfg: String

    init(config: DaqConfigData, fwVersion: String?, onUpdate: @escaping (DaqConfigData, Bool) -> Void) {
        self.config = config
        self.fwVersion = fwVersion
        self.onUpdate = onUpdate
        _mode = State(initialValue: "\(config.mode)")
        _ambientLightEn = State(initialValue: config.ambientLightEn)
        _ambientLightPeriodMs = State(initialValue: "\(config.ambientLightPeriodMs)")
        _ambientTempEn = State(initialValue: config.ambientTempEn)
        _skinTempEn = State(initialValue: config.skinTempEn)
        _skinTempPeriodMs = State(initialValue: "\(config.skinTempPeriodMs)")
        _ppgCycleTimeMs = State(initialValue: "\(config.ppgCycleTimeMs)")
        _ppgIntervalTimeMs = State(initialValue: "\(config.ppgIntervalTimeMs)")
        _ppgOnDuringSleepEn = State(initialValue: config.ppgOnDuringSleepEn)
        _ppgFsr = State(initialValue: "\(config.ppgFsr)")
        _ppgStopConfig = State(initialValue: "\(config.ppgStopConfig)")
        _ppgAgcChannelConfig = State(initialValue: "\(config.ppgAgcChannelConfig)")
        _compressedSensingEn = State(initialValue: config.compressedSensingEn)
        _csMode = State(initialValue: "\(config.csMode)")
        _multiSpectralEn = State(initialValue: config.multiSpectralEn)
        _multiSpectralPeriodMs = State(initialValue: "\(config.multiSpectralPeriodMs)")
        _sfMaxLatencyMs = State(initialValue: "\(config.sfMaxLatencyMs)")
        _edaSweepEn = State(initialValue: config.edaSweepEn)
        _edaSweepPeriodMs = State(initialValue: "\(config.edaSweepPeriodMs)")
        _edaSweepParamCfg = State(initialValue: "\(config.edaSweepParamCfg)")
        _accUlpEn = State(initialValue: "\(config.accUlpEn)")
        _acc2gDuringSleepEn = State(initialValue: config.acc2gDuringSleepEn)
        _accInactivityConfig = State(initialValue: "\(config.accInactivityConfig)")
        _oppSampleEn = State(initialValue: config.oppSampleEn)
        _oppSamplePeriodMs = State(initialValue: "\(config.oppSamplePeriodMs)")
        _oppSampleOnTimeMs = State(initialValue: "\(config.oppSampleOnTimeMs)")
        _oppSampleAltMode = State(initialValue: "\(config.oppSampleAltMode)")
        _memfaultConfig = State(initialValue: "\(config.memfaultConfig)")
        _sleepThreshConfig = State(initialValue: "\(config.sleepThreshConfig)")
        _resetRingCfg = State(initialValue: "\(config.resetRingCfg)")
        _dailyDaqModeCfg = State(initialValue: "\(config.dailyDaqModeCfg)")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("General") {
                    Toggle("Apply Immediately", isOn: $applyImmediately)

                    Picker("Mode", selection: $mode) {
                        ForEach(1...26, id: \.self) { m in
                            let minBuild = modeMinBuild(m)
                            let available = fwBuildAtLeast(fwVersion, minBuild: minBuild)
                            Text("\(m) - \(modeName(m))")
                                .tag("\(m)")
                                .foregroundColor(available ? .primary : .secondary)
                        }
                    }
                    .disabled(!fwBuildAtLeast(fwVersion, minBuild: 12))
                }

                Section("Ambient Light") {
                    ConfigToggle("Enable", isOn: $ambientLightEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                    ConfigField("Period (ms)", text: $ambientLightPeriodMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                }

                Section("Temperature") {
                    ConfigToggle("Ambient Temp Enable", isOn: $ambientTempEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                    TextField("Ambient Temp Period (tied to EDA)", text: .constant("\(config.ambientTempPeriodMs)"))
                        .disabled(true)
                        .foregroundColor(.secondary)
                    ConfigToggle("Skin Temp Enable", isOn: $skinTempEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                    ConfigField("Skin Temp Period (ms)", text: $skinTempPeriodMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                }

                Section("PPG") {
                    ConfigField("Cycle Time (ms)", text: $ppgCycleTimeMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                    ConfigField("Interval Time (ms)", text: $ppgIntervalTimeMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                    ConfigToggle("On During Sleep", isOn: $ppgOnDuringSleepEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                    ConfigField("FSR (0-5)", text: $ppgFsr, enabled: fwBuildAtLeast(fwVersion, minBuild: 16))
                    ConfigField("Stop Config (0-255)", text: $ppgStopConfig, enabled: fwBuildAtLeast(fwVersion, minBuild: 41))
                    ConfigField("AGC Channel Config (0-255)", text: $ppgAgcChannelConfig, enabled: fwBuildAtLeast(fwVersion, minBuild: 44))
                }

                Section("Compressed Sensing") {
                    ConfigToggle("Enable", isOn: $compressedSensingEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                    ConfigField("CS Mode (0-3)", text: $csMode, enabled: fwBuildAtLeast(fwVersion, minBuild: 55))
                }

                Section("Multi-Spectral") {
                    ConfigToggle("Enable", isOn: $multiSpectralEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                    ConfigField("Period (ms)", text: $multiSpectralPeriodMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 16))
                }

                Section("Superframe") {
                    ConfigField("Max Latency (ms)", text: $sfMaxLatencyMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 16))
                }

                Section("EDA Sweep") {
                    ConfigToggle("Enable", isOn: $edaSweepEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 28))
                    ConfigField("Period (ms)", text: $edaSweepPeriodMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 28))
                    ConfigField("Param Config (0-255)", text: $edaSweepParamCfg, enabled: fwBuildAtLeast(fwVersion, minBuild: 69))
                }

                Section("Accelerometer") {
                    ConfigField("ULP Config (0-255)", text: $accUlpEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 22))
                    ConfigToggle("2G During Sleep", isOn: $acc2gDuringSleepEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 36))
                    ConfigField("Inactivity Config (0-200)", text: $accInactivityConfig, enabled: fwBuildAtLeast(fwVersion, minBuild: 40))
                }

                Section("Opportunistic Sampling") {
                    ConfigToggle("Enable", isOn: $oppSampleEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 30))
                    ConfigField("Period (ms)", text: $oppSamplePeriodMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 30))
                    ConfigField("On-Time (ms)", text: $oppSampleOnTimeMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 31))
                    ConfigField("Alt Mode (0-20)", text: $oppSampleAltMode, enabled: fwBuildAtLeast(fwVersion, minBuild: 30))
                }

                Section("Memfault") {
                    ConfigField("Config (0-255)", text: $memfaultConfig, enabled: fwBuildAtLeast(fwVersion, minBuild: 30))
                }

                Section("Sleep") {
                    ConfigField("Threshold Config (0-255)", text: $sleepThreshConfig, enabled: fwBuildAtLeast(fwVersion, minBuild: 45))
                }

                Section("Reset") {
                    ConfigField("Reset Ring Cfg (0-50)", text: $resetRingCfg, enabled: fwBuildAtLeast(fwVersion, minBuild: 60))
                }

                Section("Daily DAQ Mode") {
                    ConfigField("Config (0-255)", text: $dailyDaqModeCfg, enabled: fwBuildAtLeast(fwVersion, minBuild: 76))
                }
            }
            .navigationTitle("Configure DAQ")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Update") { submitUpdate() }
                }
            }
        }
    }

    private func submitUpdate() {
        func clampInt(_ s: String, _ fallback: Int32, _ lo: Int32, _ hi: Int32) -> Int32 {
            min(hi, max(lo, Int32(s) ?? fallback))
        }
        func clampUInt(_ s: String, _ fallback: UInt32, _ lo: UInt32, _ hi: UInt32) -> UInt32 {
            min(hi, max(lo, UInt32(s) ?? fallback))
        }

        let newConfig = DaqConfigData(
            version: config.version,
            mode: clampInt(mode, config.mode, 1, 26),
            ambientLightEn: ambientLightEn,
            ambientLightPeriodMs: clampUInt(ambientLightPeriodMs, config.ambientLightPeriodMs, 1000, 60000),
            ambientTempEn: ambientTempEn,
            ambientTempPeriodMs: config.ambientTempPeriodMs,
            skinTempEn: skinTempEn,
            skinTempPeriodMs: clampUInt(skinTempPeriodMs, config.skinTempPeriodMs, 1000, 60000),
            ppgCycleTimeMs: clampUInt(ppgCycleTimeMs, config.ppgCycleTimeMs, 1000, 3600000),
            ppgIntervalTimeMs: clampUInt(ppgIntervalTimeMs, config.ppgIntervalTimeMs, 1000, 3600000),
            ppgOnDuringSleepEn: ppgOnDuringSleepEn,
            compressedSensingEn: compressedSensingEn,
            multiSpectralEn: multiSpectralEn,
            multiSpectralPeriodMs: UInt32(multiSpectralPeriodMs) ?? config.multiSpectralPeriodMs,
            sfMaxLatencyMs: UInt32(sfMaxLatencyMs) ?? config.sfMaxLatencyMs,
            ppgFsr: clampInt(ppgFsr, config.ppgFsr, 0, 5),
            edaSweepEn: edaSweepEn,
            edaSweepPeriodMs: UInt32(edaSweepPeriodMs) ?? config.edaSweepPeriodMs,
            accUlpEn: clampInt(accUlpEn, config.accUlpEn, 0, 255),
            oppSampleEn: oppSampleEn,
            oppSamplePeriodMs: UInt32(oppSamplePeriodMs) ?? config.oppSamplePeriodMs,
            oppSampleAltMode: clampInt(oppSampleAltMode, config.oppSampleAltMode, 0, 20),
            memfaultConfig: clampInt(memfaultConfig, config.memfaultConfig, 0, 255),
            oppSampleOnTimeMs: UInt32(oppSampleOnTimeMs) ?? config.oppSampleOnTimeMs,
            acc2gDuringSleepEn: acc2gDuringSleepEn,
            accInactivityConfig: clampInt(accInactivityConfig, config.accInactivityConfig, 0, 200),
            ppgStopConfig: clampInt(ppgStopConfig, config.ppgStopConfig, 0, 255),
            ppgAgcChannelConfig: clampInt(ppgAgcChannelConfig, config.ppgAgcChannelConfig, 0, 255),
            sleepThreshConfig: clampInt(sleepThreshConfig, config.sleepThreshConfig, 0, 255),
            csMode: clampInt(csMode, config.csMode, 0, 3),
            resetRingCfg: clampInt(resetRingCfg, config.resetRingCfg, 0, 50),
            edaSweepParamCfg: clampInt(edaSweepParamCfg, config.edaSweepParamCfg, 0, 255),
            dailyDaqModeCfg: clampInt(dailyDaqModeCfg, config.dailyDaqModeCfg, 0, 255)
        )
        onUpdate(newConfig, applyImmediately)
    }
}

// MARK: - Helpers

private struct ConfigToggle: View {
    let label: String
    @Binding var isOn: Bool
    let enabled: Bool

    init(_ label: String, isOn: Binding<Bool>, enabled: Bool) {
        self.label = label
        self._isOn = isOn
        self.enabled = enabled
    }

    var body: some View {
        Toggle(label, isOn: $isOn)
            .disabled(!enabled)
            .opacity(enabled ? 1.0 : 0.38)
    }
}

private struct ConfigField: View {
    let label: String
    @Binding var text: String
    let enabled: Bool

    init(_ label: String, text: Binding<String>, enabled: Bool) {
        self.label = label
        self._text = text
        self.enabled = enabled
    }

    var body: some View {
        TextField(label, text: $text)
            .disabled(!enabled)
            .opacity(enabled ? 1.0 : 0.38)
    }
}

func fwBuildAtLeast(_ fwVersion: String?, minBuild: Int) -> Bool {
    guard let fwVersion = fwVersion else { return false }
    let parts = fwVersion.split(separator: ".")
    guard parts.count >= 4 else { return false }
    guard let project = Int(parts[0]),
          let major = Int(parts[1]),
          let minor = Int(parts[2]),
          let build = Int(String(parts[3]).components(separatedBy: "-").first ?? "") else { return false }
    if project > 2 || (project == 2 && major > 5) { return true }
    if project == 2 && major == 5 && minor > 0 { return true }
    return project == 2 && major == 5 && minor == 0 && build >= minBuild
}

private func modeMinBuild(_ mode: Int) -> Int {
    switch mode {
    case 0: return Int.max
    case 1...7: return 12
    case 8...11: return 15
    case 12...13: return 16
    case 14...16: return 29
    case 17...18: return 22
    case 19...20: return 25
    case 21: return 32
    case 22...23: return 33
    case 24: return 35
    case 25...26: return 52
    default: return Int.max
    }
}

private func modeName(_ mode: Int) -> String {
    switch mode {
    case 1: return "Default"
    case 2: return "Blood Pressure (Reserved)"
    case 3: return "Quick Check"
    case 4: return "Lifestyle"
    case 5: return "Night"
    case 6: return "Night+QuickCheck"
    case 7: return "Night+Lifestyle"
    case 8: return "Quick Check V2"
    case 9: return "Night V2"
    case 10: return "Night V2 + Quick Check V2"
    case 11: return "Lifestyle V2"
    case 12: return "Quick Check V3"
    case 13: return "Night V3"
    case 14: return "Night V3 + QC V3"
    case 15: return "Lifestyle V3"
    case 16: return "Night V3 + LS V3"
    case 17: return "Night V4"
    case 18: return "Night V4 + QC V3"
    case 19: return "Night V5"
    case 20: return "Night V5 + QC V3"
    case 21: return "Blood Pressure"
    case 22: return "Night V6"
    case 23: return "Night V6 + QC V3"
    case 24: return "Night V7"
    case 25: return "Night V8"
    case 26: return "Night V8 + QC V3"
    default: return "Unknown(\(mode))"
    }
}
