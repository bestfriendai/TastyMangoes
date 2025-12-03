//
//  YouTubePlayerView.swift
//  TastyMangoes
//
//  Created by Claude on 2025-12-02 at 8:45 AM (Pacific Time)
//  Modified by Claude on 2025-12-02 at 6:15 PM (Pacific Time)
//
//  Changes (6:15 PM):
//  - Simplified to open YouTube externally (app or Safari)
//  - SFSafariViewController had entitlement issues with free provisioning
//  - External opening is most reliable and allows fullscreen/landscape in YouTube app
//

import SwiftUI

// MARK: - Trailer Player Helper

struct TrailerPlayerSheet: View {
    let videoId: String
    let movieTitle: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Color.clear
            .onAppear {
                openYouTube()
                dismiss()
            }
    }
    
    private func openYouTube() {
        // Try YouTube app first, then fall back to Safari
        let youtubeAppURL = URL(string: "youtube://watch?v=\(videoId)")!
        let youtubeWebURL = URL(string: "https://www.youtube.com/watch?v=\(videoId)")!
        
        if UIApplication.shared.canOpenURL(youtubeAppURL) {
            UIApplication.shared.open(youtubeAppURL)
        } else {
            UIApplication.shared.open(youtubeWebURL)
        }
    }
}

// MARK: - Preview

#Preview {
    TrailerPlayerSheet(videoId: "dQw4w9WgXcQ", movieTitle: "Sample Movie")
}
