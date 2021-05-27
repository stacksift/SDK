import Foundation

struct UploadIdentifier {
    var value: String

    init(_ value: String) {
        self.value = value
    }

    init(url: URL) {
        self.value = url.lastPathComponent
    }

    var reportID: String {
        guard let part = value.split(separator: ".").first else {
            return value
        }

        return String(part)
    }

    var fileExtension: String {
        let parts = value.split(separator: ".")

        guard parts.count == 2 else {
            return ""
        }

        return String(parts[1])
    }

    var mimeType: String {
        switch fileExtension {
        case "log":
            return "application/vnd.stacksift-impact"
        case "mxdiagnostic":
            return "application/vnd.apple-mxdiagnostic"
        default:
            return "application/octet-stream"
        }
    }
}
