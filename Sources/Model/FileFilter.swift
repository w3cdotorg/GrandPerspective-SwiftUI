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

    /// Matches creation date within [min, max]. nil bound = unbounded.
    case creationDateRange(min: Date?, max: Date?)

    /// Matches modification date within [min, max]. nil bound = unbounded.
    case modificationDateRange(min: Date?, max: Date?)

    /// Matches access date within [min, max]. nil bound = unbounded.
    case accessDateRange(min: Date?, max: Date?)

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

        case .creationDateRange(let min, let max):
            guard let date = node.creationDate else { return .notApplicable }
            return Self.testDate(date, min: min, max: max)

        case .modificationDateRange(let min, let max):
            guard let date = node.modificationDate else { return .notApplicable }
            return Self.testDate(date, min: min, max: max)

        case .accessDateRange(let min, let max):
            guard let date = node.accessDate else { return .notApplicable }
            return Self.testDate(date, min: min, max: max)

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

    private static func testDate(_ date: Date, min: Date?, max: Date?) -> Result {
        if let min, date < min { return .failed }
        if let max, date > max { return .failed }
        return .passed
    }

    /// Convenience: returns true if passed, false otherwise.
    func passes(_ node: FileNode) -> Bool {
        test(node) == .passed
    }
}

// MARK: - Codable

extension FileFilter: Codable {
    private enum CodingCase: String, Codable {
        case sizeRange, nameMatches, pathMatches, typeMatches, hasFlags, lacksFlags
        case creationDateRange, modificationDateRange, accessDateRange
        case and, or, not, filesOnly, directoriesOnly
    }

    private enum CodingKeys: String, CodingKey {
        case type, min, max, patterns, caseSensitive, types, strict
        case flags, filters, filter, minDate, maxDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(CodingCase.self, forKey: .type)
        switch type {
        case .sizeRange:
            self = .sizeRange(
                min: try c.decodeIfPresent(UInt64.self, forKey: .min),
                max: try c.decodeIfPresent(UInt64.self, forKey: .max)
            )
        case .nameMatches:
            self = .nameMatches(
                try c.decode([String].self, forKey: .patterns),
                caseSensitive: try c.decode(Bool.self, forKey: .caseSensitive)
            )
        case .pathMatches:
            self = .pathMatches(
                try c.decode([String].self, forKey: .patterns),
                caseSensitive: try c.decode(Bool.self, forKey: .caseSensitive)
            )
        case .typeMatches:
            let ids = try c.decode([String].self, forKey: .types)
            self = .typeMatches(
                ids.compactMap { UTType($0) },
                strict: try c.decode(Bool.self, forKey: .strict)
            )
        case .hasFlags:
            self = .hasFlags(FileNode.Flags(rawValue: try c.decode(UInt8.self, forKey: .flags)))
        case .lacksFlags:
            self = .lacksFlags(FileNode.Flags(rawValue: try c.decode(UInt8.self, forKey: .flags)))
        case .creationDateRange:
            self = .creationDateRange(
                min: try c.decodeIfPresent(Date.self, forKey: .minDate),
                max: try c.decodeIfPresent(Date.self, forKey: .maxDate)
            )
        case .modificationDateRange:
            self = .modificationDateRange(
                min: try c.decodeIfPresent(Date.self, forKey: .minDate),
                max: try c.decodeIfPresent(Date.self, forKey: .maxDate)
            )
        case .accessDateRange:
            self = .accessDateRange(
                min: try c.decodeIfPresent(Date.self, forKey: .minDate),
                max: try c.decodeIfPresent(Date.self, forKey: .maxDate)
            )
        case .and:
            self = .and(try c.decode([FileFilter].self, forKey: .filters))
        case .or:
            self = .or(try c.decode([FileFilter].self, forKey: .filters))
        case .not:
            self = .not(try c.decode(FileFilter.self, forKey: .filter))
        case .filesOnly:
            self = .filesOnly(try c.decode(FileFilter.self, forKey: .filter))
        case .directoriesOnly:
            self = .directoriesOnly(try c.decode(FileFilter.self, forKey: .filter))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .sizeRange(let min, let max):
            try c.encode(CodingCase.sizeRange, forKey: .type)
            try c.encodeIfPresent(min, forKey: .min)
            try c.encodeIfPresent(max, forKey: .max)
        case .nameMatches(let patterns, let cs):
            try c.encode(CodingCase.nameMatches, forKey: .type)
            try c.encode(patterns, forKey: .patterns)
            try c.encode(cs, forKey: .caseSensitive)
        case .pathMatches(let patterns, let cs):
            try c.encode(CodingCase.pathMatches, forKey: .type)
            try c.encode(patterns, forKey: .patterns)
            try c.encode(cs, forKey: .caseSensitive)
        case .typeMatches(let types, let strict):
            try c.encode(CodingCase.typeMatches, forKey: .type)
            try c.encode(types.map(\.identifier), forKey: .types)
            try c.encode(strict, forKey: .strict)
        case .hasFlags(let flags):
            try c.encode(CodingCase.hasFlags, forKey: .type)
            try c.encode(flags.rawValue, forKey: .flags)
        case .lacksFlags(let flags):
            try c.encode(CodingCase.lacksFlags, forKey: .type)
            try c.encode(flags.rawValue, forKey: .flags)
        case .creationDateRange(let min, let max):
            try c.encode(CodingCase.creationDateRange, forKey: .type)
            try c.encodeIfPresent(min, forKey: .minDate)
            try c.encodeIfPresent(max, forKey: .maxDate)
        case .modificationDateRange(let min, let max):
            try c.encode(CodingCase.modificationDateRange, forKey: .type)
            try c.encodeIfPresent(min, forKey: .minDate)
            try c.encodeIfPresent(max, forKey: .maxDate)
        case .accessDateRange(let min, let max):
            try c.encode(CodingCase.accessDateRange, forKey: .type)
            try c.encodeIfPresent(min, forKey: .minDate)
            try c.encodeIfPresent(max, forKey: .maxDate)
        case .and(let filters):
            try c.encode(CodingCase.and, forKey: .type)
            try c.encode(filters, forKey: .filters)
        case .or(let filters):
            try c.encode(CodingCase.or, forKey: .type)
            try c.encode(filters, forKey: .filters)
        case .not(let filter):
            try c.encode(CodingCase.not, forKey: .type)
            try c.encode(filter, forKey: .filter)
        case .filesOnly(let filter):
            try c.encode(CodingCase.filesOnly, forKey: .type)
            try c.encode(filter, forKey: .filter)
        case .directoriesOnly(let filter):
            try c.encode(CodingCase.directoriesOnly, forKey: .type)
            try c.encode(filter, forKey: .filter)
        }
    }
}

// MARK: - Named Filter

/// A named, reusable filter (replaces NamedFilter from Obj-C).
struct NamedFilter: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let filter: FileFilter

    init(id: UUID = UUID(), name: String, filter: FileFilter) {
        self.id = id
        self.name = name
        self.filter = filter
    }

    /// Default filters matching the Obj-C originals.
    static let defaults: [NamedFilter] = [
        NamedFilter(name: "No hard-links", filter: .not(.hardLinked)),
        NamedFilter(name: "No version control", filter: .not(
            .nameMatches(["CVS", ".svn", ".hg", ".git", ".bzr"], caseSensitive: false)
        )),
    ]
}
