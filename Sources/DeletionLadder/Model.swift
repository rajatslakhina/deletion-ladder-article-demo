/// The seven rungs of the deletion ladder, in the order an agent should walk them.
/// The first rung that holds decides what gets written.
public enum Rung: Int, CaseIterable, Comparable, Sendable {
    case needsToExist = 1
    case alreadyInCodebase
    case standardLibrary
    case platformFeature
    case installedDependency
    case oneLine
    case minimumThatWorks

    public static func < (lhs: Rung, rhs: Rung) -> Bool { lhs.rawValue < rhs.rawValue }

    /// The question the agent has to answer at this rung.
    public var question: String {
        switch self {
        case .needsToExist: return "Does the ticket need this to exist?"
        case .alreadyInCodebase: return "Is it already in this codebase?"
        case .standardLibrary: return "Does Swift or Foundation already do it?"
        case .platformFeature: return "Is it a SwiftUI, UIKit or App Intents feature?"
        case .installedDependency: return "Does a package we already depend on do it?"
        case .oneLine: return "Can it be one line?"
        case .minimumThatWorks: return "Only then: write the minimum that works."
        }
    }

    public var shortName: String {
        switch self {
        case .needsToExist: return "Doesn't need to exist"
        case .alreadyInCodebase: return "Already in codebase"
        case .standardLibrary: return "Swift / Foundation"
        case .platformFeature: return "Platform feature"
        case .installedDependency: return "Installed dependency"
        case .oneLine: return "One line"
        case .minimumThatWorks: return "Minimum that works"
        }
    }
}

/// What a line of code is for. Everything except `.logic` is on the floor:
/// the ladder may only remove it when the replacement demonstrably does the same job.
public enum LineRole: String, CaseIterable, Sendable {
    case logic
    case validation       // checks on input that crosses a trust boundary
    case errorHandling    // handling that prevents data loss or silent failure
    case accessibility
    case security

    public var isProtected: Bool { self != .logic }
}

/// Something that already exists and could replace hand-written code.
public struct Provider: Equatable, Sendable {
    public let rung: Rung
    /// The API or symbol the agent should call instead, e.g. `ShareLink`.
    public let symbol: String
    /// Lines of code it takes to use the provider at the call site.
    public let callSiteLines: Int
    /// Protected roles the provider genuinely takes over. A system `DatePicker`
    /// covers accessibility; `onOpenURL` does not validate the URL for you.
    public let covers: Set<LineRole>

    public init(rung: Rung, symbol: String, callSiteLines: Int, covers: Set<LineRole> = []) {
        precondition(callSiteLines >= 0, "callSiteLines can't be negative")
        self.rung = rung
        self.symbol = symbol
        self.callSiteLines = callSiteLines
        self.covers = covers
    }
}

/// A change an agent proposed, summarised by what it implements and what its lines are for.
public struct ProposedChange: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    /// The capability the code implements, used to look up existing providers.
    public let capability: String
    /// Whether the ticket actually asks for this capability.
    public let requestedByTicket: Bool
    /// Added lines, counted by role.
    public let lines: [LineRole: Int]

    public init(id: String, title: String, capability: String, requestedByTicket: Bool = true, lines: [LineRole: Int]) {
        self.id = id
        self.title = title
        self.capability = capability
        self.requestedByTicket = requestedByTicket
        self.lines = lines.filter { $0.value > 0 }
    }

    public var totalLines: Int { lines.values.reduce(0, +) }
    public var protectedLines: Int { lines.filter { $0.key.isProtected }.map(\.value).reduce(0, +) }
    public func lines(for role: LineRole) -> Int { lines[role] ?? 0 }
}

/// Everything the agent could reuse instead of writing new code, keyed by capability.
public struct CapabilityCatalog: Sendable {
    private var providers: [String: [Provider]]

    public init(_ providers: [String: [Provider]] = [:]) {
        self.providers = providers
    }

    public mutating func register(_ provider: Provider, for capability: String) {
        providers[capability, default: []].append(provider)
    }

    /// Providers for a capability, lowest rung first. Ties keep registration order.
    public func providers(for capability: String) -> [Provider] {
        let found = providers[capability] ?? []
        return found.enumerated()
            .sorted { lhs, rhs in
                lhs.element.rung == rhs.element.rung ? lhs.offset < rhs.offset : lhs.element.rung < rhs.element.rung
            }
            .map(\.element)
    }
}
