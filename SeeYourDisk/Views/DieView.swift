import SwiftUI

/// Shared look for every block in the app: flat, minimal, one thin edge per block.
/// The chip-die idea only survives as the layout language (blocks inside blocks).
enum DieStyle {
    /// Diagonal stripes = "selected for cleaning".
    static func stripes(_ ctx: inout GraphicsContext, rect r: CGRect, radius: CGFloat) {
        ctx.drawLayer { l in
            l.clip(to: Path(roundedRect: r, cornerRadius: radius))
            var h = Path()
            var x = r.minX - r.height
            while x < r.maxX { h.move(to: CGPoint(x: x, y: r.maxY)); h.addLine(to: CGPoint(x: x + r.height, y: r.minY)); x += 9 }
            l.stroke(h, with: .color(.white.opacity(0.28)), lineWidth: 1.5)
        }
    }

    static let background = Color(red: 0.045, green: 0.05, blue: 0.065)

    static func block(_ ctx: inout GraphicsContext, rect r: CGRect, color: Color, strength: Double = 1,
                      radius: CGFloat = 6, hover: Bool = false, selected: Bool = false, horizontal: Bool = true) {
        guard r.width > 2, r.height > 2 else { return }
        let path = Path(roundedRect: r, cornerRadius: radius)
        ctx.fill(path, with: .color(color.opacity(min(0.5, 0.16 * strength * (hover ? 1.5 : 1)))))
        ctx.stroke(path, with: .color(selected ? .white : color.opacity(hover ? 0.95 : 0.5)),
                   lineWidth: selected ? 2 : 1)
    }
}

struct DieCell: Identifiable {
    let node: FileNode
    let rect: CGRect
    let depth: Int
    var id: String { "\(depth)|\(node.id)" }
}

enum DieLayout {
    static func build(_ node: FileNode, in rect: CGRect) -> [DieCell] {
        var cells: [DieCell] = []
        let top = items(node.children, limit: 36)
        let rects = Treemap.layout(values: top.map { Double($0.size) }, in: rect)
        for (n, r) in zip(top, rects) {
            let block = r.insetBy(dx: 2, dy: 2)
            cells.append(DieCell(node: n, rect: block, depth: 0))
            guard n.canDrill, block.width > 110, block.height > 70 else { continue }
            let inner = CGRect(x: block.minX + 5, y: block.minY + 22,
                               width: block.width - 10, height: block.height - 27)
            let subs = items(n.children, limit: 14)
            let subRects = Treemap.layout(values: subs.map { Double($0.size) }, in: inner)
            for (s, sr) in zip(subs, subRects) {
                cells.append(DieCell(node: s, rect: sr.insetBy(dx: 1.5, dy: 1.5), depth: 1))
            }
        }
        return cells
    }

    /// Top `limit` children; the tail is folded into one synthetic block.
    private static func items(_ children: [FileNode], limit: Int) -> [FileNode] {
        let sorted = children.filter { $0.size > 0 }.sorted { $0.size > $1.size }
        guard sorted.count > limit else { return sorted }
        let head = Array(sorted.prefix(limit))
        let rest = sorted.dropFirst(limit)
        let folded = FileNode(id: "\(head.first?.id ?? "")#rest", name: "\(rest.count)", url: nil,
                              size: rest.reduce(0) { $0 + $1.size }, isDirectory: false,
                              kind: head.first?.kind ?? .other, synthetic: true)
        folded.folded = rest.prefix(30).map { ($0.displayName, $0.size) }
        return head + [folded]
    }
}

struct DieView: View {
    let node: FileNode
    let selectedID: String?
    let ticked: [(path: String, size: Int64)]   // candidates ticked for cleaning
    @Binding var hovered: FileNode?
    let onSelect: (FileNode?) -> Void
    let onOpen: (FileNode) -> Void

    @State private var hoverPoint: CGPoint = .zero
    private let margin: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let frame = CGRect(origin: .zero, size: geo.size).insetBy(dx: margin, dy: margin)
            let isRoot = node.id == "/"
            // At the top level the whole disk is one big block: "Your laptop".
            let inner = isRoot ? CGRect(x: frame.minX + 8, y: frame.minY + 36,
                                        width: frame.width - 16, height: frame.height - 44) : frame
            let cells = DieLayout.build(node, in: inner)
            let hoveredID = hovered?.id
            Canvas { ctx, _ in
                if isRoot {
                    DieStyle.block(&ctx, rect: frame, color: .white, strength: 0.2, radius: 12,
                                   selected: selectedID == nil)
                    let title = ctx.resolve(Text(verbatim: node.displayName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundColor(.white))
                    let size = ctx.resolve(Text(verbatim: formatBytes(node.size))
                        .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundColor(.white.opacity(0.6)))
                    ctx.draw(title, at: CGPoint(x: frame.minX + 14, y: frame.minY + 10), anchor: .topLeading)
                    ctx.draw(size, at: CGPoint(x: frame.maxX - 14, y: frame.minY + 10), anchor: .topTrailing)
                }
                for c in cells where c.depth == 0 { draw(&ctx, c, hoveredID: hoveredID) }
                for c in cells where c.depth == 1 { draw(&ctx, c, hoveredID: hoveredID) }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let p): hoverPoint = p; hovered = hit(cells, p)?.node
                case .ended: hovered = nil
                }
            }
            .onTapGesture(count: 2) { p in
                if let n = hit(cells, p)?.node { onOpen(n) }
            }
            .onTapGesture { p in
                onSelect(hit(cells, p)?.node)   // click on the background clears the selection
            }
            .overlay(alignment: .topLeading) {
                if let h = hovered {
                    Tooltip(node: h)
                        .offset(x: min(hoverPoint.x + 14, max(0, geo.size.width - 200)),
                                y: min(hoverPoint.y + 14, max(0, geo.size.height - 60)))
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.12), value: hoveredID)
        }
        .background(DieStyle.background)
    }

    private var tickedPaths: Set<String> { Set(ticked.map(\.path)) }

    private func hit(_ cells: [DieCell], _ p: CGPoint) -> DieCell? {
        cells.last(where: { $0.rect.contains(p) })
    }

    /// Walks up the path: is this node a cleanup candidate, or inside one?
    private func matches(_ n: FileNode, in set: Set<String>) -> Bool {
        guard var url = n.url, !set.isEmpty else { return false }
        for _ in 0..<14 {
            if set.contains(url.path) { return true }
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path { break }
            url = parent
        }
        return false
    }

    private func draw(_ ctx: inout GraphicsContext, _ c: DieCell, hoveredID: String?) {
        let r = c.rect
        guard r.width > 2, r.height > 2 else { return }
        let color = Palette.color(c.node.kind)
        let isHover = c.node.id == hoveredID
        let hasSubs = c.depth == 0 && c.node.canDrill && r.width > 110 && r.height > 70
        let radius: CGFloat = c.depth == 0 ? 7 : 5
        let horizontal = abs(c.node.id.hashValue) % 2 == 0

        DieStyle.block(&ctx, rect: r, color: color, strength: hasSubs ? 0.55 : (c.depth == 0 ? 1 : 1.25),
                       radius: radius, hover: isHover, selected: c.node.id == selectedID, horizontal: horizontal)

        if !hasSubs, let p = c.node.url?.path {
            if matches(c.node, in: tickedPaths) {
                DieStyle.stripes(&ctx, rect: r, radius: radius)               // the whole block goes
            } else {
                let inside = ticked.reduce(Int64(0)) { $0 + ($1.path.hasPrefix(p + "/") ? $1.size : 0) }
                if inside > 0 {                                                // part of it goes: stripe that share
                    let f = min(1, max(0.06, Double(inside) / Double(max(c.node.size, 1))))
                    DieStyle.stripes(&ctx, rect: CGRect(x: r.minX, y: r.minY, width: r.width * f, height: r.height),
                                     radius: radius)
                }
            }
        }

        if r.width > 56, r.height > (hasSubs ? 22 : 30) {
            let title = ctx.resolve(Text(verbatim: c.node.displayName)
                .font(.system(size: c.depth == 0 ? 12 : 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.95)))
            let sizeText = ctx.resolve(Text(verbatim: formatBytes(c.node.size))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(color))
            let sw = sizeText.measure(in: CGSize(width: 400, height: 30)).width
            var tctx = ctx
            let titleWidth = hasSubs ? max(0, r.width - sw - 24) : r.width - 12
            tctx.clip(to: Path(CGRect(x: r.minX + 4, y: r.minY, width: titleWidth + 4, height: r.height)))
            tctx.draw(title, at: CGPoint(x: r.minX + 8, y: r.minY + 6), anchor: .topLeading)
            if hasSubs, titleWidth > 20 {
                ctx.draw(sizeText, at: CGPoint(x: r.maxX - 8, y: r.minY + 6), anchor: .topTrailing)
            } else if !hasSubs, r.height > 46 {
                var sctx = ctx
                sctx.clip(to: Path(r.insetBy(dx: 4, dy: 2)))
                sctx.draw(sizeText, at: CGPoint(x: r.minX + 8, y: r.minY + 22), anchor: .topLeading)
            }
        }
    }
}

private struct Tooltip: View {
    let node: FileNode
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: node.displayName).font(.callout.weight(.semibold)).lineLimit(1)
            Text(verbatim: formatBytes(node.size)).font(.caption).foregroundStyle(Palette.color(node.kind))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.15)))
    }
}
