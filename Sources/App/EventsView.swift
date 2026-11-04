import Feedback
import MapKit
import SwiftUI

struct EventsView: View {
    @Environment(Store.self) private var store
    @State private var showPassed = false

    var body: some View {
        let upcoming = (store.upcoming + store.current).sorted { $0.startDateTime < $1.startDateTime }
        let joinedIDs = Set(upcoming.map(\.id))
        let feedbackDue = store.past.filter { $0.didCompleteFollowUp == false && ($0.followUpDeadline ?? .distantFuture) > .now }
        List {
            ErrorBanner()
            section("Feedback due", feedbackDue)
            section("Happening now", store.current)
            section("Needs reply", upcoming.filter { $0.status == .invited })
            section("Going", upcoming.filter { $0.status == .confirmed })
            section("In the pool", upcoming.filter { $0.status == .interested })
            section("Other", upcoming.filter { ![.invited, .confirmed, .interested, .notInterested].contains($0.status) && !store.current.contains($0) })
            Section {
                if let reason = store.requestMeta?.lockedReason { Text(reason).foregroundStyle(.secondary) }
                ForEach(store.requestable.filter { !joinedIDs.contains($0.id) }) { EventRow(event: $0) }
            } header: {
                Text("Available")
            }
            let passed = upcoming.filter { $0.status == .notInterested }
            if !passed.isEmpty {
                Section(isExpanded: $showPassed) {
                    ForEach(passed) { EventRow(event: $0) }
                } header: {
                    Text("Passed (\(passed.count))")
                }
            }
        }
        .navigationTitle("Events")
        .navigationDestination(for: String.self) { EventDetailView(id: $0) }
        .refreshable { await store.refresh() }
        .toolbar {
            if store.refreshing { ToolbarItem { ProgressView().controlSize(.small) } }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
        .feedback(self)
    }

    @ViewBuilder
    private func section(_ title: String, _ events: [Event]) -> some View {
        if !events.isEmpty {
            Section(title) { ForEach(events) { EventRow(event: $0) } }
        }
    }
}

struct EventRow: View {
    @Environment(Store.self) private var store
    let event: Event

    var body: some View {
        NavigationLink(value: event.id) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title).font(.headline)
                    Text(event.whenWhere).font(.subheadline).foregroundStyle(.secondary)
                    if let note { Text(note).font(.caption).foregroundStyle(.orange) }
                }
                Spacer(minLength: 8)
                EventAction(event: event, compact: true)
            }
        }
        .feedbackCell(self)
        .swipeActions {
            if event.status == .invited {
                Button("Pass") { Task { await store.pass(event) } }.tint(.gray)
            }
        }
    }

    private var note: String? {
        if event.rsvp?.payment?.status == "PENDING" { return "Payment pending" }
        if event.didCompleteFollowUp == false, let deadline = event.followUpDeadline { return "Feedback due \(event.format(deadline, .dateTime.month(.abbreviated).day()))" }
        if event.isSoldOut == true { return "Sold out" }
        if event.isCanceled == true { return "Canceled" }
        return nil
    }
}

/// The one primary action an event currently allows, so rows and detail never disagree.
struct EventAction: View {
    @Environment(Store.self) private var store
    let event: Event
    var compact = false

    var body: some View {
        SwiftUI.Group { content }.feedback(self)
    }

    @ViewBuilder
    private var content: some View {
        if store.busy.contains(event.id) {
            ProgressView().controlSize(.small)
        } else if store.requestable.contains(where: { $0.id == event.id }) && event.rsvp == nil {
            join { Task { await store.request(event) } }
        } else if event.status == .invited || event.status == .notInterested {
            let free = (event.attendOptions ?? []).filter { $0.cents == 0 }
            if free.count > 1 {
                Menu {
                    ForEach(free) { option in Button(option.title) { Task { await store.join(event, option: option) } } }
                } label: { Text("Join") }
                .menuStyle(.button)
                .buttonStyle(.glassProminent)
                .fixedSize()
            } else if let option = free.first {
                join { Task { await store.join(event, option: option) } }
            } else if let option = event.cheapestOption {
                Text("\(money(option.cents)) · pay in 222 app").font(.caption).foregroundStyle(.secondary)
            }
        } else if let status = event.status, compact {
            Text(status.label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .glassEffect(.regular.tint(status == .confirmed ? .brand.opacity(0.35) : .clear))
        }
    }

    private func join(_ action: @escaping () -> Void) -> some View {
        Button("Join", action: action).buttonStyle(.glassProminent)
    }
}

struct CancelButton: View {
    @Environment(Store.self) private var store
    let event: Event
    @State private var prompt: String?

    var body: some View {
        Button(role: .destructive) {
            if let fee = event.cancellationFee() {
                prompt = "Cancelling now costs \(money(fee.cents, fee.currency))."
            } else {
                Task { prompt = await store.cancel(event) }
            }
        } label: {
            Label(event.status == .interested ? "Leave pool" : "Cancel", systemImage: "xmark")
        }
        .buttonStyle(.glass)
        .tint(.red)
        .confirmationDialog(prompt ?? "", isPresented: Binding(get: { prompt != nil }, set: { if !$0 { prompt = nil } }), titleVisibility: .visible) {
            Button("Cancel anyway", role: .destructive) { Task { _ = await store.cancel(event, acceptingFee: true) } }
        }
    }
}

struct EventDetailView: View {
    @Environment(Store.self) private var store
    let id: String

    private static let shareTitles = [
        "plus_one_url": "Invite a plus one",
        "plus_n_url": "Invite friends",
        "private_table_url": "Invite to a private table",
    ]

    var body: some View {
        SwiftUI.Group { content }.feedback(self)
    }

    @ViewBuilder
    private var content: some View {
        if let event = store.event(id) {
            List {
                ErrorBanner()
                header(event)
                itinerary(event)
                map(event)
                terms(event)
                options(event)
                people(event)
                photos(event)
                info(event)
                if case .object(let raw) = store.raw[id] {
                    Section("All fields") {
                        ForEach(raw.keys.sorted(), id: \.self) { JSONTree(key: $0, value: raw[$0]!, event: event) }
                    }
                }
            }
            .navigationTitle(event.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        } else {
            ContentUnavailableView("Event not found", systemImage: "calendar.badge.exclamationmark")
        }
    }

    private func header(_ event: Event) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(event.title).font(.title2.bold())
                Text(event.format(event.startDateTime, .dateTime.weekday(.wide).month(.wide).day().hour().minute()))
                if !event.place.isEmpty { Text(event.place).foregroundStyle(.secondary) }
                if let status = event.status { Text(status.label).font(.subheadline.weight(.semibold)).foregroundStyle(Color.brand) }
            }
            .feedbackCell("Header", data: event.status)
            if let blurb = event.blurb { Text(blurb) }
            if let description = event.description { Text(description) }
            if let payment = event.rsvp?.payment, payment.status == "PENDING" {
                Label("Payment of \(money(payment.price ?? 0, payment.currency ?? "USD")) pending. Pay in the 222 app.", systemImage: "creditcard")
                    .foregroundStyle(.orange)
            }
            if event.status != nil || store.requestable.contains(where: { $0.id == event.id }) {
                HStack {
                    EventAction(event: event)
                    if event.status == .invited {
                        Button("Pass") { Task { await store.pass(event) } }.buttonStyle(.glass)
                    }
                    if event.status == .confirmed || event.status == .interested { CancelButton(event: event) }
                }
                .feedbackCell("Actions", data: event.status)
            }
        }
    }

    @ViewBuilder
    private func itinerary(_ event: Event) -> some View {
        let stages = event.timeline?.stages ?? []
        let points = (event.timeline?.points ?? []) + (event.rsvp?.additionalTimelineMetadata?.additionalPoints ?? [])
        if !stages.isEmpty || !points.isEmpty || !(event.venues ?? []).isEmpty {
            Section("Itinerary") {
                ForEach(stages) { stage in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(stage.title).font(.headline)
                            Spacer()
                            if let start = stage.startDateTime { Text(event.format(start, .dateTime.hour().minute())).foregroundStyle(.secondary) }
                        }
                        if let subtitle = stage.subtitle { Text(subtitle).font(.subheadline) }
                        if let reveal = stage.locationRevealDateTime {
                            Text(reveal > .now ? "Location revealed \(event.format(reveal))" : "Location revealed")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .feedbackCell("Stage", data: stage)
                }
                ForEach(event.venues ?? []) { venue in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(venue.name ?? "Venue").font(.headline)
                        if let address = venue.address,
                           let url = URL(string: "https://maps.apple.com/?q=\(address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
                            Link(address, destination: url).font(.subheadline)
                        }
                    }
                    .feedbackCell("Venue", data: venue)
                }
                ForEach(points.sorted { $0.dateTime < $1.dateTime }, id: \.self) { point in
                    LabeledContent(point.label, value: event.format(point.dateTime))
                }
            }
        }
    }

    @ViewBuilder
    private func map(_ event: Event) -> some View {
        let areas = (event.timeline?.stages ?? []).compactMap { stage in stage.locationCoordinateObfuscated.map { (stage, $0) } }
        let venues = (event.venues ?? []).filter { $0.coordinate != nil }
        if !areas.isEmpty || !venues.isEmpty {
            Section {
                Map {
                    ForEach(areas, id: \.0.id) { stage, area in
                        MapCircle(center: area.coordinate.location, radius: area.obfuscationRadiusMiles * 1609.34)
                            .foregroundStyle(Color.brand.opacity(0.2))
                            .stroke(Color.brand, lineWidth: 1)
                        Annotation(stage.title, coordinate: area.coordinate.location) { Circle().fill(Color.brand).frame(width: 6).accessibilityHidden(true) }
                    }
                    ForEach(venues) { venue in Marker(venue.name ?? "Venue", coordinate: venue.coordinate!.location).tint(Color.brand) }
                }
                .frame(height: 220)
                .feedback("Map", data: event.timeline?.stages)
                .listRowInsets(EdgeInsets())
            }
        }
    }

    @ViewBuilder
    private func terms(_ event: Event) -> some View {
        let guidelines = event.rsvp?.confirmationGuidelines ?? []
        if !guidelines.isEmpty {
            Section("Terms") {
                ForEach(guidelines, id: \.self) { guideline in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(guideline.title).font(.headline)
                        ForEach([guideline.unboxedMarkdown, guideline.boxedMarkdown].compactMap { $0 }.filter { !$0.isEmpty }, id: \.self) { Markdown(text: $0) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func options(_ event: Event) -> some View {
        let options = event.attendOptions ?? []
        if !options.isEmpty || event.fees != nil {
            Section("Options & fees") {
                ForEach(options) { option in
                    LabeledContent {
                        Text(option.cents == 0 ? "Free" : money(option.cents))
                    } label: {
                        Text(option.title)
                        let original = option.priceItems.reduce(0) { $0 + $1.price }
                        if original != option.cents { Text("\(money(original)) before discount").strikethrough() }
                        ForEach(option.details ?? [], id: \.self) { Text($0) }
                    }
                    .feedbackCell("AttendOption", data: option)
                }
                if let free = event.chosenSendDateTime, event.cancellationFee() == nil {
                    LabeledContent("Free cancellation until", value: event.format(free))
                }
                if let fee = event.fees?.lateCancellationFeePriceItem { LabeledContent(fee.label.capitalized, value: money(fee.cents, fee.currency)) }
                if let late = event.lateDeadlineDateTime { LabeledContent("Late after", value: event.format(late)) }
                if let fee = event.fees?.noShowFeePriceItem { LabeledContent(fee.label.capitalized, value: money(fee.cents, fee.currency)) }
                if let deadline = event.paymentDeadlineDateTime { LabeledContent("Payment deadline", value: event.format(deadline)) }
            }
        }
    }

    @ViewBuilder
    private func people(_ event: Event) -> some View {
        let members = (event.myGroups ?? []).flatMap(\.members).filter { $0.id != store.me?.id }
        if !members.isEmpty {
            Section("Your \(event.groupTerm ?? "group") (\(members.count))") {
                ForEach(members) { MemberRow(member: $0) }
            }
        }
    }

    @ViewBuilder
    private func photos(_ event: Event) -> some View {
        if let photos = event.photos, !photos.isEmpty {
            Section("Photos (\(photos.count))") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 4)], spacing: 4) {
                    ForEach(Array(Set(photos.map(\.url))).sorted { $0.absoluteString < $1.absoluteString }, id: \.self) { url in
                        Link(destination: url) {
                            AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { Color.secondary.opacity(0.2) }
                                .frame(minWidth: 0, maxWidth: .infinity).frame(height: 100).clipped()
                        }
                        .accessibilityLabel("Photo")
                    }
                }
                .feedback("Photos", data: photos.count)
            }
        }
    }

    @ViewBuilder
    private func info(_ event: Event) -> some View {
        Section("Details") {
            ForEach(event.details ?? [], id: \.self) { Text($0) }
            if let count = event.memberCount { LabeledContent("Members attending", value: "\(count)") }
            if let size = event.curatedGroupSize { LabeledContent("Curated \(event.groupTerm ?? "group") size", value: "\(size)") }
            if let size = event.maxPrivateGroupSize { LabeledContent("Max private group", value: "\(size)") }
            if let plusOnes = event.numberOfPlusOnesAllowed { LabeledContent("Plus ones allowed", value: "\(plusOnes)") }
            if event.isTwentyOnePlus == true { LabeledContent("Ages", value: "21+") }
            if let categories = event.categories, !categories.isEmpty { LabeledContent("Categories", value: categories.joined(separator: ", ")) }
            if event.didCompleteFollowUp == false { LabeledContent("Feedback", value: "Due, complete it in the 222 app") }
            ForEach((event.rsvp?.shareUrls ?? [:]).sorted { $0.key < $1.key }, id: \.key) { key, url in
                ShareLink(item: url) { Label(Self.shareTitles[key] ?? key, systemImage: "square.and.arrow.up") }
            }
        }
    }
}

struct MemberRow: View {
    let member: Member

    var body: some View {
        HStack(spacing: 12) {
            Avatar(url: member.profilePhotoUrl ?? member.outcome?.favoriteImageUrl)
            VStack(alignment: .leading) {
                Text(member.displayName)
                if let type = member.outcome?.personalityType { Text(type).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .feedbackCell(self)
    }
}

struct Markdown: View {
    let text: String

    var body: some View {
        Text((try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text))
    }
}

struct JSONTree: View {
    let key: String
    let value: JSON
    let event: Event?

    var body: some View {
        let label = key.replacingOccurrences(of: "_", with: " ")
        switch value {
        case .object(let object) where !object.isEmpty:
            DisclosureGroup(label) {
                ForEach(object.keys.sorted(), id: \.self) { AnyView(JSONTree(key: $0, value: object[$0]!, event: event)) }
            }
        case .array(let array) where !array.isEmpty:
            DisclosureGroup("\(label) (\(array.count))") {
                ForEach(array.indices, id: \.self) { AnyView(JSONTree(key: "\($0 + 1)", value: array[$0], event: event)) }
            }
        case .string(let string) where string.hasPrefix("http"):
            LabeledContent(label) { Link(string.count > 40 ? "Open" : string, destination: URL(string: string) ?? URL(string: "about:blank")!) }
        default:
            LabeledContent(label) { Text(leaf).textSelection(.enabled).multilineTextAlignment(.trailing) }
        }
    }

    private var leaf: String {
        switch value {
        case .null, .array, .object: "—"
        case .bool(let bool): bool ? "yes" : "no"
        case .number(let number): number.rounded() == number ? String(Int(number)) : String(number)
        case .string(let string):
            if string.contains("T"), let date = API.parseDate(string) { event?.format(date) ?? date.formatted() } else { string }
        }
    }
}

extension Coordinate {
    var location: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }
}
