import SwiftUI

/// Progress while cleaning, then the result with a button to rescan.
struct CleaningSheet: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            if model.isCleaning {
                Text("Cleaning…").font(.title2.bold())
                ProgressView(value: Double(model.cleanDone), total: Double(max(model.cleanTotal, 1)))
                Text("\(model.cleanDone) of \(model.cleanTotal) · \(formatBytes(model.cleanBytes))")
                    .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                Text(verbatim: model.cleanCurrent).font(.caption).foregroundStyle(.tertiary)
                    .lineLimit(1).truncationMode(.middle)
            } else if let r = model.lastResult {
                Image(systemName: r.failed > 0 && r.done == 0 ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(r.failed > 0 && r.done == 0 ? Color.orange : Color.green)
                Text("Cleaning finished").font(.title2.bold())
                Text(verbatim: message(r)).multilineTextAlignment(.center).foregroundStyle(.secondary)
                Text("The map still shows the old sizes. Rescan to see the current state.")
                    .font(.caption).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                HStack {
                    Button("Later") { model.lastResult = nil }
                    Button("Rescan") { model.lastResult = nil; model.startScan() }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                }
                .controlSize(.large)
            }
        }
        .padding(28)
        .frame(width: 380)
    }

    private func message(_ r: CleanResult) -> String {
        var lines: [String] = []
        if r.freed > 0 { lines.append(String(localized: "Freed \(formatBytes(r.freed)).")) }
        if r.movedToTrash {
            lines.append(String(localized: "Moved \(formatBytes(r.trashed)) to the Trash. Empty the Trash to free the space."))
        }
        if r.failed > 0 { lines.append(String(localized: "\(r.failed) items could not be removed.")) }
        if lines.isEmpty { lines.append(String(localized: "Nothing was removed.")) }
        return lines.joined(separator: "\n")
    }
}
