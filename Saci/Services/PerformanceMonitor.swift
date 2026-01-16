//
//  PerformanceMonitor.swift
//  Saci
//

import Foundation
import os.log

// @note monitor app performance metrics (memory, cpu, thread count)
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private var timer: Timer?
    private let logger = Logger(subsystem: "com.yoruakio.Saci", category: "performance")
    
    private var startTime: Date?
    private var peakMemory: Double = 0.0
    private var measurementCount: Int = 0
    
    private init() {}
    
    // @note start monitoring performance
    // @param interval time between measurements in seconds
    func startMonitoring(interval: TimeInterval = 3.0) {
        startTime = Date()
        peakMemory = 0.0
        measurementCount = 0
        
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.logPerformanceMetrics()
        }
        
        logger.info("🚀 Performance monitoring started (interval: \(interval)s)")
        print("🚀 Performance monitoring started (interval: \(interval)s)")
    }
    
    // @note stop performance monitoring
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        
        if let startTime = startTime {
            let duration = Date().timeIntervalSince(startTime)
            logger.info("🛑 Performance monitoring stopped (duration: \(duration, format: .fixed(precision: 1))s, measurements: \(self.measurementCount))")
            print("🛑 Performance monitoring stopped (duration: \(String(format: "%.1f", duration))s, measurements: \(measurementCount))")
        }
    }
    
    // @note log current memory and cpu usage
    private func logPerformanceMetrics() {
        measurementCount += 1
        
        let memoryMB = memoryUsage()
        let cpuPercent = cpuUsage()
        let threadCount = activeThreadCount()
        
        // @note track peak memory
        if memoryMB > peakMemory {
            peakMemory = memoryMB
        }
        
        let avgIndicator = memoryMB > 100 ? "⚠️" : (memoryMB > 50 ? "📈" : "✅")
        
        logger.info("\(avgIndicator) Memory: \(memoryMB, format: .fixed(precision: 2)) MB (peak: \(self.peakMemory, format: .fixed(precision: 2)) MB) | CPU: \(cpuPercent, format: .fixed(precision: 1))% | Threads: \(threadCount)")
        
        // @note print to console for debugging
        print("📊 [\(measurementCount)] Memory: \(String(format: "%.2f", memoryMB)) MB (peak: \(String(format: "%.2f", peakMemory)) MB) | CPU: \(String(format: "%.1f", cpuPercent))% | Threads: \(threadCount)")
    }
    
    // @note get current memory usage in megabytes
    // @return memory usage in MB
    func memoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else {
            return 0
        }
        
        return Double(info.resident_size) / 1024 / 1024
    }
    
    // @note get current cpu usage percentage
    // @return cpu usage as percentage
    func cpuUsage() -> Double {
        var totalUsageOfCPU: Double = 0.0
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        
        let threadsResult = task_threads(mach_task_self_, &threadsList, &threadsCount)
        
        guard threadsResult == KERN_SUCCESS else {
            return 0
        }
        
        if let threadsList = threadsList {
            for index in 0..<Int(threadsCount) {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)
                
                let infoResult = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threadsList[index], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }
                
                guard infoResult == KERN_SUCCESS else {
                    continue
                }
                
                let threadBasicInfo = threadInfo as thread_basic_info
                if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                    totalUsageOfCPU += Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100.0
                }
            }
            
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
        }
        
        return totalUsageOfCPU
    }
    
    // @note get current active thread count
    // @return number of active threads
    private func activeThreadCount() -> Int {
        var threadsList: thread_act_array_t?
        var threadsCount = mach_msg_type_number_t(0)
        
        let threadsResult = task_threads(mach_task_self_, &threadsList, &threadsCount)
        
        guard threadsResult == KERN_SUCCESS else {
            return 0
        }
        
        defer {
            if let threadsList = threadsList {
                vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: threadsList)), vm_size_t(Int(threadsCount) * MemoryLayout<thread_t>.stride))
            }
        }
        
        return Int(threadsCount)
    }
    
    // @note get performance summary
    // @return dictionary with performance stats
    func getPerformanceSummary() -> [String: Any] {
        return [
            "currentMemoryMB": memoryUsage(),
            "peakMemoryMB": peakMemory,
            "currentCPU": cpuUsage(),
            "threadCount": activeThreadCount(),
            "measurementCount": measurementCount,
            "uptimeSeconds": startTime.map { Date().timeIntervalSince($0) } ?? 0
        ]
    }
}
