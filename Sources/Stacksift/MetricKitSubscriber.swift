//
//  StacksiftMetricKitSubscriber.swift
//  SDK
//
//  Created by Matthew Massicotte on 2021-05-27.
//

import Foundation
import os.log
#if os(iOS)
import MetricKit
#endif

class MetricKitSubscriber: NSObject {
    private let logger: OSLog
    
    var onReceive: (([Data]) -> Void)?

    override init() {
        self.logger = OSLog(subsystem: "io.stacksift", category: "StacksiftMetricKitSubscriber")

        super.init()

        guard MetricKitSubscriber.metricKitAvailable else {
            os_log("MetricKit is unavailable", log: self.logger, type: .error)
            return
        }

        #if os(iOS)
        if #available(iOS 14.0, *) {
            MXMetricManager.shared.add(self)
        }
        #endif
    }

    static var metricKitAvailable: Bool {
        if #available(iOS 14.0, *) {
            return true
        } else {
            return false
        }
    }
}

#if os(iOS)
@available(iOS 13.0, *)
extension MetricKitSubscriber: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
    }

    @available(iOS 14.0, *)
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        os_log("received payloads", log: self.logger, type: .info)

        let realPayloads = payloads.filter { payload in
            if payload.isSimulated {
                os_log("filtering simulated payload", log: self.logger, type: .info)
                return false
            }

            return true
        }

        let reps = realPayloads.map { $0.jsonRepresentation() }
        guard reps.isEmpty == false else { return }

        onReceive?(reps)
    }
}

@available(iOS 14.0, *)
extension MXDiagnosticPayload {
    struct Frame: Codable {
        let binaryUUID: String
        let binaryName: String

        var isSimulated: Bool {
            return binaryName == "testBinaryName"
        }
    }

    struct Stack: Codable {
        let callStackRootFrames: [Frame]

        var isSimulated: Bool {
            return callStackRootFrames.first?.isSimulated == true
        }
    }

    struct StackTree: Codable {
        let callStacks: [Stack]

        var isSimulated: Bool {
            return callStacks.first?.isSimulated == true
        }
    }

    struct CrashDiagnostic: Codable {
        let callStackTree: StackTree

        var isSimulated: Bool {
            return callStackTree.isSimulated
        }
    }

    var isSimulated: Bool {
        guard let crashPayload = crashDiagnostics?.first else {
            return false
        }

        let jsonData = crashPayload.jsonRepresentation()

        do {
            let diagnostic = try JSONDecoder().decode(CrashDiagnostic.self, from: jsonData)

            return diagnostic.isSimulated
        } catch {
            print("error: \(error)")
            return false
        }
    }
}
#endif
