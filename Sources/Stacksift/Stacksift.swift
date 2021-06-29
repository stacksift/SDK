import Foundation
import Impact
import Wells
import os.log

public class Stacksift: NSObject {
    @objc public enum Monitor: Int {
        case inProcessOnly
        case metricKitOnly
        case metricKitWithInProcessFallback
        case metricKitAndInProcess
    }

    @objc public static var shared = Stacksift()

    private var APIKey: String?
    private var endpoint: URL?
    private var useBackgroundUploads: Bool = true
    private var monitorType = Monitor.inProcessOnly

    /// Identifier used for counting unique affected devices
    ///
    /// This value is used for counting the number of unique devices affected by an issue.
    /// The supplied value is not indexed, and not necessarily recoverable from raw
    /// report data. You should consider it useful exclusively for enabling the unique counting
    /// features.
    ///
    /// - Important
    /// This value is not persisted. It is the responsibility of the client to
    /// store and set it on every launch.
    @objc public var installIdentifier: String?

    private let logger: OSLog

    override init() {
        self.logger = OSLog(subsystem: "io.stacksift", category: "Reporter")
    }

    private lazy var reporter: WellsReporter = {
        let reportingURL = Stacksift.defaultDirectory

        let backgroundIdentifier = useBackgroundUploads ? WellsUploader.defaultBackgroundIdentifier : nil

        let reporter = WellsReporter(baseURL: reportingURL, backgroundIdentifier: backgroundIdentifier)

        reporter.locationProvider = FilenameIdentifierLocationProvider(baseURL: reportingURL)

        return reporter
    }()

    private lazy var metricKitSubscriber: MetricKitSubscriber = {
        return MetricKitSubscriber()
    }()

    private var reportDirectoryURL: URL {
        return reporter.baseURL
    }

    /// Indicates if the SDK was configured to send uploads using a background session
    ///
    /// By default, the SDK will use an URLSession background configuration for uploading
    /// reports. This is optimal from a reliablity and performance perspective. However,
    /// it can be furstrating to wait for the OS to decide to send a report while testing.
    @objc public var usingBackgroundUploads: Bool {
        return reporter.usingBackgroundUploads
    }

    @objc public static func start(APIKey: String, useBackgroundUploads: Bool = true, monitor: Monitor = .inProcessOnly) {
        shared.start(APIKey: APIKey,
                     useBackgroundUploads: useBackgroundUploads,
                     monitor: monitor)
    }

    @objc public func start(APIKey: String, useBackgroundUploads: Bool = true, monitor: Monitor = .inProcessOnly) {
        self.APIKey = APIKey
        self.useBackgroundUploads = useBackgroundUploads
        self.monitorType = monitor

        if useBackgroundUploads == false {
            os_log("using non-background sessions for uploading reports", log: self.logger, type: .info)
        }
        
        let existingURLs = existingLogURLs()

        if impactEnabled {
            os_log("using in-process monitoring", log: self.logger, type: .info)

            let id = UUID()
            let idString = id.lowerAlphaOnly

            let logURL = reportDirectoryURL.appendingPathComponent(idString, isDirectory: false).appendingPathExtension("log")

            ImpactMonitor.shared.organizationIdentifier = APIKey
            ImpactMonitor.shared.installIdentifier = installIdentifier
            ImpactMonitor.shared.start(with: logURL, identifier: id)
        }

        if metricKitEnabled {
            os_log("using MetricKit monitoring", log: self.logger, type: .info)

            metricKitSubscriber.onReceive = { [unowned self] (reps) in
                self.handleMetricKitPayloadData(reps)
            }
        }

        submitExistingLogs(with: existingURLs)
    }

    private func handleMetricKitPayloadData(_ reps: [Data]) {
        let urls = reps.compactMap { rep -> URL? in
            let idString = UUID().lowerAlphaOnly

            let logURL = reportDirectoryURL.appendingPathComponent(idString, isDirectory: false).appendingPathExtension("mxdiagnostic")

            do {
                try rep.write(to: logURL)
            } catch {
                os_log("failed to save diagnostic payload data", log: self.logger, type: .error)
                return nil
            }

            return logURL
        }

        submitExistingLogs(with: urls)
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

    private func makeURLRequest(identifier: UploadIdentifier) throws -> URLRequest {
        let platform = ImpactMonitor.platform as String
        guard let APIKey = APIKey else {
            throw NSError(domain: "StacksiftError", code: 1)
        }
        guard let url = URL(string: "https://reports.stacksift.io/v1/reports") else {
            throw NSError(domain: "StacksiftError", code: 2)
        }
        guard let bundleId = Bundle.main.bundleIdentifier else {
            throw NSError(domain: "StacksiftError", code: 3)
        }

        let reportID = identifier.reportID
        let mimeType = identifier.mimeType

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10.0)

        request.httpMethod = "PUT"

        request.addValue(reportID, forHTTPHeaderField: "stacksift-report-id")
        request.addValue(platform, forHTTPHeaderField: "stacksift-platform")
        request.addValue(mimeType, forHTTPHeaderField: "Content-Type")
        request.addValue(APIKey, forHTTPHeaderField: "stacksift-api-key")
        request.addValue(bundleId, forHTTPHeaderField: "stacksift-app-identifier")

        if let installId = installIdentifier {
            request.addValue(installId, forHTTPHeaderField: "stacksift-install-identifier")
        }

        return request
    }

    private func submitReport(at url: URL) {
        let identifier = UploadIdentifier(url: url)

        os_log("submitting report: %{public}@", log: self.logger, type: .info, url.path)

        do {
            let request = try makeURLRequest(identifier: identifier)
            try reporter.submit(fileURL: url, identifier: identifier.value, uploadRequest: request)
        } catch {
            os_log("failed to submit report", log: self.logger, type: .fault)
            removeLog(at: url)
        }
    }

    private func submitExistingLogs(with URLs: [URL]) {
        for url in URLs {
            if !shouldSubmitLog(at: url) {
                os_log("uninteresting report: %{public}@", log: self.logger, type: .info, url.path)

                removeLog(at: url)
                continue
            }

            submitReport(at: url)
        }
    }

    private func shouldSubmitLog(at url: URL) -> Bool {
        if url.pathExtension == "mxdiagnostic" {
            return true
        }

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
    private var impactEnabled: Bool {
        switch monitorType {
        case .inProcessOnly, .metricKitAndInProcess:
            return true
        case .metricKitWithInProcessFallback:
            return metricKitAvailable == false
        case .metricKitOnly:
            return false
        }
    }

    private var metricKitAvailable: Bool {
        return MetricKitSubscriber.metricKitAvailable
    }
    
    private var metricKitEnabled: Bool {
        switch monitorType {
        case .inProcessOnly:
            return false
        case .metricKitWithInProcessFallback, .metricKitOnly, .metricKitAndInProcess:
            return metricKitAvailable
        }
    }
}

extension Stacksift {
    @objc public static func testCrash() -> Never {
        preconditionFailure()
    }

    @objc public static func testException() {
        let name = NSExceptionName(rawValue: "StacksiftTestException")
        let exc = NSException(name: name,
                              reason: "This is a test exception from the Stacksift SDK",
                              userInfo: ["Key":"Value"])

        exc.raise()
    }
}

extension Stacksift {
    @objc public static var defaultDirectory: URL {
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
