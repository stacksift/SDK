import Foundation
import Impact
import Wells
import os.log

public class Stacksift: NSObject {

    @objc(StacksiftConfiguration)
    public class Configuration: NSObject {
        @objc public var APIKey: String

        /// URL value used for relaying reports
        ///
        /// Changing this value is useful for redirecting submissions away from
        /// the default of "https://reports.stacksift.io/v1/reports". A malformed
        /// url or otherwise unreachable URL will result in loss of reports.
        ///
        /// - Important: When used for proxying, all HTTP headers **must** be preserved.
        @objc public var endpoint: String = "https://reports.stacksift.io/v1/reports"

        @objc public var useBackgroundUploads: Bool = true

        @objc public var monitor = Monitor.metricKitAndInProcess

        /// Identifier used for counting unique affected devices
        ///
        /// This value is used for counting the number of unique devices affected by an issue.
        /// The supplied value is not indexed, and not necessarily recoverable from raw
        /// report data. You should consider it useful exclusively for enabling the unique counting
        /// features.
        ///
        /// - Important: This value is not persisted. It is the responsibility of the client to
        /// store and set it on every launch.
        @objc public var installIdentifier: String?

        @objc public var logger: OSLog = OSLog(subsystem: "io.stacksift", category: "Reporter")

        @objc public init(APIKey: String) {
            self.APIKey = APIKey
        }
    }

    @objc public enum Monitor: Int {
        case inProcessOnly
        case metricKitOnly
        case metricKitWithInProcessFallback
        case metricKitAndInProcess

        public var impactEnabled: Bool {
            switch self {
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

        public var metricKitEnabled: Bool {
            switch self {
            case .inProcessOnly:
                return false
            case .metricKitWithInProcessFallback, .metricKitOnly, .metricKitAndInProcess:
                return metricKitAvailable
            }
        }
    }

    @objc public static let shared = Stacksift()

    public private(set) var configuration: Configuration

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
    @objc public var installIdentifier: String? {
        get { configuration.installIdentifier }
        set { configuration.installIdentifier = newValue }
    }

    private var logger: OSLog {
        get { configuration.logger }
    }

    private var useBackgroundUploads: Bool {
        get { configuration.useBackgroundUploads }
    }

    public var APIKey: String {
        get { configuration.APIKey }
    }

    override init() {
        self.configuration = Configuration(APIKey: "")
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

    @objc public static func start(configuration: Configuration) {
        shared.start(configuration: configuration)
    }

    @objc public func start(configuration: Configuration) {
        self.configuration = configuration

        if useBackgroundUploads == false {
            os_log("using non-background sessions for uploading reports", log: logger, type: .info)
        }

        let existingURLs = existingLogURLs()
        let monitor = configuration.monitor

        if monitor.impactEnabled {
            os_log("using in-process monitoring", log: logger, type: .info)

            let id = UUID()
            let idString = id.lowerAlphaOnly

            let logURL = reportDirectoryURL.appendingPathComponent(idString, isDirectory: false).appendingPathExtension("log")

            ImpactMonitor.shared.organizationIdentifier = APIKey
            ImpactMonitor.shared.installIdentifier = installIdentifier
            ImpactMonitor.shared.start(with: logURL, identifier: id)
        }

        if monitor.metricKitEnabled {
            os_log("using MetricKit monitoring", log: logger, type: .info)

            metricKitSubscriber.onReceive = { [unowned self] (reps) in
                self.handleMetricKitPayloadData(reps)
            }
        }

        submitExistingLogs(with: existingURLs)

    }

    /// Setup the Stacksift system
    ///
    /// This method initializes the SDK and begins monitoring for crashes, as well as
    /// relaying previously-found crashes to the Stacksift service.
    ///
    /// - Important
    /// In-process monitoring systems are **not** interoperable. Be very careful with
    /// the *monitor* parameter if you are using more than one service.
    ///
    /// - Parameters:
    ///   - APIKey: The Stacksift-issued key used to identify your organization
    ///   - useBackgroundUploads: Controls the use of URLSession background uploads. This
    ///   can be problematic for testing. Defaults to true.
    ///   - monitor: The type of crash monitoring for the process. Defaults to metricKitAndInProcess.
    @objc public static func start(APIKey: String, useBackgroundUploads: Bool = true, monitor: Monitor = .metricKitAndInProcess) {
        shared.start(APIKey: APIKey,
                     useBackgroundUploads: useBackgroundUploads,
                     monitor: monitor)
    }

    /// Setup the Stacksift system
    ///
    /// This method initializes the SDK and begins monitoring for crashes, as well as
    /// relaying previously-found crashes to the Stacksift service.
    ///
    /// - Important
    /// In-process monitoring systems are **not** interoperable. Be very careful with
    /// the *monitor* parameter if you are using more than one service.
    ///
    /// - Parameters:
    ///   - APIKey: The Stacksift-issued key used to identify your organization
    ///   - useBackgroundUploads: Controls the use of URLSession background uploads. This
    ///   can be problematic for testing. Defaults to true.
    ///   - monitor: The type of crash monitoring for the process. Defaults to metricKitAndInProcess.
    @objc public func start(APIKey: String, useBackgroundUploads: Bool = true, monitor: Monitor = .metricKitAndInProcess) {
        let config = Configuration(APIKey: APIKey)

        config.useBackgroundUploads = useBackgroundUploads
        config.monitor = monitor

        start(configuration: config)
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
        let APIKey = configuration.APIKey

        guard APIKey.isEmpty == false else {
            throw NSError(domain: "StacksiftError", code: 1)
        }

        guard let url = URL(string: configuration.endpoint) else {
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
