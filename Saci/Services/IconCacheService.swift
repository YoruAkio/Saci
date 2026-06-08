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
    
    // @note doubly-linked-list node for O(1) LRU bookkeeping
    private final class Node {
        let path: String
        var image: NSImage
        var prev: Node?
        var next: Node?
        
        init(path: String, image: NSImage) {
            self.path = path
            self.image = image
        }
    }
    
    // @note in-memory icon cache (path -> node) with LRU ordering via linked list
    private var nodes: [String: Node] = [:]
    private var head: Node?  // @note most-recently used
    private var tail: Node?  // @note least-recently used
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
            guard let node = nodes[path] else { return nil }
            moveToFront(node)
            return node.image
        }
    }
    
    // @note load icon asynchronously with callback
    // @param path app bundle path
    // @param completion called on main thread with loaded icon
    func loadIcon(for path: String, completion: @escaping (NSImage) -> Void) {
        // @note check cache first (synchronous)
        if let cached = cacheQueue.sync(execute: { () -> NSImage? in
            guard let node = nodes[path] else { return nil }
            moveToFront(node)
            return node.image
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
            nodes.removeAll()
            head = nil
            tail = nil
            pendingLoads.removeAll()
            completionHandlers.removeAll()
        }
    }
    
    // @note get current cache size
    // @return number of cached icons
    var cacheSize: Int {
        cacheQueue.sync { nodes.count }
    }
    
    // @note store icon and evict least-recently-used entries beyond limit
    // @note all linked-list operations are O(1)
    // @param icon loaded icon image
    // @param path app bundle path
    private func storeIcon(_ icon: NSImage, for path: String) {
        if let existing = nodes[path] {
            // @note update existing entry and promote to most-recent
            existing.image = icon
            moveToFront(existing)
            return
        }
        
        let node = Node(path: path, image: icon)
        nodes[path] = node
        addToFront(node)
        
        // @note evict least-recently-used while over capacity
        while nodes.count > maxCacheSize, let lru = tail {
            removeNode(lru)
            nodes.removeValue(forKey: lru.path)
        }
    }
    
    // @note move an existing node to the front (most-recent) of the list
    // @param node node to promote
    private func moveToFront(_ node: Node) {
        guard head !== node else { return }
        removeNode(node)
        addToFront(node)
    }
    
    // @note insert a node at the front (most-recent) of the list
    // @param node node to insert
    private func addToFront(_ node: Node) {
        node.prev = nil
        node.next = head
        head?.prev = node
        head = node
        if tail == nil { tail = node }
    }
    
    // @note unlink a node from the list
    // @param node node to remove
    private func removeNode(_ node: Node) {
        node.prev?.next = node.next
        node.next?.prev = node.prev
        if head === node { head = node.next }
        if tail === node { tail = node.prev }
        node.prev = nil
        node.next = nil
    }
}
