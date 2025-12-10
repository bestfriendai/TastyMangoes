//
//  YouTubePlayerView.swift
//  TastyMangoes
//
//  Created by Claude on 2025-12-02 at 8:45 AM (Pacific Time)
//  Last modified by Claude on 2025-12-09 at 21:15 (America/Los_Angeles - Pacific Time)
//
//  Changes (2025-12-09):
//  - Simplified to open YouTube directly (like Movie Clips)
//  - No preview sheet - tapping trailer opens YouTube app immediately
//  - iOS shows "◀ TastyMangoes" back button automatically
//

import SwiftUI

// MARK: - Trailer Player Sheet

struct TrailerPlayerSheet: View {
    let videoId: String
    let movieTitle: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Color.clear
            .onAppear {
                openInYouTube()
                dismiss()
            }
    }
    
    private func openInYouTube() {
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
    TrailerPlayerSheet(videoId: "6ZfuNTqbHE8", movieTitle: "Wicked")
}
