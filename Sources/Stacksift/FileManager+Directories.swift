import Foundation

extension FileManager {
    static var applicationSupportURL: URL? {
        return bundleIdScopedURL(for: .applicationSupportDirectory)
    }

    static var cachesURL: URL? {
        return bundleIdScopedURL(for: .cachesDirectory)
    }
}

extension FileManager {
    static func bundleIdScopedURL(for dir: FileManager.SearchPathDirectory, bundleId: String) -> URL? {
        guard let url = FileManager.default.urls(for: dir, in: .userDomainMask).first else {
            return nil
        }

        let scopedURL = url.appendingPathComponent(bundleId)

        try? FileManager.default.createDirectory(at: scopedURL, withIntermediateDirectories: true, attributes: nil)

        return scopedURL
    }

    static func bundleIdScopedURL(for dir: FileManager.SearchPathDirectory) -> URL? {
        guard let bundleId = Bundle.main.bundleIdentifier else {
            return nil
        }

        return bundleIdScopedURL(for: dir, bundleId: bundleId)
    }
}

extension FileManager {
    func directoryExists(at url: URL) -> Bool {
        var isDir: ObjCBool = false

        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
            return false
        }

        return isDir.boolValue
    }
}
