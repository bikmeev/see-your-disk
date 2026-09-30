import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var onboarded = false
    @State private var model = AppModel()
    @State private var access = HomeAccess()

    var body: some View {
        Group {
            if !onboarded {
                OnboardingView { onboarded = true }
            } else if !access.granted {
                AccessView(access: access)
            } else {
                MainView(model: model)
            }
        }
        .frame(minWidth: 980, minHeight: 640)
    }
}

private struct MainView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            // One branch for scanning and the finished-but-still-playing state, so the game keeps its state.
            if model.phase != .done || model.gameActive {
                ScanView(model: model)
            } else {
                if model.skippedDirs > 0 { permissionBanner }
                MapView(model: model)
            }
        }
        .task { if model.phase == .idle { model.startScan() } }
        .sheet(isPresented: $model.showPaywall) { PaywallView(model: model) }
        .toolbar { ToolbarItem(placement: .primaryAction) { SettingsMenu(model: model) } }
        .confirmationDialog(confirmTitle, isPresented: Binding(get: { model.pending != nil },
                                                               set: { if !$0 { model.pending = nil } }),
                            titleVisibility: .visible) {
            Button("Clean") { model.confirmPending() }
            Button("Cancel", role: .cancel) { model.pending = nil }
        } message: {
            Text("Safe items (caches, logs) are deleted permanently and regenerate on their own. Other items are moved to the Trash.")
        }
        .sheet(isPresented: Binding(get: { model.isCleaning || model.lastResult != nil },
                                    set: { if !$0 { model.lastResult = nil } })) {
            CleaningSheet(model: model)
                .interactiveDismissDisabled(model.isCleaning)
        }
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            if let v = model.volume {
                VStack(alignment: .leading, spacing: 2) {
                    ProgressView(value: Double(v.used), total: Double(max(v.total, 1)))
                        .frame(width: 180)
                    Text("\(formatBytes(v.used)) used of \(formatBytes(v.total))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if model.phase == .done {
                Button { model.requestClean(model.safeCandidates) } label: {
                    Label("Auto clean · \(formatBytes(model.reclaimableSafe))", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.safeCandidates.isEmpty || model.isCleaning)
                .help("Removes only what is safe to delete: caches, logs, build leftovers")
            }
            Button { model.startScan() } label: { Label("Rescan", systemImage: "arrow.clockwise") }
                .disabled(model.phase == .scanning)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var permissionBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text("Some folders are protected by macOS and were skipped, so the map may be slightly incomplete.")
                .font(.callout)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.yellow.opacity(0.12))
    }

    private var confirmTitle: String {
        let items = model.pending ?? []
        return String(localized: "Clean \(items.count) items (\(formatBytes(items.reduce(0) { $0 + $1.size })))?")
    }

}

#Preview {
    ContentView()
}
