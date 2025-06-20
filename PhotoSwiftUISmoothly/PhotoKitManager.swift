//
//  PhotoKitManager.swift
//  PhotoSwiftUISmoothly
//
//  Created by lynkto_1 on 6/20/25.
//

import Foundation
import Photos
import UIKit
import Combine
import CoreLocation

// MARK: - UIApplication Extension for Key Window
extension UIApplication {
    var keyWindow: UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

@MainActor
class PhotoKitManager: NSObject, ObservableObject, PHPhotoLibraryChangeObserver {
    static let shared = PhotoKitManager()
    
    @Published var photos: [PhotoAsset] = []
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    
    private let imageManager = PHImageManager.default()
    private let imageCache = ImageCache.shared
    private let performanceMonitor = PerformanceMonitor.shared
    private var cancellables = Set<AnyCancellable>()
    private var photosFetchResult: PHFetchResult<PHAsset>?
    
    private override init() {
        super.init()
        print("📸 PhotoKitManager initializing...")
        checkAuthorizationStatus()
        
        // Register for photo library changes
        PHPhotoLibrary.shared().register(self)
        print("📸 Registered for photo library changes")
    }
    
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    func requestPhotoAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status
        
        if status == .authorized || status == .limited {
            await loadPhotos()
        }
    }
    
    // MARK: - Limited Access Support
    
    /// Presents the limited photo library picker to allow users to add more photos
    /// This is only available when authorization status is .limited
    func presentLimitedLibraryPicker() {
        guard authorizationStatus == .limited else { 
            print("📸 Cannot present limited library picker - status is not .limited")
            return 
        }
        
        print("📸 Presenting limited photo library picker...")
        
        Task { @MainActor in
            // Get the UIViewController from which to present the picker
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                print("📸 Could not find root view controller")
                return
            }
            
            // Find the topmost presented view controller
            var viewController = rootViewController
            while let presentedViewController = viewController.presentedViewController {
                viewController = presentedViewController
            }
            
            print("📸 Using view controller: \(type(of: viewController))")
            
            // Use runtime check to call the presentLimitedLibraryPicker method
            let photoLibrary = PHPhotoLibrary.shared()
            
            // Check for iOS 15+ callback version first
            if #available(iOS 15.0, *) {
                let callbackSelector = NSSelectorFromString("presentLimitedLibraryPickerFromViewController:completionHandler:")
                if photoLibrary.responds(to: callbackSelector) {
                    print("📸 Using iOS 15+ presentLimitedLibraryPicker with callback")
                    
                    // Present the limited-library selection user interface with a callback
                    let methodIMP = photoLibrary.method(for: callbackSelector)
                    typealias CallbackFunction = @convention(c) (AnyObject, Selector, UIViewController, @escaping ([String]) -> Void) -> Void
                    let callbackFunction = unsafeBitCast(methodIMP, to: CallbackFunction.self)
                    
                    callbackFunction(photoLibrary, callbackSelector, viewController) { identifiers in
                        Task { @MainActor in
                            print("📸 Limited library picker callback - newly selected assets: \(identifiers.count)")
                            for newlySelectedAssetIdentifier in identifiers {
                                print("📸 Newly selected asset: \(newlySelectedAssetIdentifier)")
                                // The PHPhotoLibraryChangeObserver will handle the updates
                            }
                            // Force reload to ensure we have the latest photos
                            await self.loadPhotos()
                        }
                    }
                    return
                }
            }
            
            // Fallback to iOS 14+ basic version
            let basicSelector = NSSelectorFromString("presentLimitedLibraryPickerFromViewController:")
            if photoLibrary.responds(to: basicSelector) {
                print("📸 Using iOS 14+ presentLimitedLibraryPicker (basic)")
                
                // Present the limited-library selection user interface
                photoLibrary.perform(basicSelector, with: viewController)
            } else {
                print("📸 presentLimitedLibraryPicker not available, using fallback")
                // Fallback: re-request authorization
                await self.fallbackRequestAuthorization()
            }
        }
    }
    
    /// Fallback method when presentLimitedLibraryPicker is not available
    private func fallbackRequestAuthorization() async {
        print("📸 Using fallback: re-requesting authorization to trigger picker...")
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            self.authorizationStatus = status
            print("📸 Authorization status after request: \(status.rawValue)")
        }
    }
    
    /// Check if the user has limited photo access and if they can add more photos
    var canPresentLimitedLibraryPicker: Bool {
        return authorizationStatus == .limited
    }
    
    private func checkAuthorizationStatus() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        if authorizationStatus == .authorized || authorizationStatus == .limited {
            Task {
                await loadPhotos()
            }
        }
    }
    
    func loadPhotos() async {
        print("📸 Loading photos - current count: \(photos.count)")
        await performanceMonitor.measureAsync("loadPhotos") {
            isLoading = true
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = 1000 // Limit initial fetch for performance
            
            let results = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            print("📸 Fetch result count: \(results.count)")
            
            // Store fetch result for change observation
            photosFetchResult = results
            
            var photoAssets: [PhotoAsset] = []
            
            results.enumerateObjects { asset, _, _ in
                let photoAsset = PhotoAsset(
                    id: asset.localIdentifier,
                    phAsset: asset,
                    creationDate: asset.creationDate ?? Date(),
                    location: asset.location
                )
                photoAssets.append(photoAsset)
            }
            
            photos = photoAssets
            print("📸 Photos loaded: \(photos.count)")
            isLoading = false
        }
    }
    
    // MARK: - PHPhotoLibraryChangeObserver
    
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        print("📸 PhotoLibraryChangeObserver: Change detected!")
        Task { @MainActor in
            await handlePhotoLibraryChanges(changeInstance)
        }
    }
    
    private func handlePhotoLibraryChanges(_ changeInstance: PHChange) async {
        print("📸 Photo library change detected")
        
        // Check if authorization status has changed
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if currentStatus != authorizationStatus {
            print("📸 Authorization status changed from \(authorizationStatus.rawValue) to \(currentStatus.rawValue)")
            authorizationStatus = currentStatus
        }
        
        guard let fetchResult = photosFetchResult else {
            print("📸 No fetch result available, reloading all photos")
            await loadPhotos()
            return
        }
        
        if let changeDetails = changeInstance.changeDetails(for: fetchResult) {
            print("📸 Processing fetch result changes")
            print("📸 - Inserted: \(changeDetails.insertedObjects.count)")
            print("📸 - Removed: \(changeDetails.removedObjects.count)")
            print("📸 - Changed: \(changeDetails.changedObjects.count)")
            
            // Update the fetch result
            photosFetchResult = changeDetails.fetchResultAfterChanges
            
            // Reload photos to reflect changes
            await loadPhotos()
        } else {
            print("📸 No change details for fetch result, checking for general changes")
            // Even if we don't have specific change details, reload photos
            // This is important for limited access changes
            await loadPhotos()
        }
    }
    
    func loadThumbnail(for asset: PhotoAsset, targetSize: CGSize) async -> UIImage? {
        let cacheKey = "\(asset.id)-\(Int(targetSize.width))x\(Int(targetSize.height))"
        
        // Check cache first
        if let cachedImage = imageCache.image(for: cacheKey) {
            return cachedImage
        }
        
        return await performanceMonitor.measureAsync("loadThumbnail") {
            return await withCheckedContinuation { continuation in
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                options.isSynchronous = false
                options.resizeMode = .fast
                
                imageManager.requestImage(
                    for: asset.phAsset,
                    targetSize: targetSize,
                    contentMode: .aspectFill,
                    options: options
                ) { [weak self] image, _ in
                    if let image = image {
                        self?.imageCache.setImage(image, for: cacheKey)
                    }
                    continuation.resume(returning: image)
                }
            }
        }
    }
    
    func loadFullSizeImage(for asset: PhotoAsset) async -> UIImage? {
        return await performanceMonitor.measureAsync("loadFullSizeImage") {
            return await withCheckedContinuation { continuation in
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.isNetworkAccessAllowed = true
                options.isSynchronous = false
                
                imageManager.requestImage(
                    for: asset.phAsset,
                    targetSize: PHImageManagerMaximumSize,
                    contentMode: .aspectFit,
                    options: options
                ) { image, _ in
                    continuation.resume(returning: image)
                }
            }
        }
    }
    
    func deletePhoto(_ asset: PhotoAsset) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets([asset.phAsset] as NSArray)
        }
        
        // Remove from local array
        photos.removeAll { $0.id == asset.id }
    }
}

// MARK: - PhotoAsset Model
struct PhotoAsset: Identifiable, Hashable {
    let id: String
    let phAsset: PHAsset
    let creationDate: Date
    let location: CLLocation?
    
    var duration: TimeInterval {
        phAsset.duration
    }
    
    var mediaType: PHAssetMediaType {
        phAsset.mediaType
    }
    
    var isVideo: Bool {
        mediaType == .video
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PhotoAsset, rhs: PhotoAsset) -> Bool {
        lhs.id == rhs.id
    }
}
