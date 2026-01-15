//
//  AppSearchService.swift
//  Saci
//

import SwiftUI
import Combine

// @note service to search installed applications with persistent cache
class AppSearchService: ObservableObject {
    static let shared = AppSearchService()
    
    @Published var results: [SearchResult] = []
    @Published var isLoading = false
    
    private var allApps: [SearchResult] = []
    private let fileManager = FileManager.default
    private let cacheFileName = "app_cache.json"
    
    // @note serial queue for thread-safe access to allApps
    private let appsQueue = DispatchQueue(label: "com.saci.appsQueue")
    
    // @note background queue for search operations
    private let searchQueue = DispatchQueue(label: "com.saci.searchQueue", qos: .userInitiated)
    
    // @note debounce search to avoid excessive filtering
    private var searchWorkItem: DispatchWorkItem?
    private let searchDebounceMs: Int = 50
    
    // @note file system monitoring for automatic app detection
    private var eventStream: FSEventStreamRef?
    private var monitorWorkItem: DispatchWorkItem?
    
    // @note search paths for applications
    private let searchPaths = [
        "/Applications",
        "/System/Applications",
        "/System/Applications/Utilities",
        NSHomeDirectory() + "/Applications"
    ]
    
    // @note cache file URL in Application Support directory
    private var cacheFileURL: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let saciDir = appSupport.appendingPathComponent("Saci", isDirectory: true)
        
        // @note create directory if needed
        if !fileManager.fileExists(atPath: saciDir.path) {
            try? fileManager.createDirectory(at: saciDir, withIntermediateDirectories: true)
        }
        
        return saciDir.appendingPathComponent(cacheFileName)
    }
    
    init() {
        loadApps()
        startFileSystemMonitoring()
    }
    
    deinit {
        stopFileSystemMonitoring()
    }
    
    // @note load apps from cache first, then validate in background
    private func loadApps() {
        isLoading = true
        
        // @note try to load from cache instantly (no file existence checks)
        if let cachedApps = loadFromCacheInstant() {
            appsQueue.sync {
                allApps = cachedApps
            }
            isLoading = false
            
            // @note validate and update cache in background
            validateAndUpdateCacheInBackground()
        } else {
            // @note no cache, do full scan
            fullScan()
        }
    }
    
    // @note load apps from cache file instantly without file existence validation
    // @return array of SearchResult or nil if cache doesn't exist
    private func loadFromCacheInstant() -> [SearchResult]? {
        guard let cacheURL = cacheFileURL,
              fileManager.fileExists(atPath: cacheURL.path),
              let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(AppCache.self, from: data) else {
            return nil
        }
        
        // @note convert to SearchResult with icons, skip file existence check for speed
        return cache.apps.map { $0.toSearchResult() }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    // @note save apps to cache file
    // @param apps array of CachedApp to save
    private func saveToCache(_ apps: [CachedApp]) {
        guard let cacheURL = cacheFileURL else { return }
        
        let cache = AppCache(apps: apps, lastUpdated: Date())
        
        do {
            let data = try JSONEncoder().encode(cache)
            try data.write(to: cacheURL)
        } catch {
            ErrorManager.shared.report(.cacheSaveFailed(underlyingError: error), showWindow: false)
        }
    }
    
    // @note validate cached apps and update in background using single-pass algorithm
    private func validateAndUpdateCacheInBackground() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            // @note get current cached apps
            let currentApps = self.appsQueue.sync { self.allApps }
            
            // @note build lookup of current paths in single pass
            var currentPathsMap: [String: Bool] = [:]
            currentPathsMap.reserveCapacity(currentApps.count)
            for app in currentApps {
                // @note check existence and store result
                currentPathsMap[app.path] = self.fileManager.fileExists(atPath: app.path)
            }
            
            // @note scan filesystem for apps
            let scannedApps = self.scanAllApps()
            
            // @note single pass to find new apps and build final list
            var newApps: [SearchResult] = []
            var finalCachedApps: [CachedApp] = []
            finalCachedApps.reserveCapacity(scannedApps.count)
            
            for app in scannedApps {
                finalCachedApps.append(app)
                if currentPathsMap[app.path] == nil {
                    // @note new app not in cache
                    newApps.append(app.toSearchResult())
                }
            }
            
            // @note collect removed paths (existed in cache but not in scan, or file deleted)
            let scannedPathsSet = Set(scannedApps.map { $0.path })
            var removedPaths: Set<String> = []
            for (path, exists) in currentPathsMap {
                if !exists || !scannedPathsSet.contains(path) {
                    removedPaths.insert(path)
                }
            }
            
            // @note only update if there are changes
            if !newApps.isEmpty || !removedPaths.isEmpty {
                DispatchQueue.main.async {
                    self.appsQueue.sync {
                        if !removedPaths.isEmpty {
                            self.allApps.removeAll { removedPaths.contains($0.path) }
                        }
                        if !newApps.isEmpty {
                            self.allApps.append(contentsOf: newApps)
                            self.allApps.sort { $0.name.lowercased() < $1.name.lowercased() }
                        }
                    }
                }
                
                // @note save updated cache
                self.saveToCache(finalCachedApps)
            }
        }
    }
    
    // @note full scan of all app directories
    private func fullScan() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let scannedApps = self.scanAllApps()
            let searchResults = scannedApps.map { $0.toSearchResult() }
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
            
            // @note save to cache
            self.saveToCache(scannedApps)
            
            DispatchQueue.main.async {
                self.appsQueue.sync {
                    self.allApps = searchResults
                }
                self.isLoading = false
            }
        }
    }
    
    // @note scan all app directories and return CachedApp array
    // @return array of CachedApp found in search paths
    private func scanAllApps() -> [CachedApp] {
        var apps: [CachedApp] = []
        
        for searchPath in searchPaths {
            guard let contents = try? fileManager.contentsOfDirectory(atPath: searchPath) else {
                continue
            }
            
            for item in contents {
                if item.hasSuffix(".app") {
                    let fullPath = (searchPath as NSString).appendingPathComponent(item)
                    let appName = (item as NSString).deletingPathExtension
                    
                    // @note get modification date for cache validation
                    let modDate = (try? fileManager.attributesOfItem(atPath: fullPath)[.modificationDate] as? Date) ?? Date()
                    
                    apps.append(CachedApp(
                        name: appName,
                        path: fullPath,
                        modificationDate: modDate
                    ))
                }
            }
        }
        
        return apps
    }
    
    // @note filter apps based on search query with debounce
    // @param query search text to filter
    func search(query: String) {
        // @note cancel previous search
        searchWorkItem?.cancel()
        
        if query.isEmpty {
            results = []
            return
        }
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            let lowercasedQuery = query.lowercased()
            
            // @note thread-safe read of allApps
            let apps = self.appsQueue.sync { self.allApps }
            
            // @note filter on background queue
            let filtered = apps.filter { app in
                app.name.lowercased().contains(lowercasedQuery)
            }
            
            // @note update results on main thread
            DispatchQueue.main.async { [weak self] in
                self?.results = filtered
            }
        }
        
        searchWorkItem = workItem
        searchQueue.asyncAfter(deadline: .now() + .milliseconds(searchDebounceMs), execute: workItem)
    }
    
    // @note launch app at given path
    // @param path full path to the app bundle
    func launchApp(at path: String) {
        let url = URL(fileURLWithPath: path)
        let config = NSWorkspace.OpenConfiguration()
        
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            if let error = error {
                ErrorManager.shared.report(.appLaunchFailed(path: path, underlyingError: error))
            }
        }
    }
    
    // @note clear search results
    func clearResults() {
        results = []
    }
    
    // @note force refresh app list and rebuild cache
    func refresh() {
        fullScan()
    }
    
    // @note clear cache and rescan
    func clearCache() {
        if let cacheURL = cacheFileURL {
            try? fileManager.removeItem(at: cacheURL)
        }
        fullScan()
    }
    
    // @note start file system monitoring for automatic app detection
    private func startFileSystemMonitoring() {
        let pathsToWatch = searchPaths as CFArray
        
        var context = FSEventStreamContext(
            version: 0,
            info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        let callback: FSEventStreamCallback = { (
            streamRef,
            clientCallBackInfo,
            numEvents,
            eventPaths,
            eventFlags,
            eventIds
        ) in
            guard let info = clientCallBackInfo else { return }
            let service = Unmanaged<AppSearchService>.fromOpaque(info).takeUnretainedValue()
            service.handleFileSystemEvent()
        }
        
        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            3.0,
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        )
        
        if let stream = eventStream {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
        }
    }
    
    // @note stop file system monitoring
    private func stopFileSystemMonitoring() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
        monitorWorkItem?.cancel()
    }
    
    // @note handle file system event with debouncing
    private func handleFileSystemEvent() {
        // @note cancel previous work item
        monitorWorkItem?.cancel()
        
        // @note create new work item with 3 second delay
        let workItem = DispatchWorkItem { [weak self] in
            self?.validateAndUpdateCacheInBackground()
        }
        
        monitorWorkItem = workItem
        
        // @note execute after delay on main queue
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: workItem)
    }
}
