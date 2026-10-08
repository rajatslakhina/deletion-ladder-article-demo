/// Renders the ladder as an always-on rule block for an agent instructions file
/// (`AGENTS.md`, `CLAUDE.md` or a per-agent rules file). Plain Markdown, any language.
public enum PromptRenderer {
    public static func render(catalog: CapabilityCatalog, capabilities: [String], platform: String = "iOS") -> String {
        var out: [String] = []
        out.append("## Before you write code (\(platform))")
        out.append("")
        out.append("Read the code this change touches and trace the real flow first. Then stop at the first rung that holds:")
        out.append("")
        for rung in Rung.allCases {
            out.append("\(rung.rawValue). \(rung.question)")
        }
        out.append("")
        out.append("Never remove input validation at a trust boundary, error handling that prevents data loss, security checks or accessibility, unless the API you replace them with does that job. Say which API does it.")

        let hints = capabilities.compactMap { capability -> String? in
            guard let provider = catalog.providers(for: capability).first else { return nil }
            return "- \(capability): use `\(provider.symbol)` (\(provider.rung.shortName.lowercased()))"
        }
        if !hints.isEmpty {
            out.append("")
            out.append("Known replacements in this repo:")
            out.append(contentsOf: hints)
        }
        return out.joined(separator: "\n")
    }
}
