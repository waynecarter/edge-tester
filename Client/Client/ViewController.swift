//
//  ViewController.swift
//  Client
//
//  Created by Wayne Carter on 1/12/21.
//

import UIKit

class ViewController: UIViewController {
    private var out = String()
    @IBOutlet var accessProgressView: UIProgressView!
    @IBOutlet var pingProgressView: UIProgressView!
    @IBOutlet var tracerouteProgressView: UIProgressView!
    @IBOutlet var testProgressView: UIProgressView!
    @IBOutlet var settingsButton: UIBarButtonItem!
    @IBOutlet var startButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    @IBAction func start(_ sender: Any) {
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.sync {
                self.startButton.isEnabled = false
                self.settingsButton.isEnabled = false
                self.out.removeAll()
                self.pingProgressView.progress = 0
                self.tracerouteProgressView.progress = 0
                self.testProgressView.progress = 0
            }
            
            self.runTest()
            
            DispatchQueue.main.sync {
                let alert = UIAlertController(title: "Test Complete", message: nil, preferredStyle: .alert)
                alert.addAction(
                    UIAlertAction(title: "OK", style: .default, handler: { _ in
                        self.accessProgressView.progress = 0
                        self.pingProgressView.progress = 0
                        self.tracerouteProgressView.progress = 0
                        self.testProgressView.progress = 0
                        self.startButton.isEnabled = true
                        self.settingsButton.isEnabled = true
                    })
                )
                self.present(alert, animated: true)
            }
        }
    }
    
    @IBAction func openSettings(_ sender: Any) {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString),
           UIApplication.shared.canOpenURL(settingsUrl)
        {
            UIApplication.shared.open(settingsUrl)
        }
    }
    
    private func runTest() {
        struct Target {
            let name: String
            let host: String
        }
        
        let cloudTargetName = Settings.cloudTargetName // e.g. "AWS Zone"
        let cloudTargetHost = Settings.cloudTargetHost // e.g. "34.218.247.30"
        let edgeTargetName = Settings.edgeTargetName   // e.g. "AWS Wavelength Zone"
        let edgeTargetHost = Settings.edgeTargetHost   // e.g. "155.146.22.181"
        
        guard cloudTargetName != nil, cloudTargetHost != nil, edgeTargetName != nil, edgeTargetHost != nil else {
            DispatchQueue.main.sync {
                let alert = UIAlertController(title: "Settings", message: "Cloud and edge target information must be defined in Settings.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString),
                   UIApplication.shared.canOpenURL(settingsUrl)
                {
                    alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { action in
                        self.openSettings(action)
                    }))
                }
                
                present(alert, animated: true)
            }
            
            return
        }
        
        let targets: [Target] = [
            Target(name: cloudTargetName!, host: cloudTargetHost!),
            Target(name: edgeTargetName!, host: edgeTargetHost!)
        ]
        
        // Test that all targets are accessible
        DispatchQueue.main.sync {
            accessProgressView.progress = 0.01
        }
        for i in 0..<targets.count {
            let target = targets[i]
            let pingResult: RequestResult = {
                return makeRequest(
                    toURL: pingUrlString(
                        withHost: target.host
                    )
                )
            }()
            if pingResult.status != 200 {
                var shouldContinue = true
                
                DispatchQueue.main.sync {
                    var message = "Cannot access \(target.name)\nStatus \(pingResult.status)"
                    if let error = pingResult.error {
                        let nserror = error as NSError
                        message = message + "\n\(nserror.localizedDescription)"
                    }
                    
                    let alert = UIAlertController(title: "Test Failed", message: message, preferredStyle: .alert)
                    alert.addAction(
                        UIAlertAction(title: "OK", style: .default, handler: { _ in
                            shouldContinue = true
                        })
                    )
                    
                    shouldContinue = false
                    self.present(alert, animated: true)
                }
                
                
                while shouldContinue == false {
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
                }
                return
            }
            DispatchQueue.main.sync {
                accessProgressView.progress = Float(i+1) / Float(targets.count)
            }
        }
        
        // If enabled, run ping
        if Settings.shouldPing {
            DispatchQueue.main.sync {
                pingProgressView.progress = 0.01
            }
            for i in 0..<targets.count {
                let target = targets[i]
                log("ping \(target.name)")
                let ping = Ping(host: target.host) { result in
                    self.log(result)
                }
                ping.start()
                log("")
                DispatchQueue.main.sync {
                    pingProgressView.progress = Float(i+1) / Float(targets.count)
                }
            }
        }
        
        // If enabled, run traceroute
        if Settings.shouldTraceroute {
            DispatchQueue.main.sync {
                tracerouteProgressView.progress = 0.01
            }
            for i in 0..<targets.count {
                let target = targets[i]
                log("traceroute \(target.name)")
                let trace = Traceroute(host: target.host) { result in
                    self.log(result)
                }
                trace.start()
                log("")
                DispatchQueue.main.sync {
                    tracerouteProgressView.progress = Float(i+1) / Float(targets.count)
                }
            }
        }
        
        // If enabled, run latency tests
        if Settings.shouldTestLatency {
            logHeaders()
            let testIterations = Settings.testIterations
            let payloadSize = Settings.payloadSize
            for i in 1...testIterations {
                let data = string(withLength: payloadSize)
                let json = "{\"data\":\"\(data)\"}"

                for target in targets {
                    let setResult: RequestResult = {
                        return makeRequest(
                            toURL: setUrlString(
                                withHost: target.host,
                                iterationIndex: i
                            ),
                            withBody: json
                        )
                    }()
                    log(target: target.name, requestType: "Set", result: setResult)

                    let getResult = makeRequest(
                        toURL: getUrlString(
                            withHost: target.host,
                            iterationIndex: i
                        )
                    )
                    log(target: target.name, requestType: "Get", result: getResult)

                    let setString = json
                    let getString = String(data: getResult.data ?? Data(), encoding: String.Encoding.utf8)
                    if setString != getString {
                        log("Error: Get value is not equal to the value Set.")
                    }
                }
                
                DispatchQueue.main.sync {
                    testProgressView.progress = Float(i) / Float(testIterations)
                }
                
                // Sleep 1 second
                sleep(1)
            }
        }
        
        // Post results
        for target in targets {
            _ = makeRequest(
                toURL: resultsUrlString(withHost: target.host),
                withBody: out
            )
        }
    }
    
    private func getUrlString(withHost host: String, iterationIndex: Int) -> String {
        return "http://\(host):8080/get?id=object\(iterationIndex)"
    }
    
    private func setUrlString(withHost host: String, iterationIndex: Int) -> String {
        return "http://\(host):8080/set?id=object\(iterationIndex)"
    }
    
    private func pingUrlString(withHost host: String) -> String {
        return "http://\(host):8080/ping"
    }
    
    private func resultsUrlString(withHost host: String) -> String {
        return "http://\(host):8080/results"
    }
    
    private func makeRequest(toURL url: String, withBody body: String? = nil) -> RequestResult {
        var request = URLRequest(
            url: URL(string: url)!
        )
        
        if let body = body {
            request.httpMethod = "POST"
            request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            request.setValue("\(body.lengthOfBytes(using: .utf8))", forHTTPHeaderField: "Content-Length")
            request.httpBody = body.data(using: .utf8)
        }
        
        var response: URLResponse?
        var statusCode: Int = 0
        var startTime: Double = 0
        var endTime: Double = 0
        var serverDuration: Double = 0
        var dbDuration: Double = 0
        
        startTime = Date().timeIntervalSince1970
        let taskResult = URLSession.shared.synchronousDataTask(with: request)
        response = taskResult.response
        endTime = Date().timeIntervalSince1970
        
        if let response = response as? HTTPURLResponse {
            statusCode = response.statusCode
            
            if let serverTimings = response.value(forHTTPHeaderField: "Server-Timing")?.split(separator: ",") {
                for serverTiming in serverTimings {
                    if let timingRange = serverTiming.range(of: "total;dur="),
                       let timingDuration = Double(serverTiming[timingRange.upperBound...])
                    {
                        serverDuration = timingDuration / Double(1000.0) // Seconds
                    } else if let timingRange = serverTiming.range(of: "db;dur="),
                       let timingDuration = Double(serverTiming[timingRange.upperBound...])
                    {
                        dbDuration = timingDuration / Double(1000.0) // Seconds
                    }
                }
            }
        }
        
        return RequestResult(
            data: taskResult.data,
            status: statusCode,
            error: taskResult.error,
            start: startTime,
            duration: endTime - startTime,
            serverDuration: serverDuration,
            dbDuration: dbDuration
        )
    }
    
    struct RequestResult {
        let data: Data?
        let status: Int
        let error: Error?
        let start: Double
        let duration: Double
        let serverDuration: Double
        let dbDuration: Double
    }
    
    private func string(withLength length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

        return String((0..<length).map{ _ in letters.randomElement()! })
    }
    
    private func logHeaders() {
        log("Target,Request Type,Response Status,Start,Duration,Server Duration,DB Duration")
    }

    private func log(target: String, requestType: String, result: RequestResult) {
        log("\(target),\(requestType),\(result.status),\(result.start),\(result.duration),\(result.serverDuration),\(result.dbDuration)")
        
        if let error = result.error {
            let nserror = error as NSError
            log("Error: \(nserror.localizedDescription)")
        }
    }
    
    private func log(_ string: String) {
        if out.count > 0 {
            out += "\n"
        }
        out += string
    }
}
