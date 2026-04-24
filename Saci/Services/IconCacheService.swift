//
//  IconCacheService.swift
//  Saci
//

import AppKit

// @note service to cache app icons for better performance
// @note icons are loaded lazily and cached in memory
class IconCacheService {
    static let shared = IconCacheService()
    
    // @note serial queue for thread-safe cache access
    private let cacheQueue = DispatchQueue(label: "com.saci.iconCache")
    
    // @note dedicated queue for icon loading with limited concurrency
    private let loadQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.saci.iconLoadQueue"
        queue.maxConcurrentOperationCount = 2  // @note limit to 2 concurrent loads
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    // @note in-memory icon cache (path -> icon)
    private var cache: [String: NSImage] = [:]
    private var cacheAccessOrder: [String] = []
    private let maxCacheSize = 128
    
    // @note track pending icon loads to avoid duplicate work
    private var pendingLoads: Set<String> = []
    
    // @note completion handlers waiting for icons
    private var completionHandlers: [String: [(NSImage) -> Void]] = [:]
    
    private init() {}
    
    // @note get cached icon synchronously
    // @param path app bundle path
    // @return cached icon or nil if not cached
    func getCachedIcon(for path: String) -> NSImage? {
        cacheQueue.sync {
            guard let icon = cache[path] else { return nil }
            markCacheAccess(path)
            return icon
        }
    }
    
    // @note load icon asynchronously with callback
    // @param path app bundle path
    // @param completion called on main thread with loaded icon
    func loadIcon(for path: String, completion: @escaping (NSImage) -> Void) {
        // @note check cache first (synchronous)
        if let cached = cacheQueue.sync(execute: { () -> NSImage? in
            guard let icon = cache[path] else { return nil }
            markCacheAccess(path)
            return icon
        }) {
            DispatchQueue.main.async { completion(cached) }
            return
        }
        
        // @note check if already loading, add to completion handlers
        let shouldStartLoad = cacheQueue.sync { () -> Bool in
            if pendingLoads.contains(path) {
                // @note already loading, add completion handler
                if completionHandlers[path] != nil {
                    completionHandlers[path]?.append(completion)
                } else {
                    completionHandlers[path] = [completion]
                }
                return false
            }
            // @note mark as pending and start load
            pendingLoads.insert(path)
            completionHandlers[path] = [completion]
            return true
        }
        
        guard shouldStartLoad else { return }
        
        // @note load icon on dedicated queue with limited concurrency
        loadQueue.addOperation { [weak self] in
            let icon = NSWorkspace.shared.icon(forFile: path)
            
            // @note cache the icon and get completion handlers
            let handlers = self?.cacheQueue.sync { () -> [(NSImage) -> Void]? in
                self?.storeIcon(icon, for: path)
                self?.pendingLoads.remove(path)
                let h = self?.completionHandlers[path]
                self?.completionHandlers.removeValue(forKey: path)
                return h
            }
            
            // @note call all completion handlers on main thread
            if let handlers = handlers {
                DispatchQueue.main.async {
                    for handler in handlers {
                        handler(icon)
                    }
                }
            }
        }
    }
    
    // @note cancel all pending icon loads (call when search changes)
    func cancelPendingLoads() {
        loadQueue.cancelAllOperations()
        cacheQueue.sync {
            pendingLoads.removeAll()
            completionHandlers.removeAll()
        }
    }
    
    // @note clear all cached icons (for memory pressure)
    func clearCache() {
        loadQueue.cancelAllOperations()
        cacheQueue.sync {
            cache.removeAll()
            cacheAccessOrder.removeAll()
            pendingLoads.removeAll()
            completionHandlers.removeAll()
        }
    }
    
    // @note get current cache size
    // @return number of cached icons
    var cacheSize: Int {
        cacheQueue.sync { cache.count }
    }
    
    // @note store icon and evict least-recently-used entries beyond limit
    // @param icon loaded icon image
    // @param path app bundle path
    private func storeIcon(_ icon: NSImage, for path: String) {
        cache[path] = icon
        markCacheAccess(path)
        
        while cacheAccessOrder.count > maxCacheSize, let oldest = cacheAccessOrder.first {
            cache.removeValue(forKey: oldest)
            cacheAccessOrder.removeFirst()
        }
    }
    
    // @note move path to most-recent cache position
    // @param path app bundle path
    private func markCacheAccess(_ path: String) {
        cacheAccessOrder.removeAll { $0 == path }
        cacheAccessOrder.append(path)
    }
}
