//
//  ImageCache.swift
//  PhotoSwiftUISmoothly
//
//  Created by lynkto_1 on 6/20/25.
//

import Foundation
import UIKit
import Combine

@MainActor
class ImageCache: NSObject, ObservableObject {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    private var memoryWarningObserver: NSObjectProtocol?
    @Published private var currentImageCount = 0
    
    private override init() {
        // Initialize published properties first
        currentImageCount = 0
        
        // Call super.init() before using self
        super.init()
        
        // Configure cache limits
        cache.countLimit = 300 // Maximum 300 images
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB memory limit
        
        // Set delegate to track cache operations
        cache.delegate = self
        
        // Clear cache on memory warning
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearCache()
        }
    }
    
    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func image(for key: String) -> UIImage? {
        return cache.object(forKey: NSString(string: key))
    }
    
    func setImage(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale)
        cache.setObject(image, forKey: NSString(string: key), cost: cost)
        currentImageCount += 1
    }
    
    func removeImage(for key: String) {
        cache.removeObject(forKey: NSString(string: key))
        currentImageCount = max(0, currentImageCount - 1)
    }
    
    func clearCache() {
        cache.removeAllObjects()
        currentImageCount = 0
    }
    
    // MARK: - Cache Statistics
    var cacheInfo: (count: Int, totalCost: Int) {
        return (currentImageCount, cache.totalCostLimit)
    }
}

// MARK: - NSCacheDelegate
extension ImageCache: NSCacheDelegate {
    nonisolated func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: AnyObject) {
        Task { @MainActor in
            currentImageCount = max(0, currentImageCount - 1)
        }
    }
}
