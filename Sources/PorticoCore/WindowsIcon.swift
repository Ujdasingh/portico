import Foundation

/// Reads embedded RT_GROUP_ICON / RT_ICON resources without executing Windows code.
public enum WindowsIcon {
    public static func load(executable: URL) -> Data? {
        guard let size = try? executable.resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size > 0, size <= 512 * 1024 * 1024,
              let data = try? Data(contentsOf: executable, options: .mappedIfSafe) else { return nil }
        return try? extract(from: data)
    }
    public static func extract(from data: Data) throws -> Data {
        let reader = Reader(data: data)
        guard try reader.number(0, 2) == 0x5a4d else { throw Invalid.image }
        let pe = try reader.number(0x3c, 4)
        guard try reader.number(pe, 4) == 0x4550 else { throw Invalid.image }
        let count = try reader.number(pe + 6, 2), optionalSize = try reader.number(pe + 20, 2)
        let optional = pe + 24, magic = try reader.number(optional, 2)
        guard count > 0, count <= 96, magic == 0x10b || magic == 0x20b else { throw Invalid.image }
        let directory = magic == 0x20b ? 112 : 96
        guard optionalSize >= directory + 24 else { throw Invalid.image }
        let sections = optional + optionalSize
        func offset(_ rva: Int, length: Int) throws -> Int {
            for i in 0..<count {
                let section = sections + i * 40
                let start = try reader.number(section + 12, 4), size = try reader.number(section + 16, 4)
                if rva >= start, rva - start <= size, length <= size - (rva - start) {
                    let position = try reader.number(section + 20, 4) + rva - start
                    _ = try reader.bytes(position, length)
                    return position
                }
            }
            throw Invalid.image
        }
        let resourceRVA = try reader.number(optional + directory + 16, 4)
        let resourceSize = try reader.number(optional + directory + 20, 4)
        let root = try offset(resourceRVA, length: resourceSize)
        func resourceBytes(_ relative: Int, _ length: Int) throws -> Data {
            guard relative >= 0, length >= 0, relative <= resourceSize, length <= resourceSize - relative else { throw Invalid.image }
            return try reader.bytes(root + relative, length)
        }
        func entries(_ directoryOffset: Int) throws -> [(Int, Int)] {
            _ = try resourceBytes(directoryOffset, 16)
            let n = try reader.number(root + directoryOffset + 12, 2) + reader.number(root + directoryOffset + 14, 2)
            guard n <= 4096 else { throw Invalid.image }
            _ = try resourceBytes(directoryOffset + 16, n * 8)
            return try (0..<n).map { i in
                let base = root + directoryOffset + 16 + i * 8
                return (try reader.number(base, 4), try reader.number(base + 4, 4))
            }
        }
        func directoryChild(_ node: Int) throws -> Int {
            guard node & 0x80000000 != 0 else { throw Invalid.image }
            return node & 0x7fffffff
        }
        func payload(_ node: Int) throws -> Data {
            guard node & 0x80000000 == 0 else { throw Invalid.image }
            _ = try resourceBytes(node, 16)
            let rva = try reader.number(root + node, 4), size = try reader.number(root + node + 4, 4)
            guard size > 0, size <= 16 * 1024 * 1024 else { throw Invalid.image }
            return try reader.bytes(offset(rva, length: size), size)
        }
        let types = try entries(0)
        guard let groups = types.first(where: { $0.0 == 14 }), let icons = types.first(where: { $0.0 == 3 }),
              let group = try entries(directoryChild(groups.1)).first,
              let language = try entries(directoryChild(group.1)).first else { throw Invalid.image }
        let groupData = try payload(language.1), groupReader = Reader(data: groupData)
        let n = try groupReader.number(4, 2)
        guard try groupReader.number(2, 2) == 1, n > 0, n <= 256 else { throw Invalid.image }
        let iconEntries = try entries(directoryChild(icons.1))
        var result = Data([0, 0, 1, 0, UInt8(n & 255), UInt8(n >> 8)]), images = Data()
        for i in 0..<n {
            let base = 6 + i * 14, id = try groupReader.number(base + 12, 2)
            guard let icon = iconEntries.first(where: { $0.0 == id }),
                  let language = try entries(directoryChild(icon.1)).first else { throw Invalid.image }
            let image = try payload(language.1)
            guard images.count + image.count <= 32 * 1024 * 1024 else { throw Invalid.image }
            result.append(try groupReader.bytes(base, 8))
            for value in [image.count, 6 + n * 16 + images.count] {
                for shift in stride(from: 0, through: 24, by: 8) { result.append(UInt8((value >> shift) & 255)) }
            }
            images.append(image)
        }
        result.append(images)
        return result
    }
    private enum Invalid: Error { case image }
    private struct Reader {
        let data: Data
        func bytes(_ offset: Int, _ length: Int) throws -> Data {
            guard offset >= 0, length >= 0, offset <= data.count, length <= data.count - offset else { throw Invalid.image }
            return data.subdata(in: offset..<(offset + length))
        }
        func number(_ offset: Int, _ length: Int) throws -> Int {
            let bytes = try bytes(offset, length)
            return bytes.enumerated().reduce(0) { $0 | (Int($1.element) << ($1.offset * 8)) }
        }
    }
}
