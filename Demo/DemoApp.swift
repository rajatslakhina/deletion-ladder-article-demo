import SwiftUI
import DeletionLadder

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

enum DemoTab: String, CaseIterable, Identifiable {
    case ladder, floor, measure, prompt
    var id: String { rawValue }
    var title: String {
        switch self {
        case .ladder: return "Ladder"
        case .floor: return "Floor"
        case .measure: return "Measure"
        case .prompt: return "Prompt"
        }
    }
}

func percent(_ value: Double) -> String { String(format: "%.1f%%", value * 100) }

/// Launch arguments (used by CI to take screenshots):
///   -tab ladder|floor|measure|prompt
///   -policy protectedFloor|linesOnly
struct RootView: View {
    @State private var tab: DemoTab
    @State private var policy: FloorPolicy

    init() {
        let rawTab = UserDefaults.standard.string(forKey: "tab") ?? DemoTab.ladder.rawValue
        _tab = State(initialValue: DemoTab(rawValue: rawTab) ?? .ladder)
        let rawPolicy = UserDefaults.standard.string(forKey: "policy") ?? FloorPolicy.protectedFloor.rawValue
        _policy = State(initialValue: FloorPolicy(rawValue: rawPolicy) ?? .protectedFloor)
    }

    private var verdicts: [Verdict] {
        DeletionLadder(catalog: SampleSprint.catalog, policy: policy).evaluate(SampleSprint.changes)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch tab {
                case .ladder: LadderList(verdicts: verdicts)
                case .floor: FloorView(policy: $policy)
                case .measure: MeasureView(report: ReductionReport(verdicts), policy: policy)
                case .prompt: PromptView()
                }
            }
            .safeAreaInset(edge: .top) {
                VStack(spacing: 6) {
                    Picker("View", selection: $tab) {
                        ForEach(DemoTab.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Policy", selection: $policy) {
                        Text("Protected floor").tag(FloorPolicy.protectedFloor)
                        Text("Lines only").tag(FloorPolicy.linesOnly)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                .padding(.bottom, 6)
                .background(.bar)
            }
            .navigationTitle("Deletion Ladder")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct RungBadge: View {
    let rung: Rung
    var color: Color {
        switch rung {
        case .needsToExist: return .purple
        case .alreadyInCodebase: return .blue
        case .standardLibrary: return .teal
        case .platformFeature: return .green
        case .installedDependency: return .orange
        case .oneLine: return .pink
        case .minimumThatWorks: return .gray
        }
    }
    var body: some View {
        Text("\(rung.rawValue) · \(rung.shortName)")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

struct LadderList: View {
    let verdicts: [Verdict]
    var body: some View {
        List(verdicts) { verdict in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(verdict.change.title).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(verdict.change.totalLines) → \(verdict.projectedLines)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(verdict.removedLines == 0 ? .secondary : .primary)
                }
                RungBadge(rung: verdict.rung)
                if let replacement = verdict.replacement {
                    Text(replacement.symbol)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if verdict.unsafeDeletionCount > 0 {
                    Label("Deletes \(verdict.unsafeDeletionCount) protected lines nothing replaces",
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if !verdict.keptProtected.isEmpty {
                    Label("Keeps \(verdict.keptProtected.values.reduce(0, +)) protected lines",
                          systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(.vertical, 2)
        }
        .listStyle(.plain)
    }
}

struct FloorView: View {
    @Binding var policy: FloorPolicy
    private var floor: ReductionReport {
        ReductionReport(DeletionLadder(catalog: SampleSprint.catalog, policy: .protectedFloor).evaluate(SampleSprint.changes))
    }
    private var linesOnly: ReductionReport {
        ReductionReport(DeletionLadder(catalog: SampleSprint.catalog, policy: .linesOnly).evaluate(SampleSprint.changes))
    }
    private var unsafe: [Verdict] {
        DeletionLadder(catalog: SampleSprint.catalog, policy: .linesOnly)
            .evaluate(SampleSprint.changes)
            .filter { $0.unsafeDeletionCount > 0 }
    }

    var body: some View {
        List {
            Section("Same sprint, two scoring rules") {
                row("Lines only", after: linesOnly.linesAfter, pooled: linesOnly.pooledReduction,
                    unsafe: linesOnly.unsafeDeletions, selected: policy == .linesOnly)
                row("Protected floor", after: floor.linesAfter, pooled: floor.pooledReduction,
                    unsafe: floor.unsafeDeletions, selected: policy == .protectedFloor)
            }
            Section("What \"lines only\" wins by") {
                ForEach(unsafe) { verdict in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verdict.change.title).font(.subheadline.weight(.semibold))
                        Text(verdict.unsafeDeletions
                                .sorted { $0.key.rawValue < $1.key.rawValue }
                                .map { "\($0.value) \($0.key.rawValue)" }
                                .joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.red)
                        Text("Replacement: \(verdict.replacement?.symbol ?? "none")")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                Text("\(linesOnly.linesRemoved - floor.linesRemoved) more lines deleted. Every one of them is validation, security or error handling.")
                    .font(.footnote)
            }
        }
    }

    private func row(_ title: String, after: Int, pooled: Double, unsafe: Int, selected: Bool) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title).font(.subheadline.weight(selected ? .bold : .regular))
                Text("\(floor.linesBefore) → \(after) lines · \(percent(pooled)) removed")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(unsafe == 0 ? "0 unsafe" : "\(unsafe) unsafe")
                .font(.caption.weight(.semibold))
                .foregroundStyle(unsafe == 0 ? .green : .red)
        }
    }
}

struct MeasureView: View {
    let report: ReductionReport
    let policy: FloorPolicy
    var body: some View {
        List {
            Section("Headline") {
                metric("Lines", "\(report.linesBefore) → \(report.linesAfter)")
                metric("Pooled reduction", percent(report.pooledReduction))
            }
            Section("What a lead should also read") {
                metric("Mean per change", percent(report.meanReduction))
                metric("Median per change", percent(report.medianReduction))
                metric("Top \(report.topCount) changes' share of removed lines", percent(report.topShare))
                metric("Changes the ladder couldn't shrink", "\(report.untouchedCount) of \(report.changeCount)")
                metric("Protected lines deleted unsafely", "\(report.unsafeDeletions)")
            }
            Section("Where each change stopped") {
                ForEach(Rung.allCases, id: \.self) { rung in
                    HStack {
                        RungBadge(rung: rung)
                        Spacer()
                        Text("\(report.rungCounts[rung] ?? 0)").font(.callout.monospacedDigit())
                    }
                }
            }
            Section {
                Text("Constructed sprint: 12 illustrative changes, not a benchmark. Policy: \(policy == .protectedFloor ? "protected floor" : "lines only").")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline.monospacedDigit().weight(.semibold))
        }
    }
}

struct PromptView: View {
    private var text: String {
        PromptRenderer.render(catalog: SampleSprint.catalog,
                              capabilities: SampleSprint.changes.map(\.capability))
    }
    var body: some View {
        ScrollView {
            Text(text)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
}
