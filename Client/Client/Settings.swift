//
//  Settings.swift
//  Client
//
//  Created by Wayne Carter on 8/5/21.
//

import Foundation

class Settings {
    static let testIterations: Int = 100
    static let payloadSize = 1000
    
    static var cloudTargetName: String? {
        trimmed(UserDefaults.standard.string(forKey: "cloud_target_name"))
    }
    
    static var cloudTargetHost: String? {
        trimmed(UserDefaults.standard.string(forKey: "cloud_target_host"))
    }
    
    static var edgeTargetName: String? {
        trimmed(UserDefaults.standard.string(forKey: "edge_target_name"))
    }
    
    static var edgeTargetHost: String? {
        trimmed(UserDefaults.standard.string(forKey: "edge_target_host"))
    }
    
    private static func trimmed(_ string: String?) -> String? {
        if let string = string?.trimmingCharacters(in: .whitespacesAndNewlines), string.count > 0 {
            return string
        } else {
            return nil
        }
    }
}
