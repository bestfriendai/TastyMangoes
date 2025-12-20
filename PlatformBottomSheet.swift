//  PlatformBottomSheet.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 15:15 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-01-15 at 19:30 (America/Los_Angeles - Pacific Time)
//  Notes: Platform bottom sheet showing all available streaming platforms grouped by type (subscription, free, ads, rent, buy)

import SwiftUI

struct PlatformBottomSheet: View {
    @Binding var isPresented: Bool
    let streaming: StreamingInfo?
    
    init(isPresented: Binding<Bool>, streaming: StreamingInfo? = nil) {
        self._isPresented = isPresented
        self.streaming = streaming
    }
    
    // Group providers by type
    private var providerGroups: [(String, [StreamingProvider], String)] {
        guard let us = streaming?.us else { return [] }
        
        var groups: [(String, [StreamingProvider], String)] = []
        
        // Subscription streaming (most important)
        if let flatrate = us.flatrate, !flatrate.isEmpty {
            groups.append(("Subscription", flatrate, "Includes Netflix, Disney+, Max, etc."))
        }
        
        // Free streaming
        if let free = us.free, !free.isEmpty {
            groups.append(("Free", free, "No subscription required"))
        }
        
        // Free with ads
        if let ads = us.ads, !ads.isEmpty {
            groups.append(("Free with Ads", ads, "Watch with commercials"))
        }
        
        // Rent
        if let rent = us.rent, !rent.isEmpty {
            groups.append(("Rent", rent, "Rent for 48 hours"))
        }
        
        // Buy
        if let buy = us.buy, !buy.isEmpty {
            groups.append(("Buy", buy, "Purchase to own"))
        }
        
        return groups
    }
    
    private var hasProviders: Bool {
        !providerGroups.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#b3b3b3"))
                    .frame(width: 32, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Watch on")
                        .font(.custom("Nunito-Bold", size: 20))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                        .padding(.top, 8)
                    
                    if hasProviders {
                        // Grouped platform list
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(providerGroups, id: \.0) { group in
                                VStack(alignment: .leading, spacing: 12) {
                                    // Section header
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(group.0)
                                            .font(.custom("Nunito-Bold", size: 16))
                                            .foregroundColor(Color(hex: "#1a1a1a"))
                                        Text(group.2)
                                            .font(.custom("Inter-Regular", size: 12))
                                            .foregroundColor(Color(hex: "#666666"))
                                    }
                                    
                                    // Platform items
                                    VStack(spacing: 8) {
                                        ForEach(group.1) { provider in
                                            PlatformRow(provider: provider)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // No providers available
                        VStack(spacing: 12) {
                            Image(systemName: "tv.slash")
                                .font(.system(size: 48))
                                .foregroundColor(Color(hex: "#999999"))
                            Text("Not available for streaming")
                                .font(.custom("Inter-Regular", size: 16))
                                .foregroundColor(Color(hex: "#666666"))
                            if let link = streaming?.us?.link, let url = URL(string: link) {
                                Button(action: {
                                    UIApplication.shared.open(url)
                                }) {
                                    Text("View on TMDB")
                                        .font(.custom("Inter-SemiBold", size: 14))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color(hex: "#648d00"))
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.white)
        .cornerRadius(24, corners: [.topLeft, .topRight])
        .presentationDetents([.height(600)])
        .presentationDragIndicator(.hidden)
    }
}

// Platform row component
private struct PlatformRow: View {
    let provider: StreamingProvider
    
    var body: some View {
        HStack(spacing: 12) {
            // Logo
            AsyncImage(url: provider.logoURL) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 48, height: 48)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                        .background(Color.white)
                        .cornerRadius(8)
                case .failure:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "tv")
                                .foregroundColor(.gray)
                        )
                @unknown default:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 48, height: 48)
                }
            }
            
            // Provider name
            Text(provider.providerName)
                .font(.custom("Inter-SemiBold", size: 16))
                .foregroundColor(Color(hex: "#333333"))
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#999999"))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(hex: "#F5F5F5"))
        .cornerRadius(8)
    }
}

#Preview {
    PlatformBottomSheet(isPresented: .constant(true), streaming: nil)
}

