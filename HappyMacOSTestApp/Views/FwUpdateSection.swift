import SwiftUI
import UniformTypeIdentifiers
import HappyPlatformAPI

struct FwUpdateSection: View {
    let connId: Int32
    let ring: ConnectedRingInfo
    @EnvironmentObject var viewModel: TestAppViewModel
    @Binding var showShareSheet: Bool

    @State private var showPickerDialog = false
    @State private var showFilePicker = false
    @State private var showMemfaultSheet = false
    @State private var fwElapsedSeconds = 0
    @State private var fwUploadSeconds = 0
    @State private var timerTask: Task<Void, Never>?

    private var isFwUpdating: Bool {
        ring.isFwUpdating || ring.state == .fwUpdating || ring.state == .fwUpdateRebooting
    }

    private var isReady: Bool {
        ring.state == .ready || ring.state == .waiting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FwUpdateSectionHeader(
                title: "FW Update",
                fwUpdateState: ring.fwUpdateState,
                onClear: (viewModel.fwImageInfo != nil && !isFwUpdating) ? { viewModel.clearFwImage() } : nil
            )

            if let info = viewModel.fwImageInfo {
                InfoRow(label: "Image", value: info.fileName)
                InfoRow(label: "Size", value: "\(info.fileSize / 1024) KB")
            }

            if isFwUpdating && ring.fwBlocksTotal > 0 {
                ProgressView(value: Float(ring.fwBlocksSent), total: Float(ring.fwBlocksTotal))
                HStack {
                    Text("\(ring.fwBlocksSent) / \(ring.fwBlocksTotal) blocks (\(ring.fwUpdateState ?? ""))")
                        .font(.caption)
                    Spacer()
                    let timerText = fwUploadSeconds > 0
                        ? "(\(fwUploadSeconds)s) \(fwElapsedSeconds)s"
                        : "\(fwElapsedSeconds)s"
                    Text(timerText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if ring.state == .fwUpdateRebooting {
                Text("Ring rebooting...")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            HStack(spacing: 4) {
                Button("Select Image") { showPickerDialog = true }
                    .buttonStyle(CommandButtonStyle())
                    .disabled(isFwUpdating)
                    .opacity(isFwUpdating ? 0.4 : 1.0)

                if isFwUpdating {
                    let canCancel = ring.state == .fwUpdating
                    Button("Cancel FW") { viewModel.cancelFwUpdate(connId: connId) }
                        .buttonStyle(CommandButtonStyle(tint: .red))
                        .disabled(!canCancel)
                        .opacity(canCancel ? 1.0 : 0.4)
                } else {
                    let canUpdate = viewModel.fwImageInfo != nil && isReady
                    Button("Update") { viewModel.startFwUpdate(connId: connId) }
                        .buttonStyle(CommandButtonStyle())
                        .disabled(!canUpdate)
                        .opacity(canUpdate ? 1.0 : 0.4)
                }
            }
        }
        .onChange(of: isFwUpdating) { newValue in
            if newValue {
                fwElapsedSeconds = 0
                fwUploadSeconds = 0
                timerTask = Task {
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        if !Task.isCancelled {
                            fwElapsedSeconds += 1
                        }
                    }
                }
            } else {
                timerTask?.cancel()
                timerTask = nil
            }
        }
        .onChange(of: ring.fwUpdateState) { newValue in
            if let state = newValue, state != "Uploading", fwUploadSeconds == 0, fwElapsedSeconds > 0 {
                fwUploadSeconds = fwElapsedSeconds
            }
        }
        .confirmationDialog("Select FW Image", isPresented: $showPickerDialog) {
            Button("Browse Files") { showFilePicker = true }
            Button("Memfault") {
                showMemfaultSheet = true
                viewModel.fetchMemfaultReleases()
            }
            Button("Cancel", role: .cancel) { }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.data]) { result in
            if case .success(let url) = result {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                let _ = viewModel.loadFwImage(url: url)
            }
        }
        .sheet(isPresented: $showMemfaultSheet) {
            MemfaultReleasesSheet(connId: connId)
                .frame(minWidth: 400, minHeight: 400)
        }
    }
}

private struct FwUpdateSectionHeader: View {
    let title: String
    let fwUpdateState: String?
    let onClear: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            Spacer()
            if let state = fwUpdateState {
                let color: Color = {
                    if state == "Uploading" { return .blue }
                    if state == "Finalizing" { return .orange }
                    if state.contains("Abort") { return .red }
                    return .secondary
                }()
                Text(state)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            } else if let onClear = onClear {
                Button("CLEAR") { onClear() }
                    .font(.caption)
                    .fontWeight(.bold)
            }
        }
        Divider()
    }
}
