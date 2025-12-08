//  PosterCarouselView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 16:00 (America/Los_Angeles - Pacific Time)
//  Notes: Full-screen poster carousel view with swipe navigation for movie posters, backdrops, and photos

import SwiftUI

struct PosterCarouselView: View {
    let movie: MovieDetail
    let movieImages: [TMDBImage]
    let initialIndex: Int
    @Binding var isPresented: Bool
    @State private var currentIndex: Int
    @GestureState private var dragOffset: CGFloat = 0
    
    init(movie: MovieDetail, movieImages: [TMDBImage], initialIndex: Int, isPresented: Binding<Bool>) {
        self.movie = movie
        self.movieImages = movieImages
        self.initialIndex = initialIndex
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    // Build array of all images: poster, backdrop, then photos
    private var allImages: [ImageItem] {
        var images: [ImageItem] = []
        
        // Add poster first
        if let posterURL = movie.posterURL {
            images.append(ImageItem(url: posterURL, type: .poster))
        }
        
        // Add backdrop second
        if let backdropURL = movie.backdropURL {
            images.append(ImageItem(url: backdropURL, type: .backdrop))
        }
        
        // Add movie photos
        for image in movieImages {
            if let url = image.imageURL {
                images.append(ImageItem(url: url, type: .photo))
            }
        }
        
        return images
    }
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            // Image carousel
            if !allImages.isEmpty {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(0..<allImages.count, id: \.self) { index in
                            AsyncImage(url: allImages[index].url) { phase in
                                switch phase {
                                case .empty:
                                    Rectangle()
                                        .fill(Color(hex: "#333333"))
                                        .overlay(
                                            ProgressView()
                                                .tint(.white)
                                        )
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                case .failure:
                                    Rectangle()
                                        .fill(Color(hex: "#333333"))
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundColor(.white.opacity(0.5))
                                                .font(.system(size: 48))
                                        )
                                @unknown default:
                                    Rectangle()
                                        .fill(Color(hex: "#333333"))
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                        }
                    }
                    .frame(width: geometry.size.width * CGFloat(allImages.count))
                    .offset(x: -CGFloat(currentIndex) * geometry.size.width + dragOffset)
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.width
                            }
                            .onEnded { value in
                                let threshold: CGFloat = 50
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if value.translation.width > threshold && currentIndex > 0 {
                                        currentIndex -= 1
                                    } else if value.translation.width < -threshold && currentIndex < allImages.count - 1 {
                                        currentIndex += 1
                                    }
                                }
                            }
                    )
                }
                
                // Close button - positioned on top
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            isPresented = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                    }
                    Spacer()
                }
                
                // Page indicator
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(0..<allImages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.bottom, 40)
                }
            } else {
                // Fallback if no images
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 64))
                        .foregroundColor(.white.opacity(0.5))
                    Text("No images available")
                        .font(.custom("Inter-Regular", size: 16))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 16)
                }
            }
        }
        .onAppear {
            // Ensure we're within bounds
            let safeIndex = min(max(initialIndex, 0), max(0, allImages.count - 1))
            currentIndex = safeIndex
            print("🖼️ [PosterCarousel] onAppear - initialIndex: \(initialIndex), safeIndex: \(safeIndex), allImages.count: \(allImages.count)")
        }
        .onChange(of: initialIndex) { oldValue, newValue in
            // Update currentIndex when initialIndex changes (e.g., when tapping different images)
            let safeIndex = min(max(newValue, 0), max(0, allImages.count - 1))
            currentIndex = safeIndex
            print("🖼️ [PosterCarousel] onChange - oldValue: \(oldValue), newValue: \(newValue), safeIndex: \(safeIndex)")
        }
    }
}

// MARK: - Image Item

private struct ImageItem {
    let url: URL
    let type: ImageType
    
    enum ImageType {
        case poster
        case backdrop
        case photo
    }
}
