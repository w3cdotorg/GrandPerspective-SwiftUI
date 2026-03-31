import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Codable proxy for FileNode tree

/// Lightweight serializable representation of a FileNode tree.
/// Used by ScanDocument for .gpscan file persistence.
struct CodableNode: Codable {
    let name: String
    let kind: String          // "file", "directory", "synthetic:<role>"
    let size: UInt64
    let children: [CodableNode]
    let creationDate: Date?
    let modificationDate: Date?
    let accessDate: Date?
    let flags: UInt8
    let typeIdentifier: String?

    init(from node: FileNode) {
        name = node.name
        kind = switch node.kind {
        case .file: "file"
        case .directory: "directory"
        case .synthetic(let role): "synthetic:\(role.rawValue)"
        }
        size = node.size
        children = node.children.map { CodableNode(from: $0) }
        creationDate = node.creationDate
        modificationDate = node.modificationDate
        accessDate = node.accessDate
        flags = node.flags.rawValue
        typeIdentifier = node.type?.identifier
    }

    func toFileNode() -> FileNode {
        let nodeKind: FileNode.Kind
        if kind == "file" {
            nodeKind = .file
        } else if kind == "directory" {
            nodeKind = .directory
        } else if kind.hasPrefix("synthetic:") {
            let roleString = String(kind.dropFirst("synthetic:".count))
            let role = FileNode.SyntheticRole(rawValue: roleString) ?? .usedSpace
            nodeKind = .synthetic(role)
        } else {
            nodeKind = .file
        }

        let utType = typeIdentifier.flatMap { UTType($0) }

        return FileNode(
            name: name,
            kind: nodeKind,
            size: size,
            children: children.map { $0.toFileNode() },
            creationDate: creationDate,
            modificationDate: modificationDate,
            accessDate: accessDate,
            flags: FileNode.Flags(rawValue: flags),
            type: utType
        )
    }
}

// MARK: - Codable proxy for ScanResult

struct CodableScanResult: Codable {
    static let formatVersion = 2

    let formatVersion: Int
    let tree: CodableNode
    let volumePath: String
    let volumeSize: UInt64
    let freeSpace: UInt64
    let scanTime: Date
    let sizeMeasure: String
    let comments: String

    init(from result: ScanResult) {
        formatVersion = Self.formatVersion
        tree = CodableNode(from: result.scanTree)
        volumePath = result.volumePath
        volumeSize = result.volumeSize
        freeSpace = result.freeSpace
        scanTime = result.scanTime
        sizeMeasure = result.sizeMeasure.rawValue
        comments = result.comments
    }

    func toScanResult() -> ScanResult {
        let measure = FileSystemScanner.SizeMeasure(rawValue: sizeMeasure) ?? .logical
        return ScanResult(
            scanTree: tree.toFileNode(),
            volumePath: volumePath,
            volumeSize: volumeSize,
            freeSpace: freeSpace,
            scanTime: scanTime,
            sizeMeasure: measure,
            comments: comments
        )
    }
}

// MARK: - UTType for .gpscan

extension UTType {
    static let gpscan = UTType(exportedAs: "net.sourceforge.grandperspectiv.gpscan")
}

// MARK: - FileDocument

/// SwiftUI document type for reading/writing .gpscan scan files.
/// Replaces TreeReader / TreeWriter from the Obj-C codebase.
struct ScanDocument: FileDocument {

    static var readableContentTypes: [UTType] { [.gpscan, .json] }
    static var writableContentTypes: [UTType] { [.gpscan] }

    var scanResult: ScanResult

    init(scanResult: ScanResult) {
        self.scanResult = scanResult
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let codable = try decoder.decode(CodableScanResult.self, from: data)
        scanResult = codable.toScanResult()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let codable = CodableScanResult(from: scanResult)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(codable)
        return FileWrapper(regularFileWithContents: data)
    }
}
