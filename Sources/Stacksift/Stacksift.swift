import Foundation
import Impact
import Wells
import os.log

public class Stacksift {
    public static var shared = Stacksift()

    private var APIKey: String?
    private var endpoint: URL?
    private var useBackgroundUploads: Bool = true

    private let logger: OSLog

    init() {
        self.logger = OSLog(subsystem: "io.stacksift", category: "Reporter")

    }

    private lazy var reporter: WellsReporter = {
        let reportingURL = Stacksift.defaultDirectory

        let backgroundIdentifier = useBackgroundUploads ? WellsUploader.defaultBackgroundIdentifier : nil

        let reporter = WellsReporter(baseURL: reportingURL, backgroundIdentifier: backgroundIdentifier)

        reporter.locationProvider = IdentifierExtensionLocationProvider(baseURL: reportingURL, fileExtension: "log")

        return reporter
    }()

    private var reportDirectoryURL: URL {
        return reporter.baseURL
    }

    /// Indicates if the SDK was configured to send uploads using a background session
    ///
    /// By default, the SDK will use an URLSession background configuration for uploading
    /// reports. This is optimal from a reliablity and performance perspective. However,
    /// it can be furstrating to wait for the OS to decide to send a report while testing.
    public var usingBackgroundUploads: Bool {
        return reporter.usingBackgroundUploads
    }

    public static func start(APIKey: String, useBackgroundUploads: Bool = true) {
        shared.start(APIKey: APIKey, useBackgroundUploads: useBackgroundUploads)
    }

    public func start(APIKey: String, useBackgroundUploads: Bool = true) {
        self.APIKey = APIKey
        self.useBackgroundUploads = useBackgroundUploads

        if useBackgroundUploads == false {
            os_log("using non-background sessions for uploading reports", log: self.logger, type: .info)
        }
        
        let existingURLs = existingLogURLs()

        let id = UUID()
        let idString = id.uuidString.replacingOccurrences(of: "-", with: "").lowercased()

        let logURL = reportDirectoryURL.appendingPathComponent(idString, isDirectory: false).appendingPathExtension("log")

        ImpactMonitor.shared.organizationIdentifier = APIKey
        ImpactMonitor.shared.start(with: logURL, identifier: id)

        submitExistingLogs(with: existingURLs)
    }

    private func deleteAllLogs(with urls: [URL]) {
        if urls.count > 0 {
            os_log("removing all logs", log: self.logger, type: .info)
        }

        for url in urls {
            removeLog(at: url)
        }
    }

    private func existingLogURLs() -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(at: reportDirectoryURL, includingPropertiesForKeys: nil, options: [])
        } catch {
            os_log("failed to get crash directory contents", log: self.logger, type: .error)
        }

        return []
    }

    private func makeURLRequest(identifier: String) throws -> URLRequest {
        let platform = ImpactMonitor.platform as String
        guard let orgIdentifier = APIKey else {
            throw NSError(domain: "StacksiftError", code: 1)
        }
        guard let url = URL(string: "https://reports.stacksift.io/v1/reports") else {
            throw NSError(domain: "StacksiftError", code: 2)
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10.0)

        request.httpMethod = "PUT"

        request.addValue(identifier, forHTTPHeaderField: "stacksift-report-id")
        request.addValue(platform, forHTTPHeaderField: "stacksift-platform")
        request.addValue("application/vnd.stacksift-impact", forHTTPHeaderField: "Content-Type")
        request.addValue(orgIdentifier, forHTTPHeaderField: "stacksift-api-key")

        return request
    }

    private func submitExistingLogs(with URLs: [URL]) {
        for url in URLs {
            if !shouldSubmitLog(at: url) {
                os_log("uninteresting log: %{public}@", log: self.logger, type: .info, url.path)

                removeLog(at: url)
                continue
            }

            let reportId = reportIdentifier(from: url)

            os_log("submitting log: %{public}@", log: self.logger, type: .info, url.path)

            do {
                let request = try makeURLRequest(identifier: reportId)
                try reporter.submit(fileURL: url, identifier: reportId, uploadRequest: request)
            } catch {
                os_log("failed to submit log", log: self.logger, type: .fault)
                removeLog(at: url)
            }
        }
    }

    private func reportIdentifier(from url: URL) -> String {
        return url.deletingPathExtension().lastPathComponent
    }

    private func shouldSubmitLog(at url: URL) -> Bool {
        guard let contents = try? String(contentsOf: url) else {
            return false
        }

        if contents.contains("[Thread:Frame]") {
            return true
        }

        if contents.contains("[Thread:Crashed]") {
            return true
        }

        if contents.contains("[Thread:State]") {
            return true
        }

        if contents.contains("[Exception]") {
            return true
        }

        return false
    }

    private func removeLog(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            os_log("failed to remove log at %{public}@ %{public}@", log: self.logger, type: .error, url.path, error.localizedDescription)
        }
    }
}

extension Stacksift {
    public static func testCrash() -> Never {
        preconditionFailure()
    }

    public static func testException() {
        let name = NSExceptionName(rawValue: "StacksiftTestException")
        let exc = NSException(name: name,
                              reason: "This is a test exception from the Stacksift SDK",
                              userInfo: ["Key":"Value"])

        exc.raise()
    }
}

extension Stacksift {
    public static var defaultDirectory: URL {
        guard let url = FileManager.cachesURL?.appendingPathComponent("Impact") else {
            return WellsReporter.defaultDirectory
        }

        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            return WellsReporter.defaultDirectory
        }

        return url
    }
}
