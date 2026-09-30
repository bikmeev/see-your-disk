import SwiftUI

/// What can be cleaned inside the selected block. Safe items come pre-ticked.
struct CleanPanel: View {
    @Bindable var model: AppModel
    let node: FileNode

    private var items: [Candidate] { model.candidates(in: node) }
    private var ticked: [Candidate] { items.filter { model.selection.contains($0.id) } }
    private var tickedBytes: Int64 { ticked.reduce(0) { $0 + $1.size } }

    var body: some View {
        let items = self.items
        VStack(alignment: .leading, spacing: 10) {
            if items.isEmpty {
                Label("Nothing to clean in this block.", systemImage: "checkmark.circle")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                HStack {
                    Text("Can be cleaned").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Auto-select") { model.autoSelect(in: node) }.buttonStyle(.link).font(.caption)
                    Button("None") { model.deselect(in: node) }.buttonStyle(.link).font(.caption)
                }
                ForEach(items.prefix(40)) { row($0) }
                if items.count > 40 {
                    Text("+\(items.count - 40) more").font(.caption).foregroundStyle(.tertiary)
                }
                Button {
                    model.requestClean(ticked)
                } label: {
                    Text("Clean selected (\(formatBytes(tickedBytes)))").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(ticked.isEmpty || model.isCleaning)
            }
        }
    }

    private func row(_ c: Candidate) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Toggle("", isOn: Binding(get: { model.selection.contains(c.id) }, set: { _ in model.toggle(c) }))
                .toggleStyle(.checkbox).labelsHidden()
                .disabled(c.safety == .protected)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(verbatim: c.title).font(.callout.weight(.medium)).lineLimit(1).truncationMode(.middle)
                    badge(c.safety)
                }
                Text(LocalizedStringKey(c.detail)).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text(verbatim: formatBytes(c.size)).font(.callout.monospacedDigit())
        }
    }

    @ViewBuilder
    private func badge(_ s: Safety) -> some View {
        switch s {
        case .safe: Text("Safe").badgeStyle(.green)
        case .review: Text("Review").badgeStyle(.orange)
        case .protected: Text("Protected").badgeStyle(.red)
        }
    }
}

private extension Text {
    func badgeStyle(_ color: Color) -> some View {
        font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}
