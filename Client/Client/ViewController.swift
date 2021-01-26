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
    @IBOutlet var shareButton: UIBarButtonItem!
    
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
    
    @IBAction func share(_ sender: Any) {
        let viewController = UIActivityViewController(activityItems: [ out.text ?? "" ], applicationActivities: nil)
        viewController.popoverPresentationController?.sourceView = self.view

        self.present(viewController, animated: true, completion: nil)
    }
    
    private func runTest() {
        let testIterations = 100
        let payloadLength = 1000
        
        let awsZoneHost = "54.244.149.31:8080"
        let awsWavelengthZoneHost = "155.146.22.181:8080"
        
        for i in 1...testIterations {
            let data = string(withLength: payloadLength)
            let body = "{\"data\":\"\(data)\"}"

            // AWS Zone
            
            log(
                target: "AWS Zone",
                requestType: "Set",
                result: makeRequest(
                    toURL: setUrlString(
                        withHost: awsZoneHost,
                        iterationIndex: i
                    ),
                    withBody: body
                )
            )
            
            log(
                target: "AWS Zone",
                requestType: "Get",
                result: makeRequest(
                    toURL: getUrlString(
                        withHost: awsZoneHost,
                        iterationIndex: i
                    )
                )
            )
            
            // AWS Wavelength

            log(
                target: "AWS Wavelength Zone",
                requestType: "Set",
                result: makeRequest(
                    toURL: setUrlString(
                        withHost: awsWavelengthZoneHost,
                        iterationIndex: i
                    ),
                    withBody: body
                )
            )

            log(
                target: "AWS Wavelength Zone",
                requestType: "Get",
                result: makeRequest(
                    toURL: getUrlString(
                        withHost: awsWavelengthZoneHost,
                        iterationIndex: i
                    )
                )
            )
            
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
    
    private func setUrlString(withHost host: String, iterationIndex: Int) -> String {
        return "http://\(host)/set?id=object\(iterationIndex)"
    }
    
    private func makeRequest(toURL url: String, withBody body: String? = nil) -> RequestResult {
        var request = URLRequest(
            url: URL(string: url)!
        )
        request.httpMethod = "POST"
        if let body = body {
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

