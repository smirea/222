import Feedback
import SwiftUI

/// The one profile screen, opened by pushing a `Member` from any list that shows people.
struct PersonView: View {
    @Environment(Store.self) private var store
    let member: Member

    var body: some View {
        let connection = store.connection(member.id)
        let together = store.eventIDsTogether(member.id)
        let events = together.compactMap(store.event).sorted { $0.startDateTime > $1.startDateTime }
        let live = store.liveAttendance(member.id)
        List {
            Section {
                AsyncImage(url: member.photoURL) { image in
                    image.resizable().scaledToFit().frame(maxWidth: .infinity)
                } placeholder: {
                    Image(systemName: "person.fill").font(.system(size: 80)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 320).background(.quaternary)
                }
                .accessibilityLabel("Photo of \(member.displayName)")
                .feedback("Photo", data: member.photoURL)
                .listRowInsets(EdgeInsets())
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(member.displayName).font(.title.bold())
                        if connection?.isCloseFriend == true {
                            Image(systemName: "star.fill").foregroundStyle(Color.brand).accessibilityLabel("Close friend")
                        }
                    }
                    if let type = member.outcome?.personalityType {
                        Text([type, member.outcome?.personalityTypePercentage.map { "\($0.formatted())% of members" }].compactMap { $0 }.joined(separator: " · "))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .feedbackCell("Name", data: member.outcome?.personalityType)
            }
            Section {
                if let live {
                    LabeledContent(live.event.title, value: live.status.map(humanize) ?? "Attending")
                }
                LabeledContent("Events together", value: "\(together.count)")
                if let first = connection?.firstMetIrlDate.map(day) ?? events.last.map(date) { LabeledContent("First met", value: first) }
                if let last = connection?.lastInteractedDate.map(day) ?? events.first.map(date) { LabeledContent("Last seen", value: last) }
                if let value = connection?.compatibility { LabeledContent("Compatibility", value: percent(value)) }
                if let value = connection?.wasIrlCompatible { LabeledContent("Compatible in person", value: value ? "yes" : "no") }
                if let value = connection?.suggestibility { LabeledContent("Suggestibility", value: percent(value)) }
            }
            if !events.isEmpty {
                Section("Events together") { ForEach(events) { EventRow(event: $0) } }
            }
            if let picks = member.outcome?.imageUrls, !picks.isEmpty {
                Section("Personality picks") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                        ForEach(picks, id: \.self) { url in
                            Color.secondary.opacity(0.15)
                                .aspectRatio(1, contentMode: .fit)
                                .overlay { AsyncImage(url: url) { $0.resizable().scaledToFill() } placeholder: { EmptyView() } }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(alignment: .topTrailing) {
                                    if url == member.outcome?.favoriteImageUrl {
                                        Image(systemName: "heart.fill").font(.caption).foregroundStyle(.white).padding(6).shadow(radius: 2)
                                    }
                                }
                                .accessibilityHidden(true)
                        }
                    }
                    .feedbackCell("Picks", data: picks.count)
                }
            }
        }
        .navigationTitle(member.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .feedback(self)
    }

    private func date(_ event: Event) -> String { event.format(event.startDateTime, .dateTime.month(.abbreviated).day().year()) }
    private func percent(_ value: Double) -> String { "\(value.formatted(.number.precision(.fractionLength(0))))%" }
    private func humanize(_ status: String) -> String {
        let words = status.replacingOccurrences(of: "_", with: " ").lowercased()
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}

struct AttendeeGrid: View {
    @Environment(Store.self) private var store
    let event: Event
    let members: [Member]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
            ForEach(members) { AttendeeCell(member: $0, seen: store.eventIDsTogether($0.id, excluding: event.id).count) }
        }
        .padding(.vertical, 6)
        .feedbackCell("Attendees", data: members.count)
    }
}

/// A button, not a NavigationLink: a List row holding several links fires the last one whichever cell is tapped.
struct AttendeeCell: View {
    @Environment(\.router) private var router
    let member: Member
    let seen: Int

    var body: some View {
        Button { router.push(member) } label: {
            VStack(spacing: 6) {
                Color.secondary.opacity(0.15)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        AsyncImage(url: member.photoURL) { $0.resizable().scaledToFill() } placeholder: {
                            Image(systemName: "person.fill").font(.largeTitle).foregroundStyle(.secondary)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .bottom) {
                        if seen > 0 {
                            Text(seen == 1 ? "Seen before" : "Seen \(seen)×")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .glassEffect(.regular.tint(Color.brand.opacity(0.5)))
                                .padding(6)
                        }
                    }
                Text(member.displayName).font(.subheadline).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.borderless)
        .tint(.primary)
        .accessibilityLabel(seen == 0 ? member.displayName : "\(member.displayName), seen at \(seen) event\(seen == 1 ? "" : "s") before")
        .feedback(self)
    }
}

struct VenuePin: View {
    @Environment(\.openURL) private var openURL
    let venue: Venue
    let isCurrent: Bool

    var body: some View {
        let urls = venue.googleMaps
        Button {
            openURL(urls.app) { opened in if !opened { openURL(urls.web) } }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill").font(.title).foregroundStyle(.white, .red).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(venue.name ?? "Venue").font(.headline)
                        if let stage = venue.stage { Text(stage).font(.caption).foregroundStyle(.secondary) }
                        if isCurrent {
                            Text("Now").font(.caption2.weight(.bold)).foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.brand, in: Capsule())
                        }
                    }
                    if let address = venue.address { Text(address).font(.subheadline).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary).accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens in Google Maps")
        .feedbackCell(self)
    }
}
