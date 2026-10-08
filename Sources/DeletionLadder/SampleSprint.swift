/// A constructed sprint: twelve changes of the kind a coding agent writes in an iOS app
/// when nobody asks it what already exists. The line counts are illustrative, not measured
/// from a real repository.
public enum SampleSprint {
    public static let catalog: CapabilityCatalog = {
        var c = CapabilityCatalog()
        c.register(Provider(rung: .platformFeature, symbol: "DatePicker(selection:displayedComponents:)",
                            callSiteLines: 4, covers: [.accessibility]), for: "date-picker")
        c.register(Provider(rung: .standardLibrary, symbol: "date.formatted(.relative(presentation: .named))",
                            callSiteLines: 1), for: "relative-time")
        c.register(Provider(rung: .installedDependency, symbol: "AsyncAlgorithms .debounce(for:)",
                            callSiteLines: 3), for: "debounce")
        c.register(Provider(rung: .platformFeature, symbol: "ShareLink(item:)",
                            callSiteLines: 3, covers: [.accessibility]), for: "share-sheet")
        c.register(Provider(rung: .alreadyInCodebase, symbol: "ImagePipeline.shared.image(for:)",
                            callSiteLines: 2, covers: [.errorHandling]), for: "image-cache")
        c.register(Provider(rung: .alreadyInCodebase, symbol: "HTTPClient.send(_:retry: .standard)",
                            callSiteLines: 2, covers: [.errorHandling]), for: "retry-backoff")
        c.register(Provider(rung: .platformFeature, symbol: ".onOpenURL { router.open($0) }",
                            callSiteLines: 3), for: "deep-link")
        c.register(Provider(rung: .installedDependency, symbol: "KeychainAccess Keychain(service:)",
                            callSiteLines: 4), for: "keychain-store")
        c.register(Provider(rung: .oneLine, symbol: "name.prefix(1).uppercased() + name.dropFirst()",
                            callSiteLines: 1), for: "capitalise-first")
        c.register(Provider(rung: .platformFeature, symbol: ".refreshable { await model.reload() }",
                            callSiteLines: 3), for: "pull-to-refresh")
        return c
    }()

    public static let changes: [ProposedChange] = [
        ProposedChange(id: "date-picker", title: "Custom date picker sheet", capability: "date-picker",
                       lines: [.logic: 212, .accessibility: 8]),
        ProposedChange(id: "relative-time", title: "\"3 min ago\" formatter", capability: "relative-time",
                       lines: [.logic: 46]),
        ProposedChange(id: "debounce", title: "Search debouncer class", capability: "debounce",
                       lines: [.logic: 38]),
        ProposedChange(id: "share-sheet", title: "UIActivityViewController wrapper", capability: "share-sheet",
                       lines: [.logic: 31, .accessibility: 2]),
        ProposedChange(id: "image-cache", title: "In-memory image cache", capability: "image-cache",
                       lines: [.logic: 104, .errorHandling: 12]),
        ProposedChange(id: "retry-backoff", title: "Retry with exponential backoff", capability: "retry-backoff",
                       lines: [.logic: 58, .errorHandling: 9]),
        ProposedChange(id: "deep-link", title: "Deep-link URL parser", capability: "deep-link",
                       lines: [.logic: 44, .validation: 11]),
        ProposedChange(id: "keychain", title: "Token storage in the Keychain", capability: "keychain-store",
                       lines: [.logic: 71, .security: 4, .errorHandling: 6]),
        ProposedChange(id: "capitalise", title: "Capitalise display name", capability: "capitalise-first",
                       lines: [.logic: 9]),
        ProposedChange(id: "analytics", title: "Screen-view analytics wrapper", capability: "analytics-wrapper",
                       requestedByTicket: false, lines: [.logic: 27, .errorHandling: 3]),
        ProposedChange(id: "settings-toggle", title: "Settings toggle for haptics", capability: "settings-toggle",
                       lines: [.logic: 11, .accessibility: 1]),
        ProposedChange(id: "pull-to-refresh", title: "Pull to refresh on the feed", capability: "pull-to-refresh",
                       lines: [.logic: 3])
    ]
}
