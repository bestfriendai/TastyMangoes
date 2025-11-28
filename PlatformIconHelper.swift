//  PlatformIconHelper.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 19:00 (America/Los_Angeles - Pacific Time)
//  Notes: Helper utility for loading streaming platform icons from Assets.xcassets

import SwiftUI

struct PlatformIconHelper {
    /// Returns the asset name for a given platform's icon
    /// These should match the image set names in Assets.xcassets
    static func iconName(for platform: String) -> String {
        switch platform {
        case "Netflix":
            return "netflix-logo"
        case "Prime Video":
            return "prime-video-logo"
        case "Disney+":
            return "disney-plus-logo"
        case "Max":
            return "max-logo"
        case "Hulu":
            return "hulu-logo"
        case "Criterion":
            return "criterion-logo"
        case "Paramount+":
            return "paramount-plus-logo"
        case "Apple TV+":
            return "apple-tv-plus-logo"
        case "Peacock":
            return "peacock-logo"
        case "Tubi":
            return "tubi-logo"
        default:
            return "platform-placeholder"
        }
    }
    
    /// Returns an Image view for the platform, with fallback to colored box if image not found
    static func icon(for platform: String, size: CGFloat = 24) -> some View {
        let imageName = iconName(for: platform)
        
        // Try to load the image from Assets
        if let uiImage = UIImage(named: imageName) {
            return AnyView(
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            )
        } else {
            // Fallback to colored box with letter (existing behavior)
            return AnyView(
                PlatformLogoFallback(platform: platform, size: size)
            )
        }
    }
}

// Fallback view that shows colored box with letter when image is not available
struct PlatformLogoFallback: View {
    let platform: String
    let size: CGFloat
    
    var body: some View {
        Group {
            switch platform {
            case "Netflix":
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#E50914"))
                    Text("N")
                        .font(.custom("Nunito-Bold", size: size * 0.6))
                        .foregroundColor(.white)
                }
            case "Prime Video":
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#00A8E1"))
                    Text("P")
                        .font(.custom("Nunito-Bold", size: size * 0.6))
                        .foregroundColor(.white)
                }
            case "Disney+":
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#113CCF"))
                    Text("D")
                        .font(.custom("Nunito-Bold", size: size * 0.6))
                        .foregroundColor(.white)
                }
            case "Max":
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#000000"))
                    Text("M")
                        .font(.custom("Nunito-Bold", size: size * 0.6))
                        .foregroundColor(.white)
                }
            case "Hulu":
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#1CE783"))
                    Text("H")
                        .font(.custom("Nunito-Bold", size: size * 0.6))
                        .foregroundColor(.white)
                }
            case "Criterion":
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#000000"))
                    Text("C")
                        .font(.custom("Nunito-Bold", size: size * 0.5))
                        .foregroundColor(.white)
                }
            case "Paramount+":
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#0064FF"))
                    Text("P+")
                        .font(.custom("Nunito-Bold", size: size * 0.4))
                        .foregroundColor(.white)
                }
            case "Apple TV+":
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#000000"))
                    VStack(spacing: 1) {
                        Text("tv")
                            .font(.custom("Nunito-Bold", size: size * 0.35))
                            .foregroundColor(.white)
                        Text("+")
                            .font(.custom("Nunito-Bold", size: size * 0.3))
                            .foregroundColor(.white)
                    }
                }
            case "Peacock":
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#6A1B9A"), Color(hex: "#1976D2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("P")
                        .font(.custom("Nunito-Bold", size: size * 0.6))
                        .foregroundColor(.white)
                }
            case "Tubi":
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#FA2B31"))
                    Text("T")
                        .font(.custom("Nunito-Bold", size: size * 0.6))
                        .foregroundColor(.white)
                }
            default:
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#E0E0E0"))
                    Text(platform.prefix(1))
                        .font(.custom("Nunito-Bold", size: size * 0.5))
                        .foregroundColor(Color(hex: "#333333"))
                }
            }
        }
        .frame(width: size, height: size)
    }
}





