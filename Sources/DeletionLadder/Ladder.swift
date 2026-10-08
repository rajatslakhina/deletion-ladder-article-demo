/// How the gate treats protected lines when an existing provider replaces a change.
public enum FloorPolicy: String, CaseIterable, Sendable {
    /// Count every replaced line as removable. Maximises the line-count win.
    case linesOnly
    /// Keep any protected line the replacement does not take over.
    case protectedFloor
}

/// What the ladder decided for one proposed change.
public struct Verdict: Identifiable, Equatable, Sendable {
    public var id: String { change.id }
    public let change: ProposedChange
    public let rung: Rung
    /// The existing API the change should call instead, if a rung below "minimum" held.
    public let replacement: Provider?
    /// Lines the change ends up with after the ladder.
    public let projectedLines: Int
    /// Protected lines kept because the replacement doesn't do their job.
    public let keptProtected: [LineRole: Int]
    /// Protected lines removed even though nothing replaces their job.
    /// Always empty under `.protectedFloor`.
    public let unsafeDeletions: [LineRole: Int]

    public var removedLines: Int { change.totalLines - projectedLines }
    public var reduction: Double {
        change.totalLines == 0 ? 0 : Double(removedLines) / Double(change.totalLines)
    }
    public var unsafeDeletionCount: Int { unsafeDeletions.values.reduce(0, +) }
}

/// Walks the ladder for each change, top rung first, and stops at the first rung that holds.
public struct DeletionLadder: Sendable {
    public let catalog: CapabilityCatalog
    public let policy: FloorPolicy

    public init(catalog: CapabilityCatalog, policy: FloorPolicy = .protectedFloor) {
        self.catalog = catalog
        self.policy = policy
    }

    public func evaluate(_ change: ProposedChange) -> Verdict {
        // Rung 1: code the ticket never asked for goes, protected lines included,
        // because what they protected goes with it.
        guard change.requestedByTicket else {
            return Verdict(change: change, rung: .needsToExist, replacement: nil,
                           projectedLines: 0, keptProtected: [:], unsafeDeletions: [:])
        }

        guard let provider = catalog.providers(for: change.capability).first else {
            // Nothing to reuse. The ladder can't shrink code it has no alternative for.
            return Verdict(change: change, rung: .minimumThatWorks, replacement: nil,
                           projectedLines: change.totalLines,
                           keptProtected: [:], unsafeDeletions: [:])
        }

        var kept: [LineRole: Int] = [:]
        var unsafe: [LineRole: Int] = [:]
        for role in LineRole.allCases where role.isProtected && !provider.covers.contains(role) {
            let count = change.lines(for: role)
            guard count > 0 else { continue }
            switch policy {
            case .protectedFloor: kept[role] = count
            case .linesOnly: unsafe[role] = count
            }
        }

        let keptCount = kept.values.reduce(0, +)
        // Never project more lines than the agent wrote: if the call site plus the floor
        // is bigger than the original, the original was already the minimum.
        let projected = min(change.totalLines, provider.callSiteLines + keptCount)
        if projected == change.totalLines {
            return Verdict(change: change, rung: .minimumThatWorks, replacement: nil,
                           projectedLines: change.totalLines, keptProtected: [:], unsafeDeletions: [:])
        }
        return Verdict(change: change, rung: provider.rung, replacement: provider,
                       projectedLines: projected, keptProtected: kept, unsafeDeletions: unsafe)
    }

    public func evaluate(_ changes: [ProposedChange]) -> [Verdict] {
        changes.map(evaluate)
    }
}
