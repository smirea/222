import Foundation

struct Outcome: Codable, Hashable {
    let personalityType: String?
    let personalityTypePercentage: Double?
    let favoriteImageUrl: URL?
    let imageUrls: [URL]?
    let traits: [Trait]?
}

struct Trait: Codable, Hashable {
    let header: String
    let adjective: String?
    let percentage: Double?
    let subheader: String?
}

struct Member: Codable, Hashable, Identifiable {
    let id: String
    let simplifiedName: String?
    let name: String?
    let profilePhotoUrl: URL?
    let outcome: Outcome?

    var displayName: String { simplifiedName ?? name ?? "Unknown" }
    var photoURL: URL? { profilePhotoUrl ?? outcome?.favoriteImageUrl }
}

/// Live events list who is coming as `group_attendees`; past events only have `my_groups`.
struct Attendee: Codable, Hashable {
    let member: Member
    let checkedInStatus: String?
}

struct AuthedMember: Codable {
    let id: String
    let name: String
    let phone: String?
    let email: String?
    let profilePhotoUrl: URL?
    let outcome: Outcome?
    let applicationStatus: String?
}

struct PriceItem: Codable, Hashable {
    let label: String
    let currency: String
    let price: Int
    let discountPrice: Int?
    let discountReason: String?

    var cents: Int { discountPrice ?? price }
}

struct AttendOption: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let priceItems: [PriceItem]
    let details: [String]?
    let allowedGroupTypes: [String]?

    var cents: Int { priceItems.reduce(0) { $0 + $1.cents } }
}

struct RSVPStatus: RawRepresentable, Codable, Hashable {
    let rawValue: String
    static let invited = RSVPStatus(rawValue: "INVITED")
    static let interested = RSVPStatus(rawValue: "INTERESTED")
    static let confirmed = RSVPStatus(rawValue: "CONFIRMED")
    static let notInterested = RSVPStatus(rawValue: "NOT_INTERESTED")

    var label: String {
        switch self {
        case .invited: "Invited"
        case .interested: "In pool"
        case .confirmed: "Going"
        case .notInterested: "Passed"
        default: rawValue.replacingOccurrences(of: "_", with: " ").lowercased()
        }
    }
}

struct Guideline: Codable, Hashable {
    let title: String
    let boxedMarkdown: String?
    let unboxedMarkdown: String?
}

struct TimelinePoint: Codable, Hashable {
    let dateTime: Date
    let label: String
}

struct Payment: Codable, Hashable {
    let id: String
    let status: String
    let price: Int?
    let currency: String?
}

struct RSVP: Codable, Hashable {
    let id: String
    let status: RSVPStatus
    let requestedAttendOption: AttendOption?
    let assignedAttendOption: AttendOption?
    let payment: Payment?
    let confirmationGuidelines: [Guideline]?
    let declineEventModalConfig: DeclineConfig?
    let additionalTimelineMetadata: AdditionalTimeline?
    let shareUrls: [String: URL]?

    struct DeclineConfig: Codable, Hashable { let declineType: String }
    struct AdditionalTimeline: Codable, Hashable { let additionalPoints: [TimelinePoint]? }
}

struct Coordinate: Codable, Hashable {
    let lat: Double
    let lon: Double
}

struct Stage: Codable, Hashable, Identifiable {
    let id: String
    let startDateTime: Date?
    let title: String
    let subtitle: String?
    let locationRevealDateTime: Date?
    let locationCoordinateObfuscated: Area?

    struct Area: Codable, Hashable {
        let coordinate: Coordinate
        let obfuscationRadiusMiles: Double
    }
}

struct Timeline: Codable, Hashable {
    let stages: [Stage]?
    let points: [TimelinePoint]?
}

struct Venue: Codable, Hashable, Identifiable {
    let id: String
    let name: String?
    let address: String?
    let coordinate: Coordinate?
    let type: String?

    var stage: String? {
        switch type {
        case nil: nil
        case "dining": "Dinner"
        case "post_dining": "After"
        case let type?: type.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var googleMaps: (app: URL, web: URL) {
        let query = [name, address].compactMap { $0 }.joined(separator: ", ")
        var app = URLComponents(string: "comgooglemaps://")!
        app.queryItems = [URLQueryItem(name: "q", value: query)]
        if let coordinate { app.queryItems?.append(URLQueryItem(name: "center", value: "\(coordinate.lat),\(coordinate.lon)")) }
        var web = URLComponents(string: "https://www.google.com/maps/search/")!
        web.queryItems = [URLQueryItem(name: "api", value: "1"), URLQueryItem(name: "query", value: query)]
        return (app.url!, web.url!)
    }
}

struct Fees: Codable, Hashable {
    let lateCancellationFeePriceItem: PriceItem?
    let noShowFeePriceItem: PriceItem?
}

struct Group: Codable, Hashable {
    let groupId: String?
    let members: [Member]
}

struct Photo: Codable, Hashable, Identifiable {
    let id: String
    let url: URL
    let takenByMemberName: String?
}

struct DayPart: Codable, Hashable {
    let date: String
    let timeOfDay: String?
}

/// One shape for upcoming, current, past and requestable events; each endpoint fills a different subset.
struct Event: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let city: String?
    let neighborhood: String?
    let blurb: String?
    let description: String?
    let startDateTime: Date
    let timeZone: String
    var rsvp: RSVP?
    let attendOptions: [AttendOption]?
    let timeline: Timeline?
    let details: [String]?
    let memberCount: Int?
    let isSoldOut: Bool?
    let isCanceled: Bool?
    let paymentDeadlineDateTime: Date?
    let lateDeadlineDateTime: Date?
    let chosenSendDateTime: Date?
    let isTwentyOnePlus: Bool?
    let numberOfPlusOnesAllowed: Int?
    let curatedGroupSize: Int?
    let maxPrivateGroupSize: Int?
    let fees: Fees?
    let groupTerm: String?
    let venues: [Venue]?
    let myGroups: [Group]?
    let groupAttendees: [Attendee]?
    let currentVenueId: String?
    let photos: [Photo]?
    let didCompleteFollowUp: Bool?
    let followUpDeadline: Date?
    let categories: [String]?
    let dateAndTimeOfDays: [DayPart]?
    let canInvitePlusOne: Bool?

    var tz: TimeZone { TimeZone(identifier: timeZone) ?? .current }
    var status: RSVPStatus? { rsvp?.status }
    var place: String { [neighborhood, city].compactMap { $0 }.joined(separator: ", ") }
    var cheapestOption: AttendOption? { attendOptions?.min { $0.cents < $1.cents } }
    var attendees: [Member] { groupAttendees?.map(\.member) ?? (myGroups ?? []).flatMap(\.members) }

    /// The guidelines text says cancelling is free until selection notifications go out, then the late fee applies, then the no-show fee.
    func cancellationFee(at now: Date = .now) -> PriceItem? {
        guard status == .confirmed || status == .interested else { return nil }
        if let late = lateDeadlineDateTime, now >= late { return fees?.noShowFeePriceItem }
        if let chosen = chosenSendDateTime, now >= chosen { return fees?.lateCancellationFeePriceItem }
        return nil
    }
}

struct RequestMetadata: Codable, Hashable {
    let lockedReason: String?
    let cantRequestUntilDateTime: Date?
}

struct Questionnaire: Codable, Hashable, Identifiable {
    let questionnaireId: String
    let title: String
    let order: [String]
    let questions: [String: Question]
    var answers: [String: JSON]
    let logic: [Logic]?

    var id: String { questionnaireId }
    enum CodingKeys: String, CodingKey {
        case questionnaireId = "questionnaire_id", title, order, questions, answers, logic
    }

    struct Logic: Codable, Hashable {
        let actions: [Action]
        struct Action: Codable, Hashable {
            let action: String
            let details: Details?
            let condition: Condition
        }
        struct Details: Codable, Hashable { let to: Value? }
        struct Condition: Codable, Hashable {
            let op: String
            let vars: [Value]
        }
        struct Value: Codable, Hashable { let value: JSON? }
    }
}

struct Question: Codable, Hashable {
    let title: String?
    let type: String
    let category: String?
    let shortTitle: String?
    let properties: Properties?

    struct Properties: Codable, Hashable {
        let choices: [Choice]?
        let allowMultipleSelection: Bool?
        let steps: Int?
        let startAtOne: Bool?
        let labels: [String: String]?
        let groupTitle: String?
        let description: String?
        enum CodingKeys: String, CodingKey {
            case choices, steps, labels, description
            case allowMultipleSelection = "allow_multiple_selection"
            case startAtOne = "start_at_one", groupTitle = "group_title"
        }
    }

    enum CodingKeys: String, CodingKey {
        case title, type, category, properties, shortTitle = "short_title"
    }

    struct Choice: Codable, Hashable { let label: String }
}

struct PersonConnection: Codable, Hashable, Identifiable {
    let personConnectionId: String
    let firstMetIrlDate: String?
    let lastInteractedDate: String?
    let eventIdsTogether: [String]?
    let compatibility: Double?
    let wasIrlCompatible: Bool?
    let suggestibility: Double?
    let isCloseFriend: Bool?
    let otherPerson: OtherPerson

    var id: String { personConnectionId }
    struct OtherPerson: Codable, Hashable { let member: Member? }
}

struct Subscription: Codable, Hashable {
    let activePlan: Plan?

    struct Plan: Codable, Hashable {
        let duration: String?
        let recurringPriceItem: PriceItem?
        let cancelLink: URL?
        let endDate: Date?
        let willCancelAtEndDate: Bool?
    }
}

func money(_ cents: Int, _ currency: String = "USD") -> String {
    (Double(cents) / 100).formatted(.currency(code: currency))
}
