//
//  AppSearchService.swift
//  Saci
//

import SwiftUI

// @note service to search installed applications with persistent cache
class AppSearchService: ObservableObject {
    @Published var results: [SearchResult] = []
    @Published var isLoading = false
    
    private var allApps: [SearchResult] = []
    private let fileManager = FileManager.default
    private let cacheFileName = "app_cache.json"
    
    // @note serial queue for thread-safe access to allApps
    private let appsQueue = DispatchQueue(label: "com.saci.appsQueue")
    
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
    }
    
    // @note load apps from cache first, then update in background
    private func loadApps() {
        isLoading = true
        
        // @note try to load from cache first for instant results
        if let cachedApps = loadFromCache() {
            appsQueue.sync {
                allApps = cachedApps
            }
            isLoading = false
            
            // @note update cache in background
            updateCacheInBackground()
        } else {
            // @note no cache, do full scan
            fullScan()
        }
    }
    
    // @note load apps from cache file
    // @return array of SearchResult or nil if cache doesn't exist
    private func loadFromCache() -> [SearchResult]? {
        guard let cacheURL = cacheFileURL,
              fileManager.fileExists(atPath: cacheURL.path),
              let data = try? Data(contentsOf: cacheURL),
              let cache = try? JSONDecoder().decode(AppCache.self, from: data) else {
            return nil
        }
        
        // @note filter out apps that no longer exist
        let validApps = cache.apps.filter { fileManager.fileExists(atPath: $0.path) }
        
        // @note convert to SearchResult with icons
        return validApps.map { $0.toSearchResult() }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
    
    // @note save apps to cache file
    // @param apps array of CachedApp to save
    private func saveToCache(_ apps: [CachedApp]) {
        guard let cacheURL = cacheFileURL else { return }
        
        let cache = AppCache(apps: apps, lastUpdated: Date())
        
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: cacheURL)
        }
    }
    
    // @note update cache in background, detecting new/removed apps
    private func updateCacheInBackground() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            let scannedApps = self.scanAllApps()
            
            // @note thread-safe read of current paths
            let currentPaths = self.appsQueue.sync {
                Set(self.allApps.map { $0.path })
            }
            let scannedPaths = Set(scannedApps.map { $0.path })
            
            // @note find new apps
            let newPaths = scannedPaths.subtracting(currentPaths)
            // @note find removed apps
            let removedPaths = currentPaths.subtracting(scannedPaths)
            
            if !newPaths.isEmpty || !removedPaths.isEmpty {
                // @note update cache and memory
                let newApps = scannedApps.filter { newPaths.contains($0.path) }
                    .map { $0.toSearchResult() }
                
                // @note thread-safe update of allApps on main thread
                DispatchQueue.main.async {
                    self.appsQueue.sync {
                        // @note remove deleted apps
                        self.allApps.removeAll { removedPaths.contains($0.path) }
                        // @note add new apps
                        self.allApps.append(contentsOf: newApps)
                        // @note sort
                        self.allApps.sort { $0.name.lowercased() < $1.name.lowercased() }
                    }
                }
                
                // @note save updated cache
                self.saveToCache(scannedApps)
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
    
    // @note filter apps based on search query
    // @param query search text to filter
    func search(query: String) {
        if query.isEmpty {
            results = []
            return
        }
        
        let lowercasedQuery = query.lowercased()
        
        // @note thread-safe read of allApps
        let apps = appsQueue.sync { allApps }
        results = apps.filter { app in
            app.name.lowercased().contains(lowercasedQuery)
        }
    }
    
    // @note launch app at given path
    // @param path full path to the app bundle
    func launchApp(at path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
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
}
