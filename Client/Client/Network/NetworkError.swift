//
//  NetworkError.swift
//  Client
//
//  Created by Pasin Suriyentrakorn on 3/5/22.
//

import Foundation

public class NetworkError {

    public static func getErrorMessage(error: Error) -> String {
        let nserror = error as NSError
        if nserror.domain == kCFErrorDomainCFNetwork as String {
            var code = Int32(nserror.code)
            if nserror.code == CFNetworkErrors.cfHostErrorUnknown.rawValue {
                if let errNo = nserror.userInfo[kCFGetAddrInfoFailureKey as String] as? Int32 {
                    if errNo == HOST_NOT_FOUND || errNo == EAI_NONAME {
                        code = CFNetworkErrors.cfHostErrorHostNotFound.rawValue
                    }
                } else {
                    code = CFNetworkErrors.cfurlErrorDNSLookupFailed.rawValue
                }
            }
            
            if let networkError = CFNetworkErrors(rawValue: code) {
                switch networkError {
                case .cfErrorHTTPConnectionLost:
                    return "Network Unreachable"
                case .cfurlErrorCannotConnectToHost:
                    return "Connection Refused"
                case .cfurlErrorNetworkConnectionLost:
                    return "Connection Refused"
                case .cfurlErrorDNSLookupFailed:
                    return "DSN Error"
                case .cfHostErrorHostNotFound:
                    return "Unknown Hostname"
                case .cfurlErrorTimedOut:
                    return "Timed Out"
                default:
                    return "Network Error (code = \(networkError.rawValue))"
                }
            }
            return "Unknown Network Error (code = \(code))"
        }
        
        return nserror.localizedFailureReason ?? nserror.localizedDescription
    }
    
    private init() { }
    
}
