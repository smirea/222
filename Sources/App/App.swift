import Feedback
import SwiftUI

@main
struct TwoTwoTwoApp: App {
    @State private var store: Store

    init() {
        let store = Store()
        _store = State(initialValue: store)
        Feedback.enable()
        Feedback.context("Store") { store }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(.brand)
        }
    }
}

extension Color {
    static let brand = Color(red: 6 / 255, green: 73 / 255, blue: 220 / 255)
}

struct RootView: View {
    @Environment(Store.self) private var store

    var body: some View {
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
        .accessibilityHidden(true)
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
