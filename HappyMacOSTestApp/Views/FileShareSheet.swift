import SwiftUI

struct FileShareSheet: View {
    @ObservedObject var viewModel: TestAppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                hpy2FilesView
                    .tabItem { Label("HPY2 Data", systemImage: "doc.fill") }
                    .tag(0)

                eventLogFilesView
                    .tabItem { Label("Event Logs", systemImage: "list.bullet.rectangle") }
                    .tag(1)
            }
            .navigationTitle("Share Files")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var hpy2FilesView: some View {
        let files = viewModel.listHpy2Files()

        return Group {
            if files.isEmpty {
                Text("No .hpy2 files found.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section(header: Text("Click a file to reveal in Finder, or use the share button")) {
                        ForEach(files, id: \.absoluteString) { url in
                            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
                            let frames = size / 4096

                            HStack {
                                VStack(alignment: .leading) {
                                    Text(url.lastPathComponent)
                                        .fontWeight(.medium)
                                    Text("\(frames) frames (\(size / 1024) KB)")
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
        }
    }

    private var eventLogFilesView: some View {
        let files = viewModel.listEventLogFiles()

        return Group {
            if files.isEmpty {
                Text("No event log files found.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        }
    }
}
