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
            } else if let movieStringId = movieStringId {
                movieDetail = try await service.fetchMovieDetail(stringId: movieStringId)
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
