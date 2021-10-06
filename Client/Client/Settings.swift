//
//  Settings.swift
//  Client
//
//  Created by Wayne Carter on 8/5/21.
//

import Foundation

class Settings {
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
    
    static var usePostForSetOperations: Bool {
        let key = "use_post_for_set_operations"
        let userDefaults = UserDefaults.standard
        userDefaults.register(
            defaults: [
                key: true
            ]
        )
        
        return userDefaults.bool(forKey: key)
    }
    
    private static func trimmed(_ string: String?) -> String? {
        if let string = string?.trimmingCharacters(in: .whitespacesAndNewlines), string.count > 0 {
            return string
        } else {
            return nil
        }
    }
}
