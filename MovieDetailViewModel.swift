//
//  MovieDetailViewModel.swift
//  TastyMangoes
//
//  Created by Claude on 11/13/25 at 7:02 PM
//

import Foundation
import SwiftUI
import Combine

// MARK: - View Model

@MainActor
class MovieDetailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var movie: MovieDetail?
    @Published var isLoading = false
    @Published var error: MovieDetailError?
    @Published var selectedTab: MovieTab = .overview
    @Published var similarMovies: [Movie] = []
    @Published var movieImages: [TMDBImage] = []
    @Published var movieVideos: [TMDBVideo] = []
    
    // MARK: - Properties
    
    private let service: MovieDetailService
    private let movieId: Int?
    private let movieStringId: String?
    
    // MARK: - Initialization
    
    nonisolated init(movieId: Int, service: MovieDetailService? = nil) {
        self.movieId = movieId
        self.movieStringId = nil
        self.service = service ?? MovieDetailService.shared
    }
    
    nonisolated init(movieStringId: String, service: MovieDetailService? = nil) {
        self.movieId = nil
        self.movieStringId = movieStringId
        self.service = service ?? MovieDetailService.shared
    }
    
    // MARK: - Public Methods
    
    func loadMovie() async {
        isLoading = true
        error = nil
        
        do {
            let movieDetail: MovieDetail
            
            if let movieId = movieId {
                movieDetail = try await service.fetchMovieDetail(id: movieId)
                
                // Load additional data in parallel
                // TODO: Re-enable similar movies once recommendation logic is improved
                // _ = await loadSimilarMovies(movieId: movieId)
                _ = await loadMovieImages(movieId: movieId)
                _ = await loadMovieVideos(movieId: movieId)
            } else if let movieStringId = movieStringId {
                movieDetail = try await service.fetchMovieDetail(stringId: movieStringId)
                
                // If we can convert string ID to Int, load additional data
                if let movieId = Int(movieStringId) {
                    // TODO: Re-enable similar movies once recommendation logic is improved
                    // _ = await loadSimilarMovies(movieId: movieId)
                    _ = await loadMovieImages(movieId: movieId)
                    _ = await loadMovieVideos(movieId: movieId)
                }
            } else {
                throw MovieDetailError.invalidData
            }
            
            self.movie = movieDetail
        } catch let detailError as MovieDetailError {
            self.error = detailError
            print("❌ Error loading movie: \(detailError.localizedDescription)")
        } catch {
            self.error = .invalidData
            print("❌ Unexpected error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    // TODO: Re-enable similar movies once recommendation logic is improved
    // Similar movies feature is completely disabled - no API calls, no UI display
    /*
    private func loadSimilarMovies(movieId: Int) async {
        do {
            // First, get the MovieCard to retrieve similar_movie_ids
            let movieCard = try await SupabaseService.shared.fetchMovieCard(tmdbId: movieId)
            
            // If we have similar movie IDs, use our endpoint
            if let similarIds = movieCard.similarMovieIds, !similarIds.isEmpty {
                let similarResults = try await SupabaseService.shared.fetchSimilarMovies(tmdbIds: similarIds)
                
                // Convert SimilarMovieResult to Movie objects
                self.similarMovies = similarResults.prefix(6).map { result in
                    Movie(
                        id: String(result.tmdbId),
                        title: result.title,
                        year: result.year ?? 0,
                        trailerURL: nil,
                        trailerDuration: nil,
                        posterImageURL: result.posterUrl, // Already full URL from Supabase storage
                        tastyScore: nil,
                        aiScore: result.rating, // Convert from 0-100 scale to 0-10
                        genres: [],
                        rating: nil,
                        director: nil,
                        runtime: nil,
                        releaseDate: result.year != nil ? String(result.year!) : nil,
                        language: nil,
                        overview: nil
                    )
                }
            } else {
                // Fallback to TMDB API if no similar IDs in database
                print("⚠️ No similar_movie_ids found, falling back to TMDB API")
                let response = try await TMDBService.shared.getSimilarMovies(movieId: movieId)
                self.similarMovies = response.results.prefix(6).map { $0.toMovie() }
            }
        } catch {
            print("⚠️ Failed to load similar movies: \(error)")
            // Fallback to TMDB API on error
            do {
                let response = try await TMDBService.shared.getSimilarMovies(movieId: movieId)
                self.similarMovies = response.results.prefix(6).map { $0.toMovie() }
            } catch {
                print("⚠️ TMDB fallback also failed: \(error)")
            }
        }
    }
    */
    
    private func loadMovieImages(movieId: Int) async {
        do {
            // Try reading from cache first (no TMDB calls)
            let movieCard = try await SupabaseService.shared.fetchMovieCardFromCache(tmdbId: String(movieId))
            
            // If we have still images from the database, use them
            if let stillImageUrls = movieCard?.stillImages, !stillImageUrls.isEmpty {
                // Convert still image URLs to TMDBImage format
                self.movieImages = stillImageUrls.map { url in
                    TMDBImage(
                        filePath: url, // Full URL from Supabase storage
                        width: nil,
                        height: nil,
                        aspectRatio: nil,
                        voteAverage: nil,
                        voteCount: nil
                    )
                }
                print("✅ Loaded \(self.movieImages.count) still images from database cache (no TMDB call)")
                return
            }
            
            // Fallback to get-movie-card function (may trigger TMDB)
            print("⚠️ No still_images in cache, trying get-movie-card (may trigger TMDB)")
            let movieCardFromFunction = try await SupabaseService.shared.fetchMovieCard(tmdbId: movieId)
            
            if let stillImageUrls = movieCardFromFunction.stillImages, !stillImageUrls.isEmpty {
                self.movieImages = stillImageUrls.map { url in
                    TMDBImage(
                        filePath: url,
                        width: nil,
                        height: nil,
                        aspectRatio: nil,
                        voteAverage: nil,
                        voteCount: nil
                    )
                }
                print("✅ Loaded \(self.movieImages.count) still images from get-movie-card")
                return
            }
            
            // Final fallback to TMDB API if no still images in database
            print("⚠️ No still_images found, falling back to TMDB API")
            let response = try await TMDBService.shared.getMovieImages(movieId: movieId)
            self.movieImages = Array(response.backdrops.prefix(6)) + Array(response.posters.prefix(6))
        } catch {
            print("⚠️ Failed to load movie images: \(error)")
            // Fallback to TMDB API on error
            do {
                let response = try await TMDBService.shared.getMovieImages(movieId: movieId)
                self.movieImages = Array(response.backdrops.prefix(6)) + Array(response.posters.prefix(6))
            } catch {
                print("⚠️ TMDB fallback also failed: \(error)")
            }
        }
    }
    
    private func loadMovieVideos(movieId: Int) async {
        do {
            // Try reading from cache first (no TMDB calls)
            let movieCard = try await SupabaseService.shared.fetchMovieCardFromCache(tmdbId: String(movieId))
            
            // If we have trailers from the database, use them
            if let trailers = movieCard?.trailers, !trailers.isEmpty {
                // Convert MovieClip array to TMDBVideo format for existing UI
                // Use custom thumbnail URL from Supabase storage if available
                self.movieVideos = trailers.map { clip in
                    TMDBVideo(
                        id: clip.key, // Use key as ID
                        key: clip.key,
                        name: clip.name,
                        site: "YouTube",
                        size: 1080, // Default size
                        type: clip.type,
                        official: true,
                        publishedAt: "", // Empty string as placeholder
                        customThumbnailURL: clip.thumbnailUrl // Use Supabase storage URL
                    )
                }
                print("✅ Loaded \(self.movieVideos.count) videos from database cache (no TMDB call)")
                return
            }
            
            // Fallback to get-movie-card function (may trigger TMDB)
            print("⚠️ No trailers in cache, trying get-movie-card (may trigger TMDB)")
            let movieCardFromFunction = try await SupabaseService.shared.fetchMovieCard(tmdbId: movieId)
            
            if let trailers = movieCardFromFunction.trailers, !trailers.isEmpty {
                self.movieVideos = trailers.map { clip in
                    TMDBVideo(
                        id: clip.key,
                        key: clip.key,
                        name: clip.name,
                        site: "YouTube",
                        size: 1080,
                        type: clip.type,
                        official: true,
                        publishedAt: "",
                        customThumbnailURL: clip.thumbnailUrl
                    )
                }
                print("✅ Loaded \(self.movieVideos.count) videos from get-movie-card")
                return
            }
            
            // Final fallback to TMDB API if no trailers in database
            print("⚠️ No trailers found, falling back to TMDB API")
            let response = try await TMDBService.shared.getMovieVideos(movieId: movieId)
            self.movieVideos = response.results.filter { 
                $0.type == "Clip" || $0.type == "Teaser" || $0.type == "Behind the Scenes" 
            }.prefix(5).map { $0 }
        } catch {
            print("⚠️ Failed to load movie videos: \(error)")
            // Fallback to TMDB API on error
            do {
                let response = try await TMDBService.shared.getMovieVideos(movieId: movieId)
                self.movieVideos = response.results.filter { 
                    $0.type == "Clip" || $0.type == "Teaser" || $0.type == "Behind the Scenes" 
                }.prefix(5).map { $0 }
            } catch {
                print("⚠️ TMDB fallback also failed: \(error)")
            }
        }
    }
    
    func retry() {
        Task {
            await loadMovie()
        }
    }
    
    func selectTab(_ tab: MovieTab) {
        selectedTab = tab
    }
    
    // MARK: - Computed Properties
    
    var hasError: Bool {
        error != nil
    }
    
    var errorMessage: String {
        error?.localizedDescription ?? "An unknown error occurred"
    }
    
    var displayedCast: [CastMember] {
        movie?.cast?.prefix(10).map { $0 } ?? []
    }
    
    var displayedCrew: [CrewMember] {
        let crew = movie?.crew ?? []
        // Get key crew members: Director, Writer, Producer, Cinematographer, etc.
        let keyJobs = ["Director", "Writer", "Screenplay", "Producer", "Director of Photography", "Editor", "Original Music Composer"]
        return crew.filter { keyJobs.contains($0.job) }.prefix(10).map { $0 }
    }
    
    var directorName: String {
        movie?.director ?? "Unknown"
    }
    
    var writersNames: String {
        let writers = movie?.crew?.filter { $0.job == "Writer" || $0.job == "Screenplay" } ?? []
        return writers.map { $0.name }.joined(separator: ", ")
    }
}

// MARK: - Movie Tab Enum

enum MovieTab: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case cast = "Cast"
    case crew = "Crew"
    case reviews = "Reviews"
    case similar = "Similar"
    
    var id: String { rawValue }
}

// MARK: - Mock for Previews

extension MovieDetailViewModel {
    static func mock() -> MovieDetailViewModel {
        let vm = MovieDetailViewModel(movieId: 550)
        vm.movie = .mock()
        return vm
    }
    
    static func mockLoading() -> MovieDetailViewModel {
        let vm = MovieDetailViewModel(movieId: 550)
        vm.isLoading = true
        return vm
    }
    
    static func mockError() -> MovieDetailViewModel {
        let vm = MovieDetailViewModel(movieId: 550)
        vm.error = .movieNotFound(550)
        return vm
    }
}
