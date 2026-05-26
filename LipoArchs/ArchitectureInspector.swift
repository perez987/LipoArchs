import Foundation

struct InspectionResult: Equatable {
    let droppedURL: URL
    let resolvedURL: URL
    let architectures: [String]

    var labelText: String {
        architectures.joined(separator: ", ")
    }

    var alertMessage: String {
        if droppedURL.standardizedFileURL == resolvedURL.standardizedFileURL {
            return String(
                format: NSLocalizedString("%@ supports: %@.", comment: "Supported architectures"),
                locale: Locale.current,
                resolvedURL.lastPathComponent,
                labelText
            )
        }

//        return """
//        Resolved \(droppedURL.lastPathComponent) to \(resolvedURL.lastPathComponent).
//        Architectures: \(labelText).
//        """
        return String(
            format: NSLocalizedString("%@ supports %@.", comment: "Supported architectures"),
            locale: Locale.current,
            resolvedURL.lastPathComponent,
            labelText
        )
    }
}

enum ArchitectureInspectionError: LocalizedError, Equatable {
    case fileNotFound(URL)
    case unsupportedContainer(URL)
    case missingBundleExecutable(URL)
    case unsupportedFileFormat
    case fileTooSmall
    case unsupportedArchitectureSet

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return String(
                format: NSLocalizedString("The dropped item could not be found at %@.", comment: "Dropped item not found"),
                locale: Locale.current,
                url.path
            )
        case .unsupportedContainer(let url):
            return String(
                format: NSLocalizedString("Drop a Mach-O executable, library, or a .app bundle. %@ is not supported.", comment: "No executable, library or app"),
                locale: Locale.current,
                url.lastPathComponent
            )
        case .missingBundleExecutable(let url):
            return String(
                format: NSLocalizedString("Couldn't locate an executable inside %@. Drop the app's binary from Contents/MacOS instead.", comment: "No executable"),
                locale: Locale.current,
                url.lastPathComponent
            )
        case .unsupportedFileFormat:
            return (NSLocalizedString("The dropped file is not a supported Mach-O executable or library.", comment: "No Mach-O file"))
        case .fileTooSmall:
            return (NSLocalizedString("The dropped file is too small to contain a valid Mach-O header.", comment: "File too small"))
        case .unsupportedArchitectureSet:
            return (NSLocalizedString("No supported Intel/Silicon architecture information is available for this file.", comment: "Unsupported architecture set"))
        }
    }
}

enum ArchitectureInspector {
    static func inspect(url: URL) throws -> InspectionResult {
        let resolvedURL = try DroppedBinaryResolver.resolve(url: url)
        let architectures = try architectures(for: resolvedURL)

        return InspectionResult(
            droppedURL: url.standardizedFileURL,
            resolvedURL: resolvedURL.standardizedFileURL,
            architectures: architectures
        )
    }

    static func architectures(for fileURL: URL) throws -> [String] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ArchitectureInspectionError.fileNotFound(fileURL)
        }

        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        let format = try BinaryFormat.detect(in: data)

        let rawArchitectures: [String]

        switch format {
        case .thin(let byteOrder):
            rawArchitectures = [architectureName(
                cpuType: try data.readInt32(at: 4, byteOrder: byteOrder),
                cpuSubtype: try data.readInt32(at: 8, byteOrder: byteOrder)
            )]
        case .fat32(let byteOrder):
            rawArchitectures = try architecturesFromFatBinary(data: data, byteOrder: byteOrder, entrySize: 20)
        case .fat64(let byteOrder):
            rawArchitectures = try architecturesFromFatBinary(data: data, byteOrder: byteOrder, entrySize: 32)
        }

        guard let displayLabel = displayArchitectureLabel(from: rawArchitectures) else {
            throw ArchitectureInspectionError.unsupportedArchitectureSet
        }

        return [displayLabel]
    }

    private static func architecturesFromFatBinary(
        data: Data,
        byteOrder: ByteOrder,
        entrySize: Int
    ) throws -> [String] {
        let count = try Int(data.readUInt32(at: 4, byteOrder: byteOrder))
        var result: [String] = []
        var seen = Set<String>()

        for index in 0..<count {
            let offset = 8 + (index * entrySize)
            let architecture = architectureName(
                cpuType: try data.readInt32(at: offset, byteOrder: byteOrder),
                cpuSubtype: try data.readInt32(at: offset + 4, byteOrder: byteOrder)
            )

            if seen.insert(architecture).inserted {
                result.append(architecture)
            }
        }

        if result.isEmpty {
            throw ArchitectureInspectionError.unsupportedFileFormat
        }

        return result
    }

    private static func architectureName(cpuType: Int32, cpuSubtype: Int32) -> String {
        let subtype = UInt32(bitPattern: cpuSubtype) & 0x00ff_ffff

        switch cpuType {
        case 7:
            return "i386"
        case 0x0100_0007:
            return subtype == 8 ? "x86_64h" : "x86_64"
        case 12:
            switch subtype {
            case 6:
                return "armv6"
            case 9:
                return "armv7"
            case 11:
                return "armv7s"
            default:
                return "arm"
            }
        case 0x0100_000c:
            return subtype == 2 ? "arm64e" : "arm64"
        case 18:
            return "ppc"
        case 0x0100_0012:
            return "ppc64"
        default:
            return "cpu(\(cpuType), subtype: \(subtype))"
        }

        private static func displayArchitectureLabel(from architectures: [String]) -> String? {
            guard !architectures.isEmpty else {
                return nil
            }

            var hasIntel = false
            var hasSilicon = false

            for architecture in architectures {
                if ["i386", "x86_64", "x86_64h"].contains(architecture) {
                    hasIntel = true
                    continue
                }

                if ["arm64", "arm64e"].contains(architecture) {
                    hasSilicon = true
                    continue
                }

                return nil
            }

            if hasIntel && hasSilicon {
                return NSLocalizedString("Intel and Silicon", comment: "Both Intel and Silicon architectures")
            }

            if hasIntel {
                return NSLocalizedString("Intel only", comment: "Intel architecture only")
            }

            if hasSilicon {
                return NSLocalizedString("Silicon only", comment: "Silicon architecture only")
            }

            return nil
        }
    }
}

enum DroppedBinaryResolver {
    static func resolve(url: URL) throws -> URL {
        let standardizedURL = url.standardizedFileURL

        guard FileManager.default.fileExists(atPath: standardizedURL.path) else {
            throw ArchitectureInspectionError.fileNotFound(standardizedURL)
        }

        var isDirectory: ObjCBool = false
        _ = FileManager.default.fileExists(atPath: standardizedURL.path, isDirectory: &isDirectory)

        guard isDirectory.boolValue else {
            return standardizedURL
        }

        if standardizedURL.pathExtension.lowercased() == "app" {
            return try resolveAppBundle(url: standardizedURL)
        }

        throw ArchitectureInspectionError.unsupportedContainer(standardizedURL)
    }

    private static func resolveAppBundle(url: URL) throws -> URL {
        let contentsURL = url.appendingPathComponent("Contents", isDirectory: true)
        let macOSDirectoryURL = contentsURL.appendingPathComponent("MacOS", isDirectory: true)
        let infoPlistURL = contentsURL.appendingPathComponent("Info.plist")

        if
            let executableName = try executableName(from: infoPlistURL),
            !executableName.isEmpty
        {
            let executableURL = macOSDirectoryURL.appendingPathComponent(executableName)
            if FileManager.default.fileExists(atPath: executableURL.path) {
                return executableURL
            }
        }

        let candidates = try FileManager.default.contentsOfDirectory(
            at: macOSDirectoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        .filter { candidate in
            ((try? candidate.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false) == false
        }

        if candidates.count == 1, let candidate = candidates.first {
            return candidate
        }

        throw ArchitectureInspectionError.missingBundleExecutable(url)
    }

    private static func executableName(from infoPlistURL: URL) throws -> String? {
        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: infoPlistURL)
        let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
        let dictionary = propertyList as? [String: Any]
        return dictionary?["CFBundleExecutable"] as? String
    }
}

private enum BinaryFormat {
    case thin(ByteOrder)
    case fat32(ByteOrder)
    case fat64(ByteOrder)

    static func detect(in data: Data) throws -> BinaryFormat {
        guard data.count >= 8 else {
            throw ArchitectureInspectionError.fileTooSmall
        }

        let magic = Array(data.prefix(4))

        switch magic {
        case [0xce, 0xfa, 0xed, 0xfe], [0xcf, 0xfa, 0xed, 0xfe]:
            return .thin(.little)
        case [0xfe, 0xed, 0xfa, 0xce], [0xfe, 0xed, 0xfa, 0xcf]:
            return .thin(.big)
        case [0xca, 0xfe, 0xba, 0xbe]:
            return .fat32(.big)
        case [0xbe, 0xba, 0xfe, 0xca]:
            return .fat32(.little)
        case [0xca, 0xfe, 0xba, 0xbf]:
            return .fat64(.big)
        case [0xbf, 0xba, 0xfe, 0xca]:
            return .fat64(.little)
        default:
            throw ArchitectureInspectionError.unsupportedFileFormat
        }
    }
}

private enum ByteOrder {
    case little
    case big
}

private extension Data {
    func readUInt32(at offset: Int, byteOrder: ByteOrder) throws -> UInt32 {
        guard count >= offset + 4 else {
            throw ArchitectureInspectionError.fileTooSmall
        }

        let byte0 = UInt32(self[offset])
        let byte1 = UInt32(self[offset + 1])
        let byte2 = UInt32(self[offset + 2])
        let byte3 = UInt32(self[offset + 3])

        switch byteOrder {
        case .little:
            return byte0 | (byte1 << 8) | (byte2 << 16) | (byte3 << 24)
        case .big:
            return (byte0 << 24) | (byte1 << 16) | (byte2 << 8) | byte3
        }
    }

    func readInt32(at offset: Int, byteOrder: ByteOrder) throws -> Int32 {
        Int32(bitPattern: try readUInt32(at: offset, byteOrder: byteOrder))
    }
}
