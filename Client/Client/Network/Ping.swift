//
//  TraceRoute.swift
//  TraceRoute
//
//  Created by Pasin Suriyentrakorn on 3/4/22.
//

import Foundation
import UIKit

public class TraceRoute : NSObject {
    public typealias TraceLog = (String) -> Void
    
    struct PacketResult {
        var address: Data
        var interval: TimeInterval
    }
    
    struct TraceResult {
        let ttl: Int32
        var packets: [PacketResult] = []
    }
    
    let MAX_TTL = 64
    let NUM_TRACE_MESGS: Int32 = 3
    let TIMEOUT_SECS: TimeInterval = 5.0

    let host: String
    let log: TraceLog
    var ping: SimplePing!
    
    // Only access from the main thread
    var finished = false
    var ttl: Int32 = 0
    var startTime: Date?
    var currentTraceResult: TraceResult?
    var timer: Timer?
    
    public init(host: String, log: @escaping TraceLog) {
        self.host = host
        self.log = log
    }
    
    public func start() {
        if ping == nil {
            ping = SimplePing(hostName: self.host)
            ping.delegate = self
        }
        
        // SimplePing only works on runloop and trace() could be called from a dispatch queue
        // which doesn't have runloop. Make sure to dispatch to the main queue to use the main
        // runloop.
        DispatchQueue.main.async {
            self.finished = false
            self.ttl = 0
            self.ping.stop()
            self.ping.start()
        }
        wait()
    }
    
    public func stop() {
        DispatchQueue.main.async {
            self.finish()
        }
    }
    
    public func finish() {
        resetTimeoutTimer()
        self.ping.stop()
        self.finished = true
    }
    
    func wait() {
        while true {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
            var done = false
            DispatchQueue.main.sync { done = finished }
            if done { break }
        }
    }
    
    func sendNextTraceRoute() -> Bool {
        ttl = ttl + 1
        if ttl > MAX_TTL {
            return false
        }
        
        startTimeoutTimer();
        
        currentTraceResult = TraceResult(ttl:ttl)
        
        startTime = Date()
        
        ping.sendTraceRoute(withTTL: ttl, numMessages: NUM_TRACE_MESGS)
        
        return true
    }
    
    func didReceivedResponsePacket(data: Data, address: Data, completed: Bool) {
        let interval = Date().timeIntervalSince(self.startTime!)
        let result = PacketResult(address: address, interval: interval)
        currentTraceResult!.packets.append(result)
        
        if currentTraceResult!.packets.count == NUM_TRACE_MESGS {
            logAndResetCurrentResult()
            if (completed || !sendNextTraceRoute()) {
                finish()
            }
        }
    }
    
    @objc func timeout() {
        // Hacky way of cancelling the pending requests:
        ping.delegate = nil
        ping.stop()
        
        logAndResetCurrentResult()
        
        ping = SimplePing(hostName: self.host)
        ping.delegate = self
        ping.start()
    }
    
    func logAndResetCurrentResult() {
        guard let result = currentTraceResult else {
            return
        }
        
        var hosts: [String] = []
        for packet in result.packets {
            let ipaddr = getHostNameInfo(address: packet.address, format: .IP_ADDRESS)
            let hostname = getHostNameInfo(address: packet.address, format: .HOSTNAME) ?? ipaddr
            if let name = hostname {
                hosts.append("\(name) (\(ipaddr ?? "?"))")
            } else {
                hosts.append("?")
            }
        }
        
        let hop = result.ttl < 10 ? " \(result.ttl)" : "\(result.ttl)"
        
        let singleLine = hosts.count < 2 || hosts.allSatisfy({ $0 == hosts.first })
        if singleLine {
            var intervals = ""
            for i in 0..<Int(NUM_TRACE_MESGS) {
                if i < result.packets.count {
                    intervals = intervals + String(format: "%.2f ms  ", result.packets[i].interval * 1000)
                } else {
                    intervals = intervals + "*  "
                }
            }
            
            if hosts.count > 0 {
                self.log(" \(hop)  \(hosts[0])  \(intervals)")
            } else {
                self.log(" \(hop)  \(intervals)")
            }
        } else {
            for i in 0..<Int(NUM_TRACE_MESGS) {
                var host = ""
                var interval = ""
                if i < result.packets.count {
                    host = hosts[i] // hosts and packets have the same number of items
                    interval = String(format: "%.2f ms  ", result.packets[i].interval * 1000)
                } else {
                    interval = "*  "
                }
                
                let hopColumn = i == 0 ? hop : "  "
                if !host.isEmpty {
                    self.log(" \(hopColumn)  \(host)  \(interval)")
                } else {
                    self.log(" \(hopColumn)  \(interval)")
                }
            }
        }
    }
    
    func resetTimeoutTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    func startTimeoutTimer() {
        resetTimeoutTimer()
        timer = Timer.scheduledTimer(timeInterval: TIMEOUT_SECS,
                                     target: self,
                                     selector: #selector(timeout),
                                     userInfo: nil,
                                     repeats: false)
    }
    
    enum HostNameInfoFormat { case HOSTNAME, IP_ADDRESS }
    
    func getHostNameInfo(address: Data, format: HostNameInfoFormat) -> String? {
        let addr = address as NSData;
        var host = [Int8](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(addr.bytes.assumingMemoryBound(to: sockaddr.self),
                       socklen_t(addr.length),
                       &host,
                       socklen_t(host.count),
                       nil,
                       0,
                       format == .HOSTNAME ? NI_NAMEREQD : NI_NUMERICHOST) == 0 {
            return String(cString: host)
        }
        return nil
    }
}

extension TraceRoute: SimplePingDelegate {
    public func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data) {
        if ttl == 0 {
            let ipaddr = getHostNameInfo(address: address, format: .IP_ADDRESS) ?? "?"
            self.log("traceroute to \(pinger.hostName) (\(ipaddr)), \(MAX_TTL) hops max")
        }
        if !self.sendNextTraceRoute() {
            finish()
        }
    }
    
    public func simplePing(_ pinger: SimplePing, didFailWithError error: Error) {
        self.log("TraceRoute Error : \((error as NSError).code)")
        finish()
    }
    
    public func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {
        // Ignored
    }
    
    public func simplePing(_ pinger: SimplePing, didFailToSendPacket packet: Data, sequenceNumber: UInt16, error: Error) {
        // Ignored, the timeout logic will log the response time as *
    }
    
    public func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16, address: Data) {
        self.didReceivedResponsePacket(data: packet, address: address, completed: true)
    }
    
    public func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data, address: Data) {
        self.didReceivedResponsePacket(data: packet, address: address, completed: false)
    }
}
