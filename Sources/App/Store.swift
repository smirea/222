import Foundation
import Observation

enum Endpoint: String, CaseIterable {
    case me = "get_authed_member"
    case upcoming = "get_members_upcoming_events"
    case current = "get_members_current_events"
    case past = "get_members_past_events"
    case requestable = "get_request_new_event_metadata"
    case questionnaires = "get_all_questionnaires"
    case people = "person_connections"
    case subscription = "get_subscription"

    var query: [String: String] { self == .subscription ? ["include_payments": "false"] : [:] }
}

@Observable @MainActor
final class Store {
    var me: AuthedMember?
    var upcoming: [Event] = []
    var current: [Event] = []
    var past: [Event] = []
    var requestable: [Event] = []
    var requestMeta: RequestMetadata?
    var questionnaires: [Questionnaire] = []
    var preferenceOrder: [String] = []
    var people: [PersonConnection] = []
    var subscription: Subscription?
    var raw: [String: JSON] = [:]
    var error: String?
    var busy: Set<String> = []
    var refreshing = false

    private static let cacheDir = URL.cachesDirectory.appending(path: "222", directoryHint: .isDirectory)

    // Baked into Info.plist at build time from env-manager (Config/LocalSecrets.xcconfig), so the app never asks for credentials.
    private let api: API? = (Bundle.main.object(forInfoDictionaryKey: "TwoTwoTwoToken") as? String)
        .flatMap { $0.isEmpty ? nil : API(token: $0) }

    init() {
        if api == nil { error = "This build has no 222 token. Run `env-manager down` in the repo, then rebuild." }
        for endpoint in Endpoint.allCases {
            if let data = try? Data(contentsOf: Self.cacheDir.appending(path: "\(endpoint.rawValue).json")) {
                try? apply(endpoint, data)
            }
        }
    }

    func refresh(_ endpoints: [Endpoint] = Endpoint.allCases) async {
        guard let api else { return }
        refreshing = true
        defer { refreshing = false }
        await withTaskGroup(of: (Endpoint, Result<Data, Error>).self) { group in
            for endpoint in endpoints {
                group.addTask {
                    do { return (endpoint, .success(try await api.data("GET", endpoint.rawValue, query: endpoint.query))) }
                    catch { return (endpoint, .failure(error)) }
                }
            }
            var failures: [String] = []
            for await (endpoint, result) in group {
                do { try store(endpoint, try result.get()) }
                catch APIError.unauthorized { error = "222 rejected the token. Update TWOTWOTWO_API_KEY in Config/LocalSecrets.xcconfig, run `env-manager up`, then rebuild."; return }
                catch { failures.append("\(endpoint.rawValue): \(error.localizedDescription)") }
            }
            self.error = failures.isEmpty ? nil : failures.joined(separator: "\n")
        }
    }

    private func store(_ endpoint: Endpoint, _ data: Data) throws {
        try apply(endpoint, data)
        try? FileManager.default.createDirectory(at: Self.cacheDir, withIntermediateDirectories: true)
        try? data.write(to: Self.cacheDir.appending(path: "\(endpoint.rawValue).json"))
    }

    private func apply(_ endpoint: Endpoint, _ data: Data) throws {
        let decoder = API.decoder
        switch endpoint {
        case .me:
            me = try decoder.decode(Wrapped.Me.self, from: data).authedMember
        case .upcoming:
            upcoming = try decoder.decode(Wrapped.Upcoming.self, from: data).upcomingEvents
            indexRaw(data, "upcoming_events")
        case .current:
            current = try decoder.decode(Wrapped.Current.self, from: data).currentEvents
            indexRaw(data, "current_events")
        case .past:
            past = try decoder.decode(Wrapped.Past.self, from: data).pastEvents.sorted { $0.startDateTime > $1.startDateTime }
            indexRaw(data, "past_events")
        case .requestable:
            let meta = try decoder.decode(Wrapped.Requestable.self, from: data).requestNewEventMetadata
            requestable = meta.requestableEvents.sorted { $0.startDateTime < $1.startDateTime }
            requestMeta = RequestMetadata(lockedReason: meta.lockedReason, cantRequestUntilDateTime: meta.cantRequestUntilDateTime)
            indexRaw(data, "request_new_event_metadata", "requestable_events")
        case .questionnaires:
            // Question ids contain underscores, so these keys must not go through snake-case conversion.
            let response = try JSONDecoder().decode(Wrapped.Questionnaires.self, from: data)
            questionnaires = response.questionnaires
            preferenceOrder = response.experiencePreferencesQuestionOrder
        case .people:
            people = try decoder.decode(Wrapped.People.self, from: data).personConnections
                .sorted { ($0.lastInteractedDate ?? "") > ($1.lastInteractedDate ?? "") }
        case .subscription:
            subscription = try decoder.decode(Wrapped.Sub.self, from: data).subscription
        }
    }

    private func indexRaw(_ data: Data, _ path: String...) {
        guard var json = try? JSONDecoder().decode(JSON.self, from: data) else { return }
        for key in path { json = json[key] ?? .null }
        guard case .array(let events) = json else { return }
        for event in events { if let id = event["id"]?.string { raw[id] = event } }
    }

    func event(_ id: String) -> Event? {
        upcoming.first { $0.id == id } ?? current.first { $0.id == id } ?? past.first { $0.id == id } ?? requestable.first { $0.id == id }
    }

    private func updateRSVP(_ eventID: String, _ rsvp: RSVP) {
        if let index = upcoming.firstIndex(where: { $0.id == eventID }) { upcoming[index].rsvp = rsvp }
        if let index = current.firstIndex(where: { $0.id == eventID }) { current[index].rsvp = rsvp }
    }

    private func perform(_ eventID: String, _ work: (API) async throws -> Void) async {
        guard let api else { return }
        busy.insert(eventID)
        defer { busy.remove(eventID) }
        do {
            try await work(api)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        await refresh([.upcoming, .requestable])
    }

    func join(_ event: Event, option: AttendOption) async {
        await perform(event.id) { api in
            let data = try await api.data("POST", "update_attend_option", query: ["event_id": event.id], body: ["attend_option_id": option.id])
            updateRSVP(event.id, try API.decoder.decode(Wrapped.RSVPResponse.self, from: data).rsvp)
        }
    }

    func pass(_ event: Event) async {
        await perform(event.id) { api in
            let data = try await api.data("POST", "reject_event_invite", query: ["event_id": event.id])
            updateRSVP(event.id, try API.decoder.decode(Wrapped.RSVPResponse.self, from: data).rsvp)
        }
    }

    /// Requesting only creates an invite; joining it right away saves the second round trip the official app makes you do.
    func request(_ event: Event) async {
        await perform(event.id) { api in
            let data = try await api.data("POST", "request_new_event", body: ["requested_event_id": event.id, "origin": "ios"])
            let response = try API.decoder.decode(Wrapped.Requested.self, from: data)
            upcoming = response.upcomingEventsResponse.upcomingEvents
            guard let invite = upcoming.first(where: { $0.id == response.newUpcomingEventId }),
                  let option = invite.attendOptions?.first(where: { $0.cents == 0 }) else { return }
            let joined = try await api.data("POST", "update_attend_option", query: ["event_id": invite.id], body: ["attend_option_id": option.id])
            updateRSVP(invite.id, try API.decoder.decode(Wrapped.RSVPResponse.self, from: joined).rsvp)
        }
    }

    /// Returns the new terms when the server changed them and the cancel now costs money; the caller asks before retrying.
    func cancel(_ event: Event, acceptingFee: Bool = false) async -> String? {
        guard let api else { return nil }
        busy.insert(event.id)
        defer { busy.remove(event.id) }
        var event = event
        for _ in 0..<2 {
            do {
                if event.rsvp?.declineEventModalConfig?.declineType == "BAIL" {
                    _ = try await api.data("POST", "bail", query: ["event_id": event.id])
                } else {
                    _ = try await api.data("POST", "reject_event_invite", query: ["event_id": event.id])
                }
                error = nil
                break
            } catch APIError.reprompt(let message, let rsvp) {
                if let rsvp { event.rsvp = rsvp; updateRSVP(event.id, rsvp) }
                if event.cancellationFee() != nil && !acceptingFee { return message }
            } catch {
                self.error = error.localizedDescription
                break
            }
        }
        await refresh([.upcoming, .requestable])
        return nil
    }

    func answer(_ questionID: String, _ value: JSON) async {
        guard let api else { return }
        let previous = questionnaires
        for index in questionnaires.indices where questionnaires[index].questions[questionID] != nil {
            questionnaires[index].answers[questionID] = value
        }
        do {
            let body = try JSONSerialization.jsonObject(with: JSONEncoder().encode(JSON.object(["answers": .object([questionID: value])])))
            _ = try await api.data("POST", "submit_answers", body: body as? [String: Any])
            error = nil
        } catch {
            questionnaires = previous
            self.error = "Saving failed: \(error.localizedDescription)"
        }
    }

    func answer(for questionID: String) -> JSON? {
        questionnaires.lazy.compactMap { $0.answers[questionID] }.first { !$0.isEmpty } ?? questionnaires.lazy.compactMap { $0.answers[questionID] }.first
    }
}

private enum Wrapped {
    struct Me: Decodable { let authedMember: AuthedMember }
    struct Upcoming: Decodable { let upcomingEvents: [Event] }
    struct Current: Decodable { let currentEvents: [Event] }
    struct Past: Decodable { let pastEvents: [Event] }
    struct Requestable: Decodable { let requestNewEventMetadata: Meta }
    struct Meta: Decodable {
        let requestableEvents: [Event]
        let lockedReason: String?
        let cantRequestUntilDateTime: Date?
    }
    struct Questionnaires: Decodable {
        let questionnaires: [Questionnaire]
        let experiencePreferencesQuestionOrder: [String]
        enum CodingKeys: String, CodingKey {
            case questionnaires
            case experiencePreferencesQuestionOrder = "experience_preferences_question_order"
        }
    }
    struct People: Decodable { let personConnections: [PersonConnection] }
    struct Sub: Decodable { let subscription: Subscription }
    struct RSVPResponse: Decodable { let rsvp: RSVP }
    struct Requested: Decodable {
        let newUpcomingEventId: String
        let upcomingEventsResponse: Upcoming
    }
}
