//  YouTubePlayerView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-06 at 08:37 (America/Los_Angeles - Pacific Time)
//  Updated on: 2025-12-06 at 09:42 (America/Los_Angeles - Pacific Time)
//  Notes: Simplified to use UIViewControllerRepresentable presenting SFSafariViewController directly for fast, reliable performance

import SwiftUI
import SafariServices

// MARK: - Trailer Player Helper

struct TrailerPlayerSheet: UIViewControllerRepresentable {
    let videoId: String
    let movieTitle: String
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        guard !videoId.isEmpty else {
            // Fallback URL if videoId is empty
            let fallbackURL = URL(string: "https://www.youtube.com")!
            return SFSafariViewController(url: fallbackURL)
        }
        
        let youtubeURL = URL(string: "https://www.youtube.com/watch?v=\(videoId)&autoplay=1")!
        
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = false
        
        let safariVC = SFSafariViewController(url: youtubeURL, configuration: config)
        
        // Configure appearance
        if #available(iOS 26.0, *) {
            // Use new API if available in future iOS versions
        } else {
            safariVC.preferredBarTintColor = UIColor(hex: "#1a1a1a")
            safariVC.preferredControlTintColor = .white
        }
        
        // Set delegate to handle dismissal
        safariVC.delegate = context.coordinator
        
        return safariVC
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }
    
    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onDismiss: () -> Void
        
        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }
        
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onDismiss()
        }
    }
}

// MARK: - UIColor Extension for Hex

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    TrailerPlayerSheet(
        videoId: "dQw4w9WgXcQ",
        movieTitle: "Sample Movie",
        onDismiss: {}
    )
}
