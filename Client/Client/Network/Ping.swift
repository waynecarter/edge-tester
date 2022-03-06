//
//  TraceRoute.swift
//  Client
//
//  Created by Pasin Suriyentrakorn on 3/4/22.
//

import Foundation
import UIKit

public class Ping : NSObject {
    public typealias TraceLog = (String) -> Void
    
    struct Packet {
        var sequence: UInt16
        var startTime: Date
        var interval: TimeInterval?
        var error: Error?
    }
    
    let PING_INTERVAL: TimeInterval = 1.0
    let PING_TIMEOUT: TimeInterval = 2.0
    let MAX_PINGS = 10

    let host: String
    let log: TraceLog
    
    // Only access from the main thread
    var pinger: SimplePing!
    
    var pingCount = 0
    var finished = false
    
    var sendTimer: Timer?
    var lastPingTime: Date?
    
    var sentPackets: [UInt16:Packet] = [:]
    
    public init(host: String, log: @escaping TraceLog) {
        self.host = host
        self.log = log
    }
    
    public func start() {
        // SimplePing only works on runloop and trace() could be called from a dispatch queue
        // which doesn't have runloop. Make sure to dispatch to the main queue to use the main
        // runloop.
        DispatchQueue.main.async {
            self.finished = false
            self.pingCount = 0
            self.startSimplePing()
        }
        wait()
    }
    
    public func stop() {
        DispatchQueue.main.async {
            self.finish()
        }
    }
    
    /// Start or re-start SimplePing
    private func startSimplePing() {
        if pinger != nil {
            pinger.delegate = nil
            pinger.stop()
        }
        
        pinger = SimplePing(hostName: self.host)
        pinger.delegate = self
        pinger.start()
    }
    
    private func finish() {
        resetSendTimer()
        pinger.stop()
        logSummary()
        finished = true
    }
    
    private func wait() {
        while true {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
            var done = false
            DispatchQueue.main.sync { done = finished }
            if done { break }
        }
    }
    
    @objc private func sendNextPing() {
        if pingCount == MAX_PINGS {
            finish()
            return
        }
        
        var timeToPing: TimeInterval = 0
        if let lastPingTime = self.lastPingTime {
            timeToPing = PING_INTERVAL - Date().timeIntervalSince(lastPingTime)
        }
        
        if timeToPing > 0.0 {
            self.perform(#selector(sendNextPing), with: nil, afterDelay: timeToPing)
            return
        }
        
        pingCount = pingCount + 1
        
        pinger.send(with: nil)
        
        assert(sendTimer == nil)
        sendTimer = Timer.scheduledTimer(timeInterval: PING_TIMEOUT,
                                         target: self,
                                         selector: #selector(sendTimeout),
                                         userInfo: nil,
                                         repeats: false)
    }
    
    @objc private func sendTimeout() {
        resetSendTimer()
        pinger.stop()
        pinger.start()
    }
    
    private func resetSendTimer() {
        sendTimer?.invalidate()
        sendTimer = nil
    }
    
    private func receivedResponse(packet: Data, address: Data?, sequenceNumber: UInt16?, error: Error?, completed: Bool) {
        resetSendTimer()
        
        if completed {
            assert(sequenceNumber != nil)
            var sentPacket = sentPackets[sequenceNumber!]!
            
            sentPacket.interval = Date().timeIntervalSince(sentPacket.startTime) * 1000
            sentPackets[sequenceNumber!] = sentPacket
            
            assert(address != nil)
            let ipAddress = getHostNameInfo(address: address!, format: .IP_ADDRESS) ?? "?"
            let interval = String(format: "%.3f ms  ", sentPacket.interval!)
            log("\(packet.count) bytes from \(ipAddress): icmp_seq=\(sequenceNumber!) time=\(interval)")
        } else {
            if let err = error {
                assert(sequenceNumber != nil)
                var sentPacket = sentPackets[sequenceNumber!]!
                
                sentPacket.error = error
                sentPackets[sequenceNumber!] = sentPacket
                log("error: \(NetworkError.getErrorMessage(error: err)) for icmp_seq=\(sequenceNumber!)")
            } else {
                assert(address != nil)
                let ipAddress = getHostNameInfo(address: address!, format: .IP_ADDRESS) ?? "?"
                log("\(packet.count) bytes from \(ipAddress): Destination Host Unreachable")
            }
        }
        
        sendNextPing()
    }
    
    private func logSummary() {
        if sentPackets.isEmpty { return }
        
        log("--- ping statistics ---")
        
        let receivedPackets = sentPackets.values.filter { $0.interval != nil }
        let transmitted = Double(sentPackets.count)
        let received = Double(receivedPackets.count)
        let percentLost = ((transmitted - received) / transmitted) * 100
        let intervals = receivedPackets.map { $0.interval! }
        
        let min = intervals.min()!
        let max = intervals.max()!
        let avg = intervals.reduce(0, +) / Double(intervals.count)
        let distances = intervals.map { ($0 - avg) * ($0 - avg) }
        let varience = distances.reduce(0, +) / Double(distances.count)
        let stddev = sqrt(varience)
        
        let lostStr = String(format: "%.1f", percentLost)
        let minStr = String(format: "%.3f", min)
        let maxStr = String(format: "%.3f", max)
        let avgStr = String(format: "%.3f", avg)
        let stddevStr = String(format: "%.3f", stddev)
                                    
        log("\(transmitted) packets transmitted, \(received) packets received, \(lostStr) pct packet loss")
        log("round-trip min/avg/max/stddev = \(minStr)/\(avgStr)/\(maxStr)/\(stddevStr) ms")
    }
    
    private enum HostNameInfoFormat { case HOSTNAME, IP_ADDRESS }
    
    private func getHostNameInfo(address: Data, format: HostNameInfoFormat) -> String? {
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

extension Ping: SimplePingDelegate {
    public func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data) {
        if pinger != self.pinger { return }
        
        if pingCount == 0 {
            let hostname = getHostNameInfo(address: address, format: .HOSTNAME) ?? self.host
            let ipaddr = getHostNameInfo(address: address, format: .IP_ADDRESS) ?? "?"
            self.log("PING \(hostname) (\(ipaddr)): \(kSimplePingDefaultDataSize) data bytes")
            
            sentPackets.removeAll()
        }
        
        sendNextPing()
    }
    
    public func simplePing(_ pinger: SimplePing, didFailWithError error: Error) {
        if pinger != self.pinger { return }
        log("ping: \(NetworkError.getErrorMessage(error: error))")
        finish()
    }
    
    public func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {
        if pinger != self.pinger { return }
        sentPackets[sequenceNumber] = Packet(sequence: sequenceNumber, startTime: Date())
    }
    
    public func simplePing(_ pinger: SimplePing, didFailToSendPacket packet: Data, sequenceNumber: UInt16, error: Error) {
        if pinger != self.pinger { return }
        receivedResponse(packet: packet, address: nil, sequenceNumber: sequenceNumber, error: error, completed: false)
    }
    
    public func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16, address: Data) {
        if pinger != self.pinger { return }
        receivedResponse(packet: packet, address: address, sequenceNumber: sequenceNumber, error: nil, completed: true)
    }
    
    public func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data, address: Data) {
        if pinger != self.pinger { return }
        receivedResponse(packet: packet, address: address, sequenceNumber: nil, error: nil, completed: false)
    }
}
