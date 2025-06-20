//
//  PhotoGridView.swift
//  PhotoSwiftUISmoothly
//
//  Created by lynkto_1 on 6/20/25.
//

import SwiftUI
import Photos

struct PhotoGridView: View {
    @ObservedObject private var photoManager = PhotoKitManager.shared
    @State private var selectedPhoto: PhotoAsset?
    @State private var showingPermissionAlert = false
    @State private var showingPerformanceSettings = false
    @State private var searchText = ""
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    private let thumbnailSize = CGSize(width: 120, height: 120)
    
    var filteredPhotos: [PhotoAsset] {
        if searchText.isEmpty {
            return photoManager.photos
        } else {
            // Basic filtering by date - could be enhanced with metadata search
            return photoManager.photos.filter { asset in
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                return formatter.string(from: asset.creationDate).localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if photoManager.authorizationStatus == .authorized || photoManager.authorizationStatus == .limited {
                    photoContentView
                } else {
                    permissionView
                }
            }
            .navigationTitle("Photos")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(trailing: 
                Button {
                    showingPerformanceSettings = true
                } label: {
                    Image(systemName: "speedometer")
                }
            )
            .searchable(text: $searchText, prompt: "Search photos by date")
            .refreshable {
                await photoManager.loadPhotos()
            }
        }
        .alert("Photo Access Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please allow access to your photo library in Settings to view your photos.")
        }
        .sheet(item: $selectedPhoto) { photo in
            NavigationView {
                PhotoDetailView(asset: photo) {
                    print("🎬 PhotoDetailView onDismiss called")
                    selectedPhoto = nil
                }
            }
            .onAppear {
                print("🎬 Presenting PhotoDetailView for: \(photo.id)")
            }
        }
        .sheet(isPresented: $showingPerformanceSettings) {
            PerformanceSettingsView()
        }
    }
    
    private var photoContentView: some View {
        VStack(spacing: 0) {
            // Limited access banner
            if photoManager.authorizationStatus == .limited {
                limitedAccessBanner
            }
            
            if photoManager.isLoading && photoManager.photos.isEmpty {
                loadingView
            } else if photoManager.photos.isEmpty {
                emptyStateView
            } else {
                photoGrid
            }
        }
    }
    
    private var limitedAccessBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo.badge.plus")
                .foregroundColor(.orange)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Limited Photo Access")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Select more photos to include in this app")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Select More") {
                print("🔘 Limited access Select More button tapped")
                print("🔘 Current authorization status: \(photoManager.authorizationStatus.rawValue)")
                photoManager.presentLimitedLibraryPicker()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    private var photoGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(filteredPhotos) { asset in
                    AsyncPhotoView(
                        asset: asset,
                        targetSize: thumbnailSize,
                        cornerRadius: 0
                    )
                    .aspectRatio(1, contentMode: .fit)
                    .background(Color.clear) // Ensure tappable area
                    .contentShape(Rectangle()) // Make entire area tappable
                    .onTapGesture {
                        print("📱 Grid item tapped: \(asset.id)")
                        print("📱 Current selectedPhoto before: \(selectedPhoto?.id ?? "nil")")
                        
                        // Direct assignment - no delays or complex state management needed
                        // The sheet(item:) modifier will handle the presentation automatically
                        selectedPhoto = asset
                        print("📱 selectedPhoto set to: \(selectedPhoto?.id ?? "nil")")
                    }
                    .contextMenu {
                        contextMenuForAsset(asset)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .overlay(
            photoCountOverlay,
            alignment: .bottom
        )
    }
    
    private var photoCountOverlay: some View {
        HStack {
            Spacer()
            Text("\(filteredPhotos.count) photos")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemBackground).opacity(0.8))
                .cornerRadius(12)
                .padding()
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading photos...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Photos Found")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Your photo library appears to be empty or no photos match your search.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var permissionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 80))
                .foregroundColor(.orange)
            
            VStack(spacing: 12) {
                Text("Photo Access Required")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("This app needs access to your photo library to display your photos. Please grant permission to continue.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button("Grant Access") {
                Task {
                    await photoManager.requestPhotoAccess()
                    if photoManager.authorizationStatus == .denied {
                        showingPermissionAlert = true
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    @ViewBuilder
    private func contextMenuForAsset(_ asset: PhotoAsset) -> some View {
        Button {
            // Share functionality
            sharePhoto(asset)
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        
        Button {
            // Add to favorites (if needed)
            // This would require additional PHPhotoLibrary permissions
        } label: {
            Label("Favorite", systemImage: "heart")
        }
        
        Button(role: .destructive) {
            Task {
                try? await photoManager.deletePhoto(asset)
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private func sharePhoto(_ asset: PhotoAsset) {
        Task {
            if let image = await photoManager.loadFullSizeImage(for: asset) {
                await MainActor.run {
                    let activityController = UIActivityViewController(
                        activityItems: [image],
                        applicationActivities: nil
                    )
                    
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = windowScene.windows.first {
                        window.rootViewController?.present(activityController, animated: true)
                    }
                }
            }
        }
    }
}

#Preview {
    PhotoGridView()
}
