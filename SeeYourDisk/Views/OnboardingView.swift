import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private struct Page {
        let icon: String
        let title: LocalizedStringKey
        let text: LocalizedStringKey
    }

    private let pages: [Page] = [
        Page(icon: "cpu",
             title: "See where your disk went",
             text: "See Your Disk turns your storage into a chip map. Every block is a folder, and its size shows how much space it takes. Click a block to zoom in."),
        Page(icon: "lock.shield",
             title: "100% local and private",
             text: "The app never uploads your files or any data about them. Every scan and every action happens on your Mac. The only connection is Apple's own purchase system."),
        Page(icon: "checkmark.seal",
             title: "You stay in control",
             text: "Clean everything that is safe in one click, or pick exactly what to remove. Anything that is not clearly safe goes to the Trash, and system files are protected. You choose which folder the app may look at."),
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            MiniDie(seed: page)
                .frame(width: 260, height: 170)
                .id(page)
                .transition(.opacity)
            Image(systemName: pages[page].icon)
                .font(.system(size: 30))
                .foregroundStyle(.tint)
            VStack(spacing: 12) {
                Text(pages[page].title).font(.largeTitle.bold())
                Text(pages[page].text)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
            .id("t\(page)")
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { i in
                    Circle().fill(i == page ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            HStack {
                if page > 0 { Button("Back") { withAnimation { page -= 1 } } }
                Button(page == pages.count - 1 ? "Get started" : "Continue") {
                    if page == pages.count - 1 { onFinish() } else { withAnimation { page += 1 } }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.02, green: 0.035, blue: 0.05).opacity(0.4))
    }
}

private struct MiniDie: View {
    let seed: Int
    private let kinds: [NodeKind] = [.systemData, .apps, .documents, .developer, .appData, .media, .system, .other]

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let base = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 8)
                let values: [Double] = [9, 6, 5, 4, 3, 2.5, 2, 1]
                let rects = Treemap.layout(values: values.shifted(by: seed), in: base)
                for (i, r) in rects.enumerated() {
                    let color = Palette.color(kinds[(i + seed) % kinds.count])
                    let pulse = 0.7 + 0.5 * (sin(t * 1.6 + Double(i)) + 1) / 2
                    DieStyle.block(&ctx, rect: r.insetBy(dx: 2, dy: 2), color: color, strength: pulse,
                                   radius: 6, horizontal: i % 2 == 0)
                }
            }
        }
    }
}

private extension Array where Element == Double {
    func shifted(by n: Int) -> [Double] {
        let k = n % count
        return Array(self[k...] + self[..<k]).sorted(by: >)
    }
}
