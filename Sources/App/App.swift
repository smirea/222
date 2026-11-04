import SwiftUI

@main
struct TwoTwoTwoApp: App {
    @State private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(.brand)
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 780)
        #endif
    }
}

extension Color {
    static let brand = Color(red: 6 / 255, green: 73 / 255, blue: 220 / 255)
}

struct RootView: View {
    @Environment(Store.self) private var store

    var body: some View {
        if store.token == nil {
            TokenView()
        } else {
            TabView {
                Tab("Events", systemImage: "calendar") { NavigationStack { EventsView() } }
                Tab("Past", systemImage: "clock.arrow.circlepath") { NavigationStack { PastView() } }
                Tab("People", systemImage: "person.2") { NavigationStack { PeopleView() } }
                Tab("Algorithm", systemImage: "slider.horizontal.3") { NavigationStack { AlgorithmView() } }
            }
            .tabViewStyle(.sidebarAdaptable)
            .task { await store.refresh() }
        }
    }
}

struct TokenView: View {
    @Environment(Store.self) private var store
    @State private var token = ""
    @State private var error: String?
    @State private var working = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("222").font(.largeTitle.bold())
            Text("Paste your 222 API token. `222 invites -s` in the scripts repo refreshes it from Chrome, and `get_authed_member` returns it as `auth_token`.")
                .foregroundStyle(.secondary)
            SecureField("Token", text: $token)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)
            if let error { Text(error).foregroundStyle(.red).font(.callout) }
            Button(action: submit) {
                Text(working ? "Checking…" : "Sign in").frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .disabled(token.isEmpty || working)
        }
        .padding(24)
        .frame(maxWidth: 420)
    }

    private func submit() {
        working = true
        Task {
            do { try await store.signIn(token) } catch { self.error = error.localizedDescription }
            working = false
        }
    }
}

extension Event {
    func format(_ date: Date, _ style: Date.FormatStyle = .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()) -> String {
        var style = style
        style.timeZone = tz
        return date.formatted(style)
    }

    var whenWhere: String {
        [format(startDateTime), neighborhood].compactMap { $0 }.joined(separator: " · ")
    }
}

struct Avatar: View {
    let url: URL?
    var size: CGFloat = 36

    var body: some View {
        AsyncImage(url: url) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Image(systemName: "person.fill").foregroundStyle(.secondary)
        }
        .frame(width: size, height: size)
        .background(.quaternary)
        .clipShape(Circle())
    }
}

struct ErrorBanner: View {
    @Environment(Store.self) private var store

    var body: some View {
        if let error = store.error {
            Section {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.callout).textSelection(.enabled)
            }
        }
    }
}
