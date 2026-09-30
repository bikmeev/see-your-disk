import SwiftUI

struct MapView: View {
    @Bindable var model: AppModel

    var body: some View {
        if let node = model.current {
            VStack(spacing: 0) {
                breadcrumb
                HStack(spacing: 0) {
                    DieView(node: node,
                            selectedID: model.selected?.id,
                            ticked: model.selectedCandidates.map { ($0.url.path, $0.size) },
                            hovered: $model.hovered,
                            onSelect: { model.selected = $0 },
                            onOpen: { model.open($0) })
                    Divider()
                    Inspector(model: model, node: model.selected ?? node)
                        .frame(width: 320)
                }
            }
        }
    }

    private var breadcrumb: some View {
        HStack(spacing: 6) {
            Button { model.back() } label: { Image(systemName: "chevron.left") }
                .disabled(model.trail.count < 2)
            ForEach(Array(model.trail.enumerated()), id: \.offset) { i, n in
                if i > 0 { Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary) }
                Button(n.displayName) { model.goTo(i) }
                    .buttonStyle(.plain)
                    .fontWeight(i == model.trail.count - 1 ? .semibold : .regular)
                    .foregroundStyle(i == model.trail.count - 1 ? .primary : .secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.bar)
    }
}

private struct Inspector: View {
    @Bindable var model: AppModel
    let node: FileNode

    /// A folder whose content is one child of (almost) the same size, e.g. `App.app` → `Contents`.
    private var wrapperChild: FileNode? {
        let real = node.children.filter { !$0.synthetic }
        guard real.count == 1, let c = real.first, node.size > 0,
              Double(c.size) >= Double(node.size) * 0.97 else { return nil }
        return c
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(Palette.color(node.kind)).frame(width: 9, height: 9)
                        Text(Palette.label(node.kind)).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(verbatim: node.displayName).font(.headline).lineLimit(2)
                    Text(verbatim: formatBytes(node.size))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.color(node.kind))
                    if let p = node.url?.path {
                        Text(verbatim: p).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(3).textSelection(.enabled)
                    }
                }
                if let inner = wrapperChild {
                    Label {
                        Text("Same size as the only folder inside it, “\(inner.displayName)”. That is one folder nested in another, not a copy, so nothing is counted twice.")
                            .font(.callout)
                    } icon: { Image(systemName: "square.on.square") }
                    .foregroundStyle(.secondary)
                }
                HStack {
                    if node.canDrill && node.id != model.current?.id {
                        Button("Open") { model.open(node) }
                    }
                    if let url = node.url { Button("Show in Finder") { model.reveal(url) } }
                }
                Divider()
                if node.id == "#system" {
                    UnreadableInfo(model: model, node: node)
                } else if node.synthetic && !node.folded.isEmpty {
                    FoldedList(node: node)
                } else {
                    CleanPanel(model: model, node: node)
                }
                Divider()
                Legend()
            }
            .padding(14)
        }
    }
}

private struct Legend: View {
    private let kinds: [NodeKind] = [.system, .systemData, .apps, .documents, .developer, .appData, .media, .other]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Legend").font(.caption).foregroundStyle(.secondary)
            ForEach(kinds, id: \.self) { k in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3).fill(Palette.color(k).opacity(0.8)).frame(width: 12, height: 12)
                    Text(Palette.label(k)).font(.callout)
                }
            }
            Divider().padding(.vertical, 2)
            Text("Click to select · double-click to open").font(.callout).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                StripeSwatch()
                Text("selected for cleaning").font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

/// What is inside a "Small items" block.
private struct FoldedList: View {
    let node: FileNode
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Too small to get their own blocks, so they are combined here. Different items, not copies of each other.")
                .font(.callout).foregroundStyle(.secondary)
            Text("Largest of them").font(.caption).foregroundStyle(.secondary)
            ForEach(Array(node.folded.enumerated()), id: \.offset) { _, item in
                HStack {
                    Text(verbatim: item.name).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 6)
                    Text(verbatim: formatBytes(item.size)).foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        }
    }
}

/// Everything macOS keeps outside your Home folder.
private struct UnreadableInfo: View {
    let model: AppModel
    let node: FileNode

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This is everything on the disk outside your Home folder and Applications: macOS itself, system files, caches kept by the system, and snapshots. macOS does not let apps look inside.")
                .font(.callout)
            Text("Usually it is:").font(.caption).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Label("The macOS system itself", systemImage: "macwindow")
                Label("APFS snapshots, for example after a macOS update", systemImage: "clock.arrow.circlepath")
                Label("System indexes, logs and metadata", systemImage: "list.bullet.rectangle")
            }
            .font(.callout).foregroundStyle(.secondary)
            Text("Nothing here can be cleaned from the app. To reduce it, restart your Mac and install pending macOS updates.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}

/// Tiny striped sample, the same look as blocks selected for cleaning.
private struct StripeSwatch: View {
    var body: some View {
        Canvas { ctx, size in
            let r = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
            ctx.stroke(Path(roundedRect: r, cornerRadius: 3), with: .color(.secondary), lineWidth: 1)
            DieStyle.stripes(&ctx, rect: r, radius: 3)
        }
        .frame(width: 22, height: 14)
    }
}
