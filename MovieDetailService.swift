//
//  MovieDetailService.swift
//  TastyMangoes
//
//  Fixed - 11/14/25 at 10:45 PM
//

import Foundation

// MARK: - Movie Detail Service

enum MovieDetailError: Error, LocalizedError {
    case fileNotFound
    case invalidData
    case decodingError(Error)
    case networkError(Error)
    case movieNotFound(Int)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Could not find the movies data file"
        case .invalidData:
            return "The movie data is invalid"
        case .decodingError(let error):
            return "Failed to decode movie data: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .movieNotFound(let id):
            return "Movie with ID \(id) not found"
        }
    }
}

class MovieDetailService {
    
    // MARK: - Properties
    
    nonisolated static let shared = MovieDetailService()
    
    // Thread-safe cache using NSCache
    private let movieCache = NSCache<NSNumber, MovieDetailWrapper>()
    private let stringIdCache = NSCache<NSString, MovieDetailWrapper>()
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Fetch movie detail by Int ID
    func fetchMovieDetail(id: Int) async throws -> MovieDetail {
        // Check cache first
        if let cached = movieCache.object(forKey: NSNumber(value: id)) {
            return cached.movieDetail
        }
        
        // Try TMDB API first
        do {
            let movieDetail = try await fetchFromTMDB(movieId: id)
            
            // Cache the result
            movieCache.setObject(MovieDetailWrapper(movieDetail: movieDetail), forKey: NSNumber(value: id))
            
            return movieDetail
        } catch {
            print("⚠️ TMDB API failed for ID \(id), falling back to JSON: \(error)")
        }
        
        // Fall back to JSON
        let movie = try await loadFromJSON(id: id)
        
        // Cache the result
        movieCache.setObject(MovieDetailWrapper(movieDetail: movie), forKey: NSNumber(value: id))
        
        return movie
    }
    
    /// Fetch movie detail by String ID
    func fetchMovieDetail(stringId: String) async throws -> MovieDetail {
        // Check cache first
        if let cached = stringIdCache.object(forKey: stringId as NSString) {
            return cached.movieDetail
        }
        
        // Try to convert string ID to Int for TMDB API
        if let movieId = Int(stringId) {
            // Fetch from TMDB API
            do {
                let movieDetail = try await fetchFromTMDB(movieId: movieId)
                
                // Cache the result
                stringIdCache.setObject(MovieDetailWrapper(movieDetail: movieDetail), forKey: stringId as NSString)
                movieCache.setObject(MovieDetailWrapper(movieDetail: movieDetail), forKey: NSNumber(value: movieId))
                
                return movieDetail
            } catch {
                print("⚠️ TMDB API failed for string ID \(stringId), falling back to JSON: \(error)")
            }
        }
        
        // Fall back to loading from JSON
        let movie = try await loadFromJSON(stringId: stringId)
        
        // Cache the result
        stringIdCache.setObject(MovieDetailWrapper(movieDetail: movie), forKey: stringId as NSString)
        
        return movie
    }
    
    /// Load all movies from JSON file
    func loadAllMovies() async throws -> [MovieDetail] {
        let movies = try await loadMoviesFromJSON()
        
        // Cache all movies
        for movie in movies {
            movieCache.setObject(MovieDetailWrapper(movieDetail: movie), forKey: NSNumber(value: movie.id))
        }
        
        return movies
    }
    
    /// Clear the cache
    func clearCache() {
        movieCache.removeAllObjects()
        stringIdCache.removeAllObjects()
    }
    
    // MARK: - Private Methods - TMDB API
    
    private func fetchFromTMDB(movieId: Int) async throws -> MovieDetail {
        // Fetch movie details and credits in parallel from TMDB
        async let movieDetailResponse = TMDBService.shared.getMovieDetails(movieId: movieId)
        async let creditsResponse = TMDBService.shared.getMovieCredits(movieId: movieId)
        
        do {
            let (detail, credits) = try await (movieDetailResponse, creditsResponse)
            
            // Convert to our MovieDetail model
            let movieDetail = detail.toMovieDetail(credits: credits)
            
            return movieDetail
        } catch {
            throw MovieDetailError.networkError(error)
        }
    }
    
    // MARK: - Private Methods - JSON Loading
    
    private func loadFromJSON(id: Int) async throws -> MovieDetail {
        let movies = try await loadMoviesFromJSON()
        
        guard let movie = movies.first(where: { $0.id == id }) else {
            throw MovieDetailError.movieNotFound(id)
        }
        
        return movie
    }
    
    private func loadFromJSON(stringId: String) async throws -> MovieDetail {
        guard let url = Bundle.main.url(forResource: "movies", withExtension: "json") else {
            throw MovieDetailError.fileNotFound
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            
            let movies = try decoder.decode([Movie].self, from: data)
            
            guard let movie = movies.first(where: { $0.id == stringId }) else {
                throw MovieDetailError.movieNotFound(stringId.hashValue)
            }
            
            // Convert Movie to MovieDetail
            var movieDetail: MovieDetail = movie.toMovieDetail()
            // Store the original string ID
            movieDetail.stringId = stringId
            
            return movieDetail
            
        } catch let error as DecodingError {
            print("❌ Decoding error: \(error)")
            throw MovieDetailError.decodingError(error)
        } catch {
            throw MovieDetailError.decodingError(error)
        }
    }
    
    private func loadMoviesFromJSON() async throws -> [MovieDetail] {
        guard let url = Bundle.main.url(forResource: "movies", withExtension: "json") else {
            throw MovieDetailError.fileNotFound
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            
            // Try to decode as array first
            if let movies = try? decoder.decode([MovieDetail].self, from: data) {
                return movies
            }
            
            // If that fails, try as single object
            if let movie = try? decoder.decode(MovieDetail.self, from: data) {
                return [movie]
            }
            
            throw MovieDetailError.invalidData
            
        } catch let error as DecodingError {
            print("❌ Decoding error: \(error)")
            throw MovieDetailError.decodingError(error)
        } catch {
            throw MovieDetailError.decodingError(error)
        }
    }
}

// MARK: - Cache Wrapper

private class MovieDetailWrapper {
    let movieDetail: MovieDetail
    
    init(movieDetail: MovieDetail) {
        self.movieDetail = movieDetail
    }
}

// MARK: - Non-Actor Wrapper for SwiftUI Previews

class MovieDetailServiceWrapper {
    static func mockFetchMovieDetail(id: Int) async throws -> MovieDetail {
        // For previews, return mock data
        return MovieDetail.mock()
    }
}
