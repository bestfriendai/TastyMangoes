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
                async let similarMoviesTask = loadSimilarMovies(movieId: movieId)
                async let imagesTask = loadMovieImages(movieId: movieId)
                async let videosTask = loadMovieVideos(movieId: movieId)
                
                // Wait for all to complete
                _ = try? await (similarMoviesTask, imagesTask, videosTask)
            } else if let movieStringId = movieStringId {
                movieDetail = try await service.fetchMovieDetail(stringId: movieStringId)
                
                // If we can convert string ID to Int, load additional data
                if let movieId = Int(movieStringId) {
                    async let similarMoviesTask = loadSimilarMovies(movieId: movieId)
                    async let imagesTask = loadMovieImages(movieId: movieId)
                    async let videosTask = loadMovieVideos(movieId: movieId)
                    
                    _ = try? await (similarMoviesTask, imagesTask, videosTask)
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
    
    private func loadSimilarMovies(movieId: Int) async {
        do {
            let response = try await TMDBService.shared.getSimilarMovies(movieId: movieId)
            self.similarMovies = response.results.prefix(6).map { $0.toMovie() }
        } catch {
            print("⚠️ Failed to load similar movies: \(error)")
        }
    }
    
    private func loadMovieImages(movieId: Int) async {
        do {
            let response = try await TMDBService.shared.getMovieImages(movieId: movieId)
            // Combine backdrops and posters, prefer backdrops for photos section
            self.movieImages = Array(response.backdrops.prefix(6)) + Array(response.posters.prefix(6))
        } catch {
            print("⚠️ Failed to load movie images: \(error)")
        }
    }
    
    private func loadMovieVideos(movieId: Int) async {
        do {
            let response = try await TMDBService.shared.getMovieVideos(movieId: movieId)
            // Filter for clips and teasers (exclude trailers as we show those separately)
            self.movieVideos = response.results.filter { 
                $0.type == "Clip" || $0.type == "Teaser" || $0.type == "Behind the Scenes" 
            }.prefix(5).map { $0 }
        } catch {
            print("⚠️ Failed to load movie videos: \(error)")
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
