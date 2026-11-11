import Feedback
import SwiftUI

struct PastView: View {
    @Environment(Store.self) private var store

    var body: some View {
        List {
            ErrorBanner()
            ForEach(store.past) { EventRow(event: $0) }
        }
        .navigationTitle("Past (\(store.past.count))")
        .refreshable { await store.refresh([.past]) }
        .feedback(self)
    }
}

/// Day-only strings parse as UTC midnight, so they must format in UTC or US time zones show the day before.
func day(_ isoDay: String) -> String {
    guard let date = try? Date(isoDay, strategy: .iso8601.year().month().day()) else { return isoDay }
    var style = Date.FormatStyle.dateTime.month(.abbreviated).day().year()
    style.timeZone = .gmt
    return date.formatted(style)
}

struct PeopleView: View {
    @Environment(Store.self) private var store
    @State private var search = ""

    var body: some View {
        let people = store.people.filter { search.isEmpty || ($0.otherPerson.member?.displayName ?? "").localizedCaseInsensitiveContains(search) }
        List(people) { person in
            if let member = person.otherPerson.member {
                NavigationLink(value: member) { PersonRow(person: person) }
            } else {
                PersonRow(person: person)
            }
        }
        .navigationTitle("People (\(store.people.count))")
        .searchable(text: $search)
        .refreshable { await store.refresh([.people]) }
        .feedback(self)
    }
}

struct PersonRow: View {
    let person: PersonConnection

    var body: some View {
        HStack(spacing: 12) {
            Avatar(url: person.otherPerson.member?.photoURL, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(person.otherPerson.member?.displayName ?? "Non-member")
                    if person.isCloseFriend == true { Image(systemName: "star.fill").foregroundStyle(Color.brand).font(.caption).accessibilityLabel("Close friend") }
                }
                Text(summary).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let compatibility = person.compatibility {
                Text("\(Int(compatibility.rounded()))%")
                    .font(.callout.monospacedDigit().weight(.semibold))
                    .foregroundStyle(person.wasIrlCompatible == true ? Color.brand : .secondary)
            }
        }
        .feedback(self)
    }

    private var summary: String {
        [person.otherPerson.member?.outcome?.personalityType,
         person.lastInteractedDate.map { "last seen \(day($0))" },
         person.eventIdsTogether.map { "\($0.count) event\($0.count == 1 ? "" : "s")" }]
            .compactMap { $0 }.joined(separator: " · ")
    }
}

struct AlgorithmView: View {
    @Environment(Store.self) private var store
    @State private var search = ""

    var body: some View {
        List {
            ErrorBanner()
            ForEach(sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.ids, id: \.self) { id in
                        if let question = question(id) { QuestionRow(id: id, question: question) }
                    }
                }
            }
            if search.isEmpty { profile }
        }
        .navigationTitle("Algorithm")
        .searchable(text: $search, prompt: "Search questions")
        .refreshable { await store.refresh([.questionnaires, .me, .subscription]) }
        .feedback(self)
    }

    @ViewBuilder
    private var profile: some View {
        if let me = store.me {
            Section("You") {
                HStack(spacing: 16) {
                    Avatar(url: me.profilePhotoUrl, size: 64)
                    VStack(alignment: .leading) {
                        Text(me.name).font(.title3.bold())
                        if let type = me.outcome?.personalityType {
                            Text("\(type) · \(me.outcome?.personalityTypePercentage.map { "\($0.formatted())% of members" } ?? "")").foregroundStyle(.secondary)
                        }
                    }
                }
                ForEach(me.outcome?.traits ?? [], id: \.self) { trait in
                    LabeledContent(trait.adjective ?? trait.header) { Text(trait.percentage.map { "\($0.formatted())%" } ?? "") }
                }
                if let plan = store.subscription?.activePlan {
                    LabeledContent("Subscription", value: plan.recurringPriceItem.map { "\(money($0.cents, $0.currency)) / \(plan.duration == "ONE_MONTH" ? "month" : (plan.duration ?? "").lowercased())" } ?? "active")
                    if let end = plan.endDate { LabeledContent(plan.willCancelAtEndDate == true ? "Ends" : "Renews", value: end.formatted(date: .abbreviated, time: .omitted)) }
                    if let link = plan.cancelLink { Link("Manage subscription", destination: link) }
                }
            }
        }
    }

    private func question(_ id: String) -> Question? {
        store.questionnaires.lazy.compactMap { $0.questions[id] }.first
    }

    /// Typeform branches: a question that is the target of a conditional jump only applies when one of those conditions holds.
    private func applies(_ id: String) -> Bool {
        let actions: [Questionnaire.Logic.Action] = store.questionnaires.flatMap { $0.logic ?? [] }.flatMap(\.actions)
        let conditions: [Questionnaire.Logic.Condition] = actions
            .filter { action in action.action == "jump" && action.condition.op != "always" && action.details?.to?.value?.string == id }
            .map(\.condition)
        guard !conditions.isEmpty else { return true }
        return conditions.contains { condition in
            guard let field = condition.vars.first?.value?.string, let expected = condition.vars.last?.value?.string else { return false }
            let answer = store.answer(for: field)?.strings ?? []
            return condition.op == "is" ? answer.contains(expected) : answer != [expected]
        }
    }

    private var sections: [(title: String, ids: [String])] {
        let preferences = store.preferenceOrder.filter { question($0) != nil && applies($0) }
        var seen = Set(preferences)
        var byCategory: [(String, [String])] = []
        for questionnaire in store.questionnaires {
            for id in questionnaire.order where !seen.contains(id) {
                guard let question = questionnaire.questions[id], question.type != "statement", applies(id) else { continue }
                seen.insert(id)
                let category = question.category ?? "other"
                if let index = byCategory.firstIndex(where: { $0.0 == category }) { byCategory[index].1.append(id) }
                else { byCategory.append((category, [id])) }
            }
        }
        let all = [("Experience preferences", preferences)] + byCategory.map { (Self.title($0.0), $0.1) }
        guard !search.isEmpty else { return all.filter { !$0.1.isEmpty } }
        return all.map { title, ids in
            (title, ids.filter { id in [question(id)?.title, question(id)?.shortTitle].compactMap { $0 }.contains { $0.localizedCaseInsensitiveContains(search) } })
        }.filter { !$0.1.isEmpty }
    }

    private static func title(_ category: String) -> String {
        let words = category.replacing(/([A-Z])/) { " " + $0.1.lowercased() }
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}

struct QuestionRow: View {
    @Environment(Store.self) private var store
    let id: String
    let question: Question
    @State private var text = ""

    var body: some View {
        let answer = store.answer(for: id)
        VStack(alignment: .leading, spacing: 8) {
            if let group = question.properties?.groupTitle { Text(group).font(.caption).foregroundStyle(.secondary) }
            Text(question.title ?? question.shortTitle ?? id).font(.subheadline.weight(.medium))
            switch question.type {
            case "multiple_choice" where question.properties?.allowMultipleSelection == true:
                Chips(options: options(including: answer?.strings ?? []), selected: Set(answer?.strings ?? [])) { label in
                    var selected = answer?.strings ?? []
                    if let index = selected.firstIndex(of: label) { selected.remove(at: index) } else { selected.append(label) }
                    save(.array(selected.map(JSON.string)))
                }
            case "multiple_choice", "dropdown":
                let current = answer?.string ?? ""
                Picker("Answer", selection: Binding(get: { current }, set: { save(.string($0)) })) {
                    if current.isEmpty { Text("Not answered").tag("") }
                    ForEach(options(including: current.isEmpty ? [] : [current]), id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            case "opinion_scale":
                let steps = question.properties?.steps ?? 5
                let start = question.properties?.startAtOne == false ? 0 : 1
                Picker("Answer", selection: Binding(get: { answer?.number.map(Int.init) ?? -1 }, set: { save(.number(Double($0))) })) {
                    ForEach(start..<(start + steps), id: \.self) { Text("\($0)").tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                if let labels = question.properties?.labels {
                    HStack {
                        Text(labels["left"] ?? "")
                        Spacer()
                        Text(labels["right"] ?? "")
                    }
                    .font(.caption2).foregroundStyle(.secondary)
                }
            case "date":
                Text(answer?.string ?? "—").foregroundStyle(.secondary)
            default:
                TextField("Answer", text: $text, axis: question.type == "long_text" ? .vertical : .horizontal)
                    .onAppear { text = answer?.string ?? "" }
                    .onSubmit { if text != answer?.string { save(.string(text)) } }
            }
        }
        .padding(.vertical, 2)
        .feedbackCell(self)
    }

    private func options(including answers: [String]) -> [String] {
        let labels = (question.properties?.choices ?? []).map(\.label)
        return labels + answers.filter { !labels.contains($0) }
    }

    private func save(_ value: JSON) {
        Task { await store.answer(id, value) }
    }
}

struct Chips: View {
    let options: [String]
    let selected: Set<String>
    let toggle: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let isOn = selected.contains(option)
                Button(option) { toggle(option) }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .foregroundStyle(isOn ? .white : .primary)
                    .background(isOn ? Color.brand : Color.secondary.opacity(0.15), in: Capsule())
                    .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .feedback("Chips", data: selected)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: rows.last.map { $0.y + $0.height } ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [(indices: [Int], y: CGFloat, width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], y: CGFloat, width: CGFloat, height: CGFloat)] = []
        var current: [Int] = [], x: CGFloat = 0, y: CGFloat = 0, height: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x + size.width > width, !current.isEmpty {
                rows.append((current, y, x - spacing, height))
                y += height + spacing
                current = []; x = 0; height = 0
            }
            current.append(index)
            x += size.width + spacing
            height = max(height, size.height)
        }
        if !current.isEmpty { rows.append((current, y, x - spacing, height)) }
        return rows
    }
}
