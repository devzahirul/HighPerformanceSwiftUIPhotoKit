//
//  PerformanceMonitor.swift
//  PhotoSwiftUISmoothly
//
//  Created by lynkto_1 on 6/20/25.
//

import Foundation
import QuartzCore
import os.log

class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private let logger = Logger(subsystem: "com.photoswiftuismoothly", category: "Performance")
    private var startTimes: [String: CFTimeInterval] = [:]
    private let queue = DispatchQueue(label: "performance.monitor", qos: .utility)
    private let fileManager = FileManager.default
    private let logFileURL: URL
    
    private init() {
        // Create logs directory
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDirectory = documentsPath.appendingPathComponent("Logs")
        
        try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        
        // Create log file with timestamp
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        logFileURL = logsDirectory.appendingPathComponent("performance_\(timestamp).log")
        
        // Write initial log entry
        writeToFile("=== PhotoSwiftUISmoothly Performance Log Started ===")
        writeToFile("Timestamp: \(Date())")
        writeToFile("App Version: 1.0")
        writeToFile("===================================================")
    }
    
    func startMeasuring(_ operation: String) {
        let uniqueKey = "\(operation)_\(UUID().uuidString.prefix(8))"
        queue.sync {
            startTimes[uniqueKey] = CACurrentMediaTime()
        }
        logger.info("Started measuring: \(operation) [\(uniqueKey)]")
    }
    
    func endMeasuring(_ operation: String) {
        var foundKey: String?
        var duration: CFTimeInterval = 0
        
        queue.sync {
            // Find the most recent start time for this operation
            foundKey = startTimes.keys.first { $0.hasPrefix("\(operation)_") }
            
            if let key = foundKey, let startTime = startTimes[key] {
                duration = CACurrentMediaTime() - startTime
                startTimes.removeValue(forKey: key)
            }
        }
        
        guard foundKey != nil else {
            logger.error("No start time found for operation: \(operation)")
            return
        }
        
        logger.info("Completed \(operation) in \(String(format: "%.2f", duration * 1000))ms")
        writeToFile("Completed \(operation) in \(String(format: "%.2f", duration * 1000))ms")
        
        // Log performance warnings for slow operations
        if duration > 0.1 { // More than 100ms
            let warningMessage = "Slow operation detected: \(operation) took \(String(format: "%.2f", duration * 1000))ms"
            logger.warning("\(warningMessage)")
            writeToFile("⚠️ \(warningMessage)")
        }
    }
    
    func measureAsync<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
        let uniqueKey = "\(operation)_\(UUID().uuidString.prefix(8))"
        let startTime = CACurrentMediaTime()
        
        queue.sync {
            startTimes[uniqueKey] = startTime
        }
        
        logger.info("Started measuring: \(operation) [\(uniqueKey)]")
        
        defer {
            queue.sync {
                startTimes.removeValue(forKey: uniqueKey)
            }
            
            let duration = CACurrentMediaTime() - startTime
            logger.info("Completed \(operation) in \(String(format: "%.2f", duration * 1000))ms")
            writeToFile("Completed \(operation) in \(String(format: "%.2f", duration * 1000))ms")
            
            if duration > 0.1 {
                let warningMessage = "Slow operation detected: \(operation) took \(String(format: "%.2f", duration * 1000))ms"
                logger.warning("\(warningMessage)")
                writeToFile("⚠️ \(warningMessage)")
            }
        }
        
        return try await block()
    }
    
    func measure<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        let uniqueKey = "\(operation)_\(UUID().uuidString.prefix(8))"
        let startTime = CACurrentMediaTime()
        
        queue.sync {
            startTimes[uniqueKey] = startTime
        }
        
        logger.info("Started measuring: \(operation) [\(uniqueKey)]")
        
        defer {
            queue.sync {
                startTimes.removeValue(forKey: uniqueKey)
            }
            
            let duration = CACurrentMediaTime() - startTime
            logger.info("Completed \(operation) in \(String(format: "%.2f", duration * 1000))ms")
            writeToFile("Completed \(operation) in \(String(format: "%.2f", duration * 1000))ms")
            
            if duration > 0.1 {
                let warningMessage = "Slow operation detected: \(operation) took \(String(format: "%.2f", duration * 1000))ms"
                logger.warning("\(warningMessage)")
                writeToFile("⚠️ \(warningMessage)")
            }
        }
        
        return try block()
    }
    
    // MARK: - File Logging
    private func writeToFile(_ message: String) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] \(message)\n"
        
        queue.async {
            if let data = logEntry.data(using: .utf8) {
                if self.fileManager.fileExists(atPath: self.logFileURL.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: self.logFileURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    try? data.write(to: self.logFileURL)
                }
            }
        }
    }
    
    func getLogFileURL() -> URL {
        return logFileURL
    }
    
    func clearLogs() {
        try? fileManager.removeItem(at: logFileURL)
        writeToFile("=== Log Cleared ===")
    }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}
