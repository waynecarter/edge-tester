//
//  ViewController.swift
//  Client
//
//  Created by Wayne Carter on 1/12/21.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet var out: UITextView!
    @IBOutlet var progressView: UIProgressView!
    @IBOutlet var startButton: UIBarButtonItem!
    
    struct RequestResult {
        let status: Int
        let start: Double
        let duration: Double
        let serverDuration: Double
        let dbDuration: Double
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    @IBAction func start(_ sender: Any) {
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.sync {
                self.startButton.isEnabled = false
                self.out.text = nil
                self.progressView.progress = 0
            }
            
            self.runTest()
            
            DispatchQueue.main.sync {
                let alert = UIAlertController(title: "Test complete.", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alert, animated: true)
                
                self.progressView.progress = 0
                self.startButton.isEnabled = true
            }
        }
    }
    
    @IBAction func copyToClipboard(_ sender: Any) {
        UIPasteboard.general.string = out.text
    }
    
    private func runTest() {
        let testIterations = 100
        let payloadLength = 1000
        
        struct Target {
            let name: String
            let host: String
        }
        
        let targets: [Target] = [
            Target(name: "AWS Zone", host: "54.191.119.94:8080"),
            Target(name: "AWS Local Zone", host: "15.254.2.208:8080")
        ]
        
        for i in 1...testIterations {
            let data = string(withLength: payloadLength)
            let json = "%7B%22data%22:%22\(data)%22%7D"

            for target in targets {
                log(
                    target: target.name,
                    requestType: "Set",
                    result: makeRequest(
                        toURL: setUrlString(
                            withHost: target.host,
                            iterationIndex: i,
                            json: json
                        )
                    )
                )
                
                log(
                    target: target.name,
                    requestType: "Get",
                    result: makeRequest(
                        toURL: getUrlString(
                            withHost: target.host,
                            iterationIndex: i
                        )
                    )
                )
            }
            
            DispatchQueue.main.sync {
                progressView.progress = Float(i) / Float(testIterations)
            }
            
            // Sleep 1 second
            sleep(1)
        }
    }
    
    private func getUrlString(withHost host: String, iterationIndex: Int) -> String {
        return "http://\(host)/get?id=object\(iterationIndex)"
    }
    
    private func setUrlString(withHost host: String, iterationIndex: Int, json: String) -> String {
        return "http://\(host)/set?id=object\(iterationIndex)&json=\(json)"
    }
    
    private func makeRequest(toURL url: String, withBody body: String? = nil) -> RequestResult {
        var request = URLRequest(
            url: URL(string: url)!
        )
        
        if let body = body {
            request.httpMethod = "POST"
            request.httpBody = body.data(using: .utf8)
        }
        
        var response: URLResponse?
        var statusCode: Int = 0
        var startTime: Double = 0
        var endTime: Double = 0
        var serverDuration: Double = 0
        var dbDuration: Double = 0
        
        do {
            startTime = Date().timeIntervalSince1970
            try NSURLConnection.sendSynchronousRequest(request, returning: &response)
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
        } catch {
            // Do nothing
        }
        
        return RequestResult(
            status: statusCode,
            start: startTime,
            duration: endTime - startTime,
            serverDuration: serverDuration,
            dbDuration: dbDuration
        )
    }
    
    private func string(withLength length: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

        return String((0..<length).map{ _ in letters.randomElement()! })
    }

    private func log(target: String, requestType: String, result: RequestResult) {
        DispatchQueue.main.async {
            if self.out.text.count == 0 {
                self.out.text.append("Target,Request Type,Response Status,Start,Duration,Server Duration,DB Duration")
            }
            
            self.out.text.append("\n\(target),\(requestType),\(result.status),\(result.start),\(result.duration),\(result.serverDuration),\(result.dbDuration)")
        }
    }
}
