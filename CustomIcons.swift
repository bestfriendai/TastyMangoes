//
//  CustomIcons.swift
//  TastyMangoes
//
//  Created to match Figma designs - 11/14/25 10:26pm
//

import SwiftUI

// MARK: - Mango Logo Icon Component (matches Figma Icon / Mango Logo Color)
struct MangoLogoIcon: View {
    let size: CGFloat
    var color: Color? = nil // Optional: if nil, uses default colors; if set, uses that color
    
    var body: some View {
        ZStack {
            // Mango body (yellow/orange gradient area or solid color) - drawn first so stem appears on top
            Path { path in
                // Create a rounded mango shape
                path.move(to: CGPoint(x: size * 0.5, y: size * 0.2))
                path.addCurve(
                    to: CGPoint(x: size * 0.8, y: size * 0.5),
                    control1: CGPoint(x: size * 0.7, y: size * 0.25),
                    control2: CGPoint(x: size * 0.85, y: size * 0.35)
                )
                path.addCurve(
                    to: CGPoint(x: size * 0.5, y: size * 0.8),
                    control1: CGPoint(x: size * 0.75, y: size * 0.65),
                    control2: CGPoint(x: size * 0.65, y: size * 0.75)
                )
                path.addCurve(
                    to: CGPoint(x: size * 0.2, y: size * 0.5),
                    control1: CGPoint(x: size * 0.35, y: size * 0.75),
                    control2: CGPoint(x: size * 0.15, y: size * 0.65)
                )
                path.addCurve(
                    to: CGPoint(x: size * 0.5, y: size * 0.2),
                    control1: CGPoint(x: size * 0.25, y: size * 0.35),
                    control2: CGPoint(x: size * 0.3, y: size * 0.25)
                )
                path.closeSubpath()
            }
            .fill(
                color != nil
                    ? AnyShapeStyle(color!)
                    : AnyShapeStyle(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(hex: "#FFC966"),
                                Color(hex: "#FF9933")
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            
            // Stem/Leaf part (green or specified color) - drawn on top
            Path { path in
                // Leaf shape at the top
                path.move(to: CGPoint(x: size * 0.4, y: size * 0.05))
                path.addCurve(
                    to: CGPoint(x: size * 0.65, y: size * 0.35),
                    control1: CGPoint(x: size * 0.5, y: size * 0.05),
                    control2: CGPoint(x: size * 0.65, y: size * 0.2)
                )
                path.addCurve(
                    to: CGPoint(x: size * 0.4, y: size * 0.05),
                    control1: CGPoint(x: size * 0.65, y: size * 0.25),
                    control2: CGPoint(x: size * 0.5, y: size * 0.15)
                )
                path.closeSubpath()
            }
            .fill(color ?? Color(hex: "#648d00"))
        }
        .frame(width: size, height: size)
        .clipped()
    }
}

// MARK: - AI Filled Icon Component (matches Figma Icon / AI Filled)
struct AIFilledIcon: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Brain/chip icon shape
            Path { path in
                // Outer circuit-like shape
                path.move(to: CGPoint(x: size * 0.1354, y: size * 0.1146))
                
                // Top left corner
                path.addLine(to: CGPoint(x: size * 0.3, y: size * 0.1146))
                path.addCurve(
                    to: CGPoint(x: size * 0.35, y: size * 0.15),
                    control1: CGPoint(x: size * 0.3, y: size * 0.1146),
                    control2: CGPoint(x: size * 0.33, y: size * 0.125)
                )
                
                // Top right corner
                path.addLine(to: CGPoint(x: size * 0.7, y: size * 0.15))
                path.addCurve(
                    to: CGPoint(x: size * 0.8646, y: size * 0.1146),
                    control1: CGPoint(x: size * 0.75, y: size * 0.125),
                    control2: CGPoint(x: size * 0.8646, y: size * 0.1146)
                )
                
                // Right side
                path.addLine(to: CGPoint(x: size * 0.8646, y: size * 0.5))
                
                // Bottom right corner
                path.addCurve(
                    to: CGPoint(x: size * 0.7, y: size * 0.85),
                    control1: CGPoint(x: size * 0.8646, y: size * 0.7),
                    control2: CGPoint(x: size * 0.8, y: size * 0.8)
                )
                
                // Bottom left corner
                path.addLine(to: CGPoint(x: size * 0.3, y: size * 0.85))
                path.addCurve(
                    to: CGPoint(x: size * 0.1354, y: size * 0.5),
                    control1: CGPoint(x: size * 0.2, y: size * 0.8),
                    control2: CGPoint(x: size * 0.1354, y: size * 0.7)
                )
                
                // Close path
                path.addLine(to: CGPoint(x: size * 0.1354, y: size * 0.1146))
            }
            .fill(Color(hex: "#FEA500"))
            
            // Inner circuit details
            Circle()
                .fill(Color(hex: "#FEA500").opacity(0.3))
                .frame(width: size * 0.25, height: size * 0.25)
                .offset(x: -size * 0.1, y: size * 0.05)
            
            Circle()
                .fill(Color(hex: "#FEA500").opacity(0.3))
                .frame(width: size * 0.25, height: size * 0.25)
                .offset(x: size * 0.1, y: -size * 0.05)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview for Testing
#Preview("Icons") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            VStack {
                MangoLogoIcon(size: 16.667)
                Text("Mango Logo")
                    .font(.caption)
            }
            
            VStack {
                AIFilledIcon(size: 20)
                Text("AI Icon")
                    .font(.caption)
            }
        }
        
        // Show in context similar to movie page
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    MangoLogoIcon(size: 16.667)
                    Text("Tasty Score")
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                }
                Text("64%")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#1a1a1a"))
            }
            
            Rectangle()
                .fill(Color(hex: "#ececec"))
                .frame(width: 1, height: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 2) {
                    AIFilledIcon(size: 20)
                    Text("AI Score")
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                }
                Text("5.9")
                    .font(.custom("Nunito-Bold", size: 20))
                    .foregroundColor(Color(hex: "#1a1a1a"))
            }
        }
        .padding()
        .background(Color.white)
    }
}
