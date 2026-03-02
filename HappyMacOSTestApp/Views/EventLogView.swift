import SwiftUI

struct EventLogSection: View {
    let connId: Int32
    @EnvironmentObject var viewModel: TestAppViewModel
    @State private var showShareSheet = false

    var body: some View {
        let logs = viewModel.connectionLogs[connId] ?? []

        VStack(alignment: .leading) {
            HStack {
                Text("Event Log")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                Spacer()
                Button {
                    let _ = viewModel.saveEventLog(connId: connId)
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                Button { showShareSheet = true } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        if logs.isEmpty {
                            Text("No events yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(8)
                        }
                        ForEach(logs) { entry in
                            LogEntryRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(4)
                }
                .frame(height: 400)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                .onChange(of: logs.last?.id) { _ in
                    if let lastId = logs.last?.id {
                        withAnimation {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            EventLogShareSheet(viewModel: viewModel, deviceId: viewModel.connectedRings[connId]?.name)
                .frame(minWidth: 400, minHeight: 400)
        }
    }
}

struct LogEntryRow: View {
    let entry: LogEntry

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        let timeStr = Self.timeFormatter.string(from: entry.timestamp)
        let isError = entry.message.hasPrefix("ERROR")

        Text("\(timeStr)  \(entry.message)")
            .font(.system(size: 11, design: .monospaced))
            .lineSpacing(2)
            .foregroundColor(isError ? .red : .primary)
    }
}

struct EventLogShareSheet: View {
    @ObservedObject var viewModel: TestAppViewModel
    let deviceId: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            let files = viewModel.listEventLogFiles(deviceId: deviceId)

            if files.isEmpty {
                Text("No saved event logs found.")
                    .padding()
            } else {
                List {
                    Section(header: Text("Click a file to reveal in Finder, or use the share button")) {
                        ForEach(files, id: \.absoluteString) { url in
                            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0

                            HStack {
                                VStack(alignment: .leading) {
                                    Text(url.lastPathComponent)
                                        .fontWeight(.medium)
                                    Text("\(size / 1024) KB")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                ShareLink(item: url) {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    try? FileManager.default.removeItem(at: url)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }

            Spacer()
                .navigationTitle("Event Logs\(deviceId.map { " — \($0)" } ?? "")")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
