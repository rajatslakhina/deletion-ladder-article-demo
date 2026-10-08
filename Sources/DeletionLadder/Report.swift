/// Honest aggregate numbers for a batch of verdicts.
///
/// A mean line reduction is the number a README puts in its headline. A lead needs the
/// numbers underneath it too: the median, how concentrated the win is, and how many
/// changes the ladder couldn't touch at all.
public struct ReductionReport: Equatable, Sendable {
    public let changeCount: Int
    public let linesBefore: Int
    public let linesAfter: Int
    /// Mean of per-change reductions (each change weighted equally).
    public let meanReduction: Double
    /// Median of per-change reductions.
    public let medianReduction: Double
    /// Share of all removed lines that come from the `topCount` biggest removals.
    public let topShare: Double
    public let topCount: Int
    /// Changes the ladder left at their original size.
    public let untouchedCount: Int
    /// Protected lines removed with nothing taking over their job.
    public let unsafeDeletions: Int
    public let rungCounts: [Rung: Int]

    public var linesRemoved: Int { linesBefore - linesAfter }
    public var pooledReduction: Double {
        linesBefore == 0 ? 0 : Double(linesRemoved) / Double(linesBefore)
    }

    public init(_ verdicts: [Verdict], topCount requestedTop: Int = 2) {
        let top = max(0, requestedTop)
        changeCount = verdicts.count
        linesBefore = verdicts.map(\.change.totalLines).reduce(0, +)
        linesAfter = verdicts.map(\.projectedLines).reduce(0, +)

        let reductions = verdicts.map(\.reduction).sorted()
        meanReduction = reductions.isEmpty ? 0 : reductions.reduce(0, +) / Double(reductions.count)
        medianReduction = ReductionReport.median(of: reductions)

        let removed = verdicts.map(\.removedLines).sorted(by: >)
        let totalRemoved = removed.reduce(0, +)
        let topRemoved = removed.prefix(top).reduce(0, +)
        topShare = totalRemoved == 0 ? 0 : Double(topRemoved) / Double(totalRemoved)
        self.topCount = min(top, removed.count)

        untouchedCount = verdicts.filter { $0.removedLines == 0 }.count
        unsafeDeletions = verdicts.map(\.unsafeDeletionCount).reduce(0, +)
        rungCounts = Dictionary(grouping: verdicts, by: \.rung).mapValues(\.count)
    }

    /// Median of an already-sorted array. Empty input gives 0.
    static func median(of sorted: [Double]) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let mid = sorted.count / 2
        if sorted.count % 2 == 1 { return sorted[mid] }
        return (sorted[mid - 1] + sorted[mid]) / 2
    }
}
