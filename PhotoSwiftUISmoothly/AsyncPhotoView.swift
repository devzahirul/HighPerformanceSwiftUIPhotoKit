//
//  AsyncPhotoView.swift
//  PhotoSwiftUISmoothly
//
//  Created by lynkto_1 on 6/20/25.
//

import SwiftUI
import UIKit
import Photos

struct AsyncPhotoView: View {
    let asset: PhotoAsset
    let targetSize: CGSize
    let cornerRadius: CGFloat
    
    @ObservedObject private var photoKitManager = PhotoKitManager.shared
    @State private var image: UIImage?
    @State private var isLoading = false
    
    init(asset: PhotoAsset, targetSize: CGSize = CGSize(width: 150, height: 150), cornerRadius: CGFloat = 8) {
        self.asset = asset
        self.targetSize = targetSize
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: targetSize.width, height: targetSize.height)
                    .clipped()
                    .cornerRadius(cornerRadius)
                    .overlay(
                        // Video indicator
                        asset.isVideo ? videoOverlay : nil
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: targetSize.width, height: targetSize.height)
                    .cornerRadius(cornerRadius)
                    .overlay(
                        Group {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                                    .font(.title2)
                            }
                        }
                    )
            }
        }
        .task {
            await loadImage()
        }
        .id(asset.id) // Ensure view updates when asset changes
    }
    
    private var videoOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.caption2)
                    Text(formatDuration(asset.duration))
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
                .padding(.trailing, 4)
                .padding(.bottom, 4)
            }
        }
    }
    
    private func loadImage() async {
        guard image == nil else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        image = await photoKitManager.loadThumbnail(for: asset, targetSize: targetSize)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    // Use a simple rectangle for preview instead of real PHAsset
    Rectangle()
        .fill(Color.gray.opacity(0.3))
        .frame(width: 150, height: 150)
        .cornerRadius(8)
        .overlay(
            Image(systemName: "photo")
                .foregroundColor(.gray)
                .font(.title2)
        )
}
