//
//  UUID+Pretty.swift
//  SDK
//
//  Created by Matthew Massicotte on 2021-05-27.
//

import Foundation

extension UUID {
    var lowerAlphaOnly: String {
        return uuidString.replacingOccurrences(of: "-", with: "").lowercased()
    }
}
