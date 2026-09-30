import SwiftUI
import AppKit

/// The real home folder. Inside the App Sandbox `homeDirectoryForCurrentUser` points to the app container.
nonisolated func realHomeURL() -> URL {
    if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
        return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
    }
    return FileManager.default.homeDirectoryForCurrentUser
}

/// Access to the user's Home folder: the user picks it once in the system Open panel and we keep a
/// security-scoped bookmark, so the App Sandbox allows reading and cleaning inside it after restarts.
@Observable
final class HomeAccess {
    private static let key = "homeFolderBookmark"
    private(set) var granted = false
    private var scoped: URL?
    var errorText: String?

    init() { restore() }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.key) else { return }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope],
                                 relativeTo: nil, bookmarkDataIsStale: &stale),
              url.standardizedFileURL.path == realHomeURL().standardizedFileURL.path,
              url.startAccessingSecurityScopedResource() else { return }
        scoped = url
        granted = true
        if stale { save(url) }
    }

    private func save(_ url: URL) {
        if let data = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func choose() {
        let home = realHomeURL()
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = home
        panel.prompt = String(localized: "Allow")
        panel.message = String(localized: "Choose your Home folder (\(home.lastPathComponent)) so See Your Disk can measure and clean it.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard url.standardizedFileURL.path == home.standardizedFileURL.path else {
            errorText = String(localized: "Please choose your Home folder: \(home.lastPathComponent).")
            return
        }
        guard url.startAccessingSecurityScopedResource() else {
            errorText = String(localized: "macOS did not grant access. Please try again.")
            return
        }
        scoped?.stopAccessingSecurityScopedResource()
        scoped = url
        save(url)
        errorText = nil
        granted = true
    }
}

struct AccessView: View {
    @Bindable var access: HomeAccess

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "folder.badge.gearshape").font(.system(size: 48)).foregroundStyle(.tint)
            Text("Choose your Home folder").font(.largeTitle.bold())
            Text("macOS lets an app see only the folders you choose. Pick your Home folder once and See Your Disk can measure it and clean caches, logs and leftovers inside it. You can change this later.")
                .font(.title3).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 540)
            Button("Choose Home folder") { access.choose() }
                .buttonStyle(.borderedProminent).controlSize(.large)
            if let e = access.errorText {
                Text(verbatim: e).font(.callout).foregroundStyle(.orange)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
