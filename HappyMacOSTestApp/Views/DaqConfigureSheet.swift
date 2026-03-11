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
        VStack(spacing: 0) {
            // Title bar
            Text("Configure DAQ")
                .font(.headline)
                .padding(.vertical, 10)

            Divider()

            // Scrollable content
            ScrollView {
                VStack(spacing: 12) {
                    GroupBox("General") {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Apply Immediately", isOn: $applyImmediately)
                            Picker("DAQ Mode", selection: $mode) {
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
                    }

                    GroupBox("Ambient Light") {
                        VStack(alignment: .leading, spacing: 8) {
                            ConfigToggle("Enable", isOn: $ambientLightEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                            ConfigField("Period (ms)", hint: "1000-60000", text: $ambientLightPeriodMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                        }
                    }

                    GroupBox("Temperature") {
                        VStack(alignment: .leading, spacing: 8) {
                            ConfigToggle("Ambient Temp Enable", isOn: $ambientTempEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ambient Temp Period (ms)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Tied to EDA sampling, not configurable")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                TextField("", text: .constant("\(config.ambientTempPeriodMs)"))
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(true)
                                    .opacity(0.38)
                            }
                            ConfigToggle("Skin Temp Enable", isOn: $skinTempEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                            ConfigField("Skin Temp Period (ms)", hint: "1000-60000", text: $skinTempPeriodMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                        }
                    }

                    GroupBox("PPG") {
                        VStack(alignment: .leading, spacing: 8) {
                            ConfigField("Cycle Time (ms)", hint: "Periodic ON/OFF duration (1000-3600000)", text: $ppgCycleTimeMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                            ConfigField("Interval Time (ms)", hint: "LED on duration within cycle (1000-3600000)", text: $ppgIntervalTimeMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                            ConfigToggle("Enabled During Sleep Only (Off = Always On)", isOn: $ppgOnDuringSleepEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                            ConfigField("Full Scale Range (FSR)", hint: "0=FW Default 4K, 1=4K, 2=8K, 3=16K, 4=32K, 5=Legacy 16K \u{00B5}A", text: $ppgFsr, enabled: fwBuildAtLeast(fwVersion, minBuild: 16))
                            ConfigField("Stop Config", hint: "Bit 7: Enable. Bits 5:0: Battery SOC% at which PPG stops (1-50%)", text: $ppgStopConfig, enabled: fwBuildAtLeast(fwVersion, minBuild: 41))
                            ConfigField("AGC Channel Config", hint: "Per channel (bits 7:6/5:4/3:2/1:0): 00=Off, 01=On", text: $ppgAgcChannelConfig, enabled: fwBuildAtLeast(fwVersion, minBuild: 44))
                        }
                    }

                    GroupBox("Compressed Sensing") {
                        VStack(alignment: .leading, spacing: 8) {
                            ConfigToggle("Enable (IR/Ambient Only)", isOn: $compressedSensingEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                            ConfigField("CS Mode", hint: "0=IR Only, 1=IR/R, 2=IR/G, 3=Reserved", text: $csMode, enabled: fwBuildAtLeast(fwVersion, minBuild: 55))
                        }
                    }

                    GroupBox("Multi-Spectral") {
                        VStack(alignment: .leading, spacing: 8) {
                            ConfigToggle("Enable", isOn: $multiSpectralEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 12))
                            ConfigField("Sample Period (ms)", hint: "0=Sample on DAQ enable only, else 10000-3600000", text: $multiSpectralPeriodMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 16))
                        }
                    }

                    GroupBox("Superframe") {
                        VStack(alignment: .leading, spacing: 8) {
                            ConfigField("Max Open Time (ms)", hint: "0=Disabled. Close superframe early if duration exceeds limit (2000-20000)", text: $sfMaxLatencyMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 16))
                        }
                    }

                    GroupBox("EDA Sweep") {
                        VStack(alignment: .leading, spacing: 8) {
                            ConfigToggle("Enable", isOn: $edaSweepEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 28))
                            ConfigField("Period (ms)", hint: "0=Disabled, else 60000-3600000 (60s to 1hr)", text: $edaSweepPeriodMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 28))
                            ConfigField("Param Config", hint: "Bit 7: Enable optional configs. Bit 6: AGC. Bit 5: Clear AGC every Nth sweep", text: $edaSweepParamCfg, enabled: fwBuildAtLeast(fwVersion, minBuild: 69))
                        }
                    }

                    GroupBox("Accelerometer") {
                        VStack(alignment: .leading, spacing: 8) {
                            ConfigField("Ultra Low Power (ULP) Config", hint: "Bit 0: ULP enable. Bit 2: Reduced data mode during sleep", text: $accUlpEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 22))
                            ConfigToggle("Increase Resolution During Sleep (8G\u{2192}2G)", isOn: $acc2gDuringSleepEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 36))
                            ConfigField("Inactivity Config", hint: "Activity threshold for opportunistic sampling trigger (0-200)", text: $accInactivityConfig, enabled: fwBuildAtLeast(fwVersion, minBuild: 40))
                        }
                    }

                    GroupBox("Opportunistic Sampling") {
                        VStack(alignment: .leading, spacing: 8) {
                            ConfigToggle("Enable", isOn: $oppSampleEn, enabled: fwBuildAtLeast(fwVersion, minBuild: 30))
                            ConfigField("Period (ms)", hint: "0=Default (3h). Range: 1800000-57600000 (30min to 16hr)", text: $oppSamplePeriodMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 30))
                            ConfigField("ON Time (ms)", hint: "0=Default (60s). Range: 10000-3600000 (10s to 1hr)", text: $oppSampleOnTimeMs, enabled: fwBuildAtLeast(fwVersion, minBuild: 31))
                            ConfigField("Sampling Mode", hint: "0=Use standard DAQ mode, 3-20=Alternate PPG sampling mode", text: $oppSampleAltMode, enabled: fwBuildAtLeast(fwVersion, minBuild: 30))
                        }
                    }

                    GroupBox("Memfault") {
                        VStack(alignment: .leading, spacing: 8) {
                            ConfigField("Memfault Access Config", hint: "Bit 7: Enable. Bits 4:3: Min log level. Bit 2: Logs. Bit 1: Events. Bit 0: Core dumps", text: $memfaultConfig, enabled: fwBuildAtLeast(fwVersion, minBuild: 30))
                        }
                    }

                    GroupBox("Sleep") {
                        VStack(alignment: .leading, spacing: 8) {
                            ConfigField("Sleep Threshold Config", hint: "Bit 7: Enable. Bit 6: Direction (1=increase, 0=decrease). Bit 5: Lock on entry. Bits 3:0: Multiplier power", text: $sleepThreshConfig, enabled: fwBuildAtLeast(fwVersion, minBuild: 45))
                        }
                    }

                    GroupBox("Reset") {
                        VStack(alignment: .leading, spacing: 8) {
                            ConfigField("Reset After N Days", hint: "0=Disabled. 1-50 days. Ring must be disconnected, DAQ off, SOC \u{2265}50%", text: $resetRingCfg, enabled: fwBuildAtLeast(fwVersion, minBuild: 60))
                        }
                    }

                    GroupBox("Daily DAQ Mode") {
                        VStack(alignment: .leading, spacing: 8) {
                            ConfigField("Daily DAQ Mode Config", hint: "Bit 7: Enable. Bit 6: Sample during sleep only", text: $dailyDaqModeCfg, enabled: fwBuildAtLeast(fwVersion, minBuild: 76))
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Fixed button bar
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Update") { submitUpdate() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 520, height: 650)
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
    let hint: String?
    @Binding var text: String
    let enabled: Bool

    init(_ label: String, hint: String? = nil, text: Binding<String>, enabled: Bool) {
        self.label = label
        self.hint = hint
        self._text = text
        self.enabled = enabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(enabled ? .primary : .secondary)
            if let hint = hint {
                Text(hint)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            TextField("", text: $text)
                .textFieldStyle(.roundedBorder)
                .disabled(!enabled)
                .opacity(enabled ? 1.0 : 0.38)
        }
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
    case 0: return Int.max       // All Sensors Off (not available)
    case 1: return 12            // Nominal (No PPG)
    case 2: return Int.max       // Nominal (No EDA, PPG) (not available)
    case 3...7: return 12        // Nominal+PPG IR, SPO2-50/100, HR-50/100
    case 8: return 15            // HR - 200
    case 9...10: return 15       // IR - 200 - 1/2
    case 11: return 15           // SPO2 - 200
    case 12: return 16           // PTT - 100
    case 13: return 16           // ACC - HI FREQ - LO RES
    case 14...16: return 29      // IR-400, G-400, R-400
    case 17...18: return 22      // ACC - Low Power 1/2
    case 19...20: return 25      // RGBIR - 50/100
    case 21: return 32           // PTT - 200
    case 22...23: return 33      // ACC 52Hz - 8G/2G
    case 24: return 35           // ACC - 104Hz - 8G
    case 25...26: return 52      // RGBIR-100 - ACC 104Hz - 8G/2G
    default: return Int.max
    }
}

private func modeName(_ mode: Int) -> String {
    switch mode {
    case 0: return "All Sensors Off"
    case 1: return "Nominal (No PPG)"
    case 2: return "Nominal (No EDA, PPG)"
    case 3: return "Nominal + PPG IR"
    case 4: return "SPO2 - 50"
    case 5: return "SPO2 - 100"
    case 6: return "HR - 50"
    case 7: return "HR - 100"
    case 8: return "HR - 200"
    case 9: return "IR - 200 - 1"
    case 10: return "IR - 200 - 2"
    case 11: return "SPO2 - 200"
    case 12: return "PTT - 100"
    case 13: return "ACC - HI FREQ - LO RES"
    case 14: return "IR - 400"
    case 15: return "G - 400"
    case 16: return "R - 400"
    case 17: return "ACC - Low Power - 1"
    case 18: return "ACC - Low Power - 2"
    case 19: return "RGBIR - 50"
    case 20: return "RGBIR - 100"
    case 21: return "PTT - 200"
    case 22: return "ACC 52Hz - 8G"
    case 23: return "ACC 52Hz - 2G"
    case 24: return "ACC - 104Hz - 8G"
    case 25: return "RGBIR - 100 - ACC 104Hz - 8G"
    case 26: return "RGBIR - 100 - ACC 104Hz - 2G"
    default: return "Unknown(\(mode))"
    }
}
