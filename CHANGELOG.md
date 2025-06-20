# Changelog

All notable changes to PhotoSwiftUISmoothly will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### ✅ Fixed - Limited Library Picker Implementation

#### **Official Apple API Implementation**
- Implemented `presentLimitedLibraryPicker(from:)` exactly as documented by Apple
- Added runtime method checking to handle SDK availability issues
- Eliminated compilation errors by using dynamic method calls with `NSSelectorFromString`

#### **Multi-iOS Version Support**
- **iOS 15+**: Uses callback version that provides newly selected asset identifiers
  ```swift
  PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController) { identifiers in
      for newlySelectedAssetIdentifier in identifiers {
          // Stage asset for app interaction
      }
  }
  ```
- **iOS 14+**: Uses basic version without callback
  ```swift
  PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
  ```
- **Fallback**: Authorization re-request for older versions or when API unavailable

#### **Enhanced View Controller Handling**
- Proper view controller hierarchy detection from window scene
- Traverses presentation stack to find topmost view controller
- Ensures picker is presented from the correct view controller context

#### **Automatic Photo Grid Updates**
- `PHPhotoLibraryChangeObserver` detects when user adds photos via picker
- Photo grid updates automatically without manual refresh
- iOS 15+ callback provides exact list of newly selected photos for enhanced tracking

#### **Improved User Experience**
- "Select More" button in limited access banner now reliably triggers iOS system picker
- Eliminates the need to send users to Settings app
- Follows iOS native "Edit Selected Photos" behavior exactly

#### **Technical Implementation Details**
- Runtime selector checking: `NSSelectorFromString("presentLimitedLibraryPickerFromViewController:")`
- iOS 15+ callback support with `completionHandler` parameter
- Enhanced debug logging for troubleshooting picker behavior
- Fallback mechanism ensures functionality across all iOS versions

#### **Code Quality Improvements**
- Removed complex workaround implementations
- Simplified codebase while maintaining full functionality
- Added comprehensive error handling and logging
- Full compatibility with existing PhotoKit integration

### **Bug Fixes**
- Fixed "Select More" button not triggering limited photo picker
- Resolved compilation errors related to unavailable SDK methods
- Fixed photo grid not updating after user selects additional photos
- Eliminated crashes when trying to present picker from wrong view controller

### **Performance**
- Optimized limited access detection and handling
- Reduced unnecessary authorization requests
- Improved change observer efficiency for limited access updates

---

## Previous Versions

### [1.0.0] - Initial Release
- High-performance PhotoKit integration for iOS
- Advanced image caching with `ImageCache`
- Smooth scrolling photo grid with `LazyVGrid`
- Comprehensive performance monitoring with `PerformanceMonitor`
- Full documentation and troubleshooting guides
- Support for photo details view with zoom and pan
- Search functionality for photos by date
- Complete SwiftUI implementation with modern architecture
