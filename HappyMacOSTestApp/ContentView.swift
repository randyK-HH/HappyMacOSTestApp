import SwiftUI
import HappyPlatformAPI

struct ContentView: View {
    @EnvironmentObject var viewModel: TestAppViewModel
    @State private var selectedConnId: Int32?

    var body: some View {
        HStack(spacing: 0) {
            // Fixed scan panel on the left
            ScanPanel(selectedConnId: $selectedConnId)
                .frame(width: 280)

            Divider()

            // Ring panels on the right
            let sortedRings = viewModel.connectedRings.values.sorted { $0.connId < $1.connId }

            if sortedRings.isEmpty {
                // Empty state
                VStack {
                    Spacer()
                    Text("Connect a ring to see its controls")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(sortedRings) { ring in
                            VStack(spacing: 0) {
                                RingPanel(connId: ring.connId)
                            }
                            .frame(minWidth: 380, maxWidth: .infinity)

                            if ring.connId != sortedRings.last?.connId {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }
}

// Make Int32 work with ForEach
extension Int32: Identifiable {
    public var id: Int32 { self }
}
