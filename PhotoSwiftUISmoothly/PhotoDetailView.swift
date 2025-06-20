//
//  PhotoDetailView.swift
//  PhotoSwiftUISmoothly
//
//  Created by lynkto_1 on 6/20/25.
//

import SwiftUI
import Photos

struct PhotoDetailView: View {
    let asset: PhotoAsset
    let onDismiss: () -> Void
    
    @ObservedObject private var photoManager = PhotoKitManager.shared
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showingInfoSheet = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Navigation bar
                navigationBar
                
                Spacer()
                
                // Photo content
                photoContent
                
                Spacer()
                
                // Bottom controls
                bottomControls
            }
        }
        .task {
            print("🖼️ PhotoDetailView task started for asset: \(asset.id)")
            await loadFullSizeImage()
        }
        .sheet(isPresented: $showingInfoSheet) {
            photoInfoSheet
        }
        .onAppear {
            print("🖼️ PhotoDetailView appeared for asset: \(asset.id)")
        }
        .onDisappear {
            print("🖼️ PhotoDetailView disappeared")
        }
    }
    
    private var navigationBar: some View {
        HStack {
            Button("Done") {
                onDismiss()
            }
            .foregroundColor(.white)
            .font(.body)
            
            Spacer()
            
            Button {
                showingInfoSheet = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundColor(.white)
                    .font(.title2)
            }
        }
        .padding()
    }
    
    private var photoContent: some View {
        Group {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            } else if let image = image {
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .clipped()
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let newScale = lastScale * value
                                        scale = max(1.0, min(newScale, 5.0))
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        if scale <= 1.0 {
                                            withAnimation(.spring()) {
                                                scale = 1.0
                                                offset = .zero
                                            }
                                            lastScale = 1.0
                                            lastOffset = .zero
                                        }
                                    },
                                
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1.0 {
                                            offset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastScale = 1.0
                                    lastOffset = .zero
                                } else {
                                    scale = 2.0
                                    lastScale = 2.0
                                }
                            }
                        }
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    
                    Text("Failed to load image")
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }
        }
    }
    
    private var bottomControls: some View {
        HStack(spacing: 40) {
            Button {
                shareImage()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            Button {
                // Add to favorites functionality
            } label: {
                Image(systemName: "heart")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            Button {
                deletePhoto()
            } label: {
                Image(systemName: "trash")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
    
    private var photoInfoSheet: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Photo metadata
                VStack(alignment: .leading, spacing: 12) {
                    Text("Photo Information")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let image = image {
                        InfoRow(title: "Dimensions", value: "\(Int(image.size.width)) × \(Int(image.size.height))")
                    }
                    
                    InfoRow(title: "Date Created", value: formatDate(asset.creationDate))
                    
                    if let location = asset.location {
                        InfoRow(title: "Location", value: "\(location.coordinate.latitude), \(location.coordinate.longitude)")
                    }
                    
                    if asset.isVideo {
                        InfoRow(title: "Duration", value: formatDuration(asset.duration))
                        InfoRow(title: "Media Type", value: "Video")
                    } else {
                        InfoRow(title: "Media Type", value: "Photo")
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                showingInfoSheet = false
            })
        }
    }
    
    private func loadFullSizeImage() async {
        isLoading = true
        image = await photoManager.loadFullSizeImage(for: asset)
        isLoading = false
    }
    
    private func shareImage() {
        guard let image = image else { return }
        
        let activityController = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }
    
    private func deletePhoto() {
        Task {
            try? await photoManager.deletePhoto(asset)
            await MainActor.run {
                onDismiss()
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
    }
}

#Preview {
    // Simple preview without real PHAsset
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Text("Photo Detail View Preview")
                .foregroundColor(.white)
                .font(.title)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 200, height: 200)
                .cornerRadius(8)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                        .font(.system(size: 50))
                )
        }
    }
}
