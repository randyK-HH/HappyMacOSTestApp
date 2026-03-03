import SwiftUI

struct MemfaultReleasesSheet: View {
    let connId: Int32
    @EnvironmentObject var viewModel: TestAppViewModel
    @Environment(\.dismiss) private var dismiss

    private var isDownloading: Bool {
        viewModel.memfaultDownloadingConnId == connId
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.memfaultReleases.isEmpty && viewModel.memfaultLoading {
                    ProgressView("Loading releases...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.memfaultReleases.isEmpty, let error = viewModel.memfaultError {
                    Text(error)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.memfaultReleases) { release in
                            let isThisDownloading = isDownloading && viewModel.memfaultDownloadVersion == release.version

                            Button {
                                if !isDownloading {
                                    viewModel.downloadMemfaultRelease(version: release.version, connId: connId)
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(release.version)
                                            .fontWeight(.bold)
                                        Text(formatDate(release.createdDate))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if isThisDownloading {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                }
                            }
                            .disabled(isDownloading)
                            .onAppear {
                                // Auto-pagination
                                if release.id == viewModel.memfaultReleases.last?.id {
                                    viewModel.loadMoreMemfaultReleases()
                                }
                            }
                        }

                        if viewModel.memfaultLoading && !viewModel.memfaultReleases.isEmpty {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .controlSize(.small)
                                Spacer()
                            }
                        }

                        if let error = viewModel.memfaultError, !viewModel.memfaultReleases.isEmpty {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }

                        if !viewModel.memfaultHasMore && !viewModel.memfaultLoading && !viewModel.memfaultReleases.isEmpty {
                            Text("\(viewModel.memfaultReleases.count) releases loaded")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Memfault Releases")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isDownloading)
                }
            }
            .onChange(of: viewModel.fwImageInfoMap[connId] != nil) { hasImage in
                if hasImage && !isDownloading {
                    dismiss()
                }
            }
        }
    }

    private func formatDate(_ isoDate: String) -> String {
        guard !isoDate.isEmpty else { return "" }
        let trimmed = isoDate.replacingOccurrences(of: #"\.[0-9]+.*"#, with: "", options: .regularExpression)
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        parser.timeZone = TimeZone(identifier: "UTC")
        guard let date = parser.date(from: trimmed) else { return String(isoDate.prefix(10)) }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
