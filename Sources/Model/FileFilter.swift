import Foundation
import UniformTypeIdentifiers

/// A composable predicate on FileNode.
/// Replaces the Obj-C Filter / FilterTest / FileItemTest / CompoundItemTest hierarchy.
///
/// Usage:
///   let filter = .and([
///       .not(.hardLinked),
///       .sizeRange(min: 1024, max: nil),
///       .filesOnly(.nameMatches(["*.log"], caseSensitive: false))
///   ])
///   let passes = filter.test(node)
enum FileFilter: Sendable {

    /// Result of testing a node.
    enum Result: Int8, Sendable {
        case passed = 1
        case failed = 0
        case notApplicable = -1
    }

    // MARK: - Leaf tests

    /// Matches file size within [min, max]. nil bound = unbounded.
    case sizeRange(min: UInt64?, max: UInt64?)

    /// Matches file name against patterns (glob-style or exact).
    case nameMatches([String], caseSensitive: Bool)

    /// Matches file path against patterns.
    case pathMatches([String], caseSensitive: Bool)

    /// Matches uniform type (conformance check unless strict).
    case typeMatches([UTType], strict: Bool)

    /// Matches flags (hardLinked, package).
    case hasFlags(FileNode.Flags)

    /// Matches absence of flags.
    case lacksFlags(FileNode.Flags)

    // MARK: - Combinators

    /// All sub-filters must pass (AND).
    case and([FileFilter])

    /// At least one sub-filter must pass (OR).
    case or([FileFilter])

    /// Inverts the result.
    indirect case not(FileFilter)

    /// Applies sub-filter only to files (notApplicable for directories).
    indirect case filesOnly(FileFilter)

    /// Applies sub-filter only to directories (notApplicable for files).
    indirect case directoriesOnly(FileFilter)

    // MARK: - Convenience factories

    /// Matches hard-linked items.
    static var hardLinked: FileFilter { .hasFlags(.hardLinked) }

    /// Matches packages.
    static var package: FileFilter { .hasFlags(.package) }

    // MARK: - Test

    func test(_ node: FileNode) -> Result {
        switch self {
        case .sizeRange(let min, let max):
            let size = node.size
            if let min, size < min { return .failed }
            if let max, size > max { return .failed }
            return .passed

        case .nameMatches(let patterns, let caseSensitive):
            let name = caseSensitive ? node.name : node.name.lowercased()
            for pattern in patterns {
                let p = caseSensitive ? pattern : pattern.lowercased()
                if name == p { return .passed }
            }
            return .failed

        case .pathMatches(let patterns, let caseSensitive):
            let path = caseSensitive ? node.path : node.path.lowercased()
            for pattern in patterns {
                let p = caseSensitive ? pattern : pattern.lowercased()
                if path.contains(p) { return .passed }
            }
            return .failed

        case .typeMatches(let types, let strict):
            guard let nodeType = node.type else { return .notApplicable }
            for t in types {
                if strict {
                    if nodeType == t { return .passed }
                } else {
                    if nodeType.conforms(to: t) { return .passed }
                }
            }
            return .failed

        case .hasFlags(let flags):
            return node.flags.contains(flags) ? .passed : .failed

        case .lacksFlags(let flags):
            return node.flags.isDisjoint(with: flags) ? .passed : .failed

        case .and(let filters):
            var anyPassed = false
            for f in filters {
                switch f.test(node) {
                case .failed: return .failed
                case .passed: anyPassed = true
                case .notApplicable: continue
                }
            }
            return anyPassed ? .passed : .notApplicable

        case .or(let filters):
            var allNotApplicable = true
            for f in filters {
                switch f.test(node) {
                case .passed: return .passed
                case .failed: allNotApplicable = false
                case .notApplicable: continue
                }
            }
            return allNotApplicable ? .notApplicable : .failed

        case .not(let filter):
            switch filter.test(node) {
            case .passed: return .failed
            case .failed: return .passed
            case .notApplicable: return .notApplicable
            }

        case .filesOnly(let filter):
            guard !node.isDirectory else { return .notApplicable }
            return filter.test(node)

        case .directoriesOnly(let filter):
            guard node.isDirectory else { return .notApplicable }
            return filter.test(node)
        }
    }

    /// Convenience: returns true if passed, false otherwise.
    func passes(_ node: FileNode) -> Bool {
        test(node) == .passed
    }
}

// MARK: - Named Filter

/// A named, reusable filter (replaces NamedFilter from Obj-C).
struct NamedFilter: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let filter: FileFilter

    /// Default filters matching the Obj-C originals.
    static let defaults: [NamedFilter] = [
        NamedFilter(name: "No hard-links", filter: .not(.hardLinked)),
        NamedFilter(name: "No version control", filter: .not(
            .nameMatches(["CVS", ".svn", ".hg", ".git", ".bzr"], caseSensitive: false)
        )),
    ]
}
