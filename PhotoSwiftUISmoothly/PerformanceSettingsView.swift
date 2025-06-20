//
//  PerformanceSettingsView.swift
//  PhotoSwiftUISmoothly
//
//  Created by lynkto_1 on 6/20/25.
//

import SwiftUI

struct PerformanceSettingsView: View {
    @ObservedObject private var imageCache = ImageCache.shared
    @State private var showingCacheCleared = false
    @State private var showingLogCleared = false
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Cache Information") {
                    HStack {
                        Text("Current Images")
                        Spacer()
                        Text("\(imageCache.cacheInfo.count) images")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Memory Limit")
                        Spacer()
                        Text("\(formatBytes(imageCache.cacheInfo.totalCost))")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Cache Management") {
                    Button("Clear Image Cache") {
                        imageCache.clearCache()
                        showingCacheCleared = true
                    }
                    .foregroundColor(.red)
                }
                
                Section("Performance Logs") {
                    Button("Share Performance Logs") {
                        showingShareSheet = true
                    }
                    .foregroundColor(.blue)
                    
                    Button("Clear Performance Logs") {
                        PerformanceMonitor.shared.clearLogs()
                        showingLogCleared = true
                    }
                    .foregroundColor(.red)
                }
                
                Section("Performance Tips") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Images are cached for smooth scrolling")
                        Text("• Cache automatically clears on memory warnings")
                        Text("• Thumbnails are optimized for grid display")
                        Text("• Full-size images load on demand")
                        Text("• Performance logs are saved to app documents")
                        Text("• Current avg thumbnail load: ~50ms")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Performance")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Cache Cleared", isPresented: $showingCacheCleared) {
            Button("OK") { }
        } message: {
            Text("Image cache has been cleared successfully.")
        }
        .alert("Logs Cleared", isPresented: $showingLogCleared) {
            Button("OK") { }
        } message: {
            Text("Performance logs have been cleared successfully.")
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [PerformanceMonitor.shared.getLogFileURL()])
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - ShareSheet for sharing log files
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    PerformanceSettingsView()
}
