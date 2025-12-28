//
//  TMDBService.swift
//  TastyMangoes
//
//  Fixed - 11/14/25 at 10:45 PM
//

import Foundation

// MARK: - TMDB Service Errors

enum TMDBError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

// MARK: - TMDB Service

class TMDBService {
    
    static let shared = TMDBService()
    
    private init() {}
    
    // MARK: - Search Movies
    
    /// Search for movies by query string
    func searchMovies(query: String, page: Int = 1) async throws -> TMDBSearchResponse {
        var components = URLComponents(string: "\(TMDBConfig.baseURL)/search/movie")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: TMDBConfig.apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "language", value: "en-US")
        ]
        
        guard let url = components?.url else {
            throw TMDBError.invalidURL
        }
        
        return try await performRequest(url: url)
    }
    
    // MARK: - Get Movie Details
    
    /// Get full details for a specific movie
    func getMovieDetails(movieId: Int) async throws -> TMDBMovieDetail {
        var components = URLComponents(string: "\(TMDBConfig.baseURL)/movie/\(movieId)")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: TMDBConfig.apiKey),
            URLQueryItem(name: "language", value: "en-US")
        ]
        
        guard let url = components?.url else {
            throw TMDBError.invalidURL
        }
        
        return try await performRequest(url: url)
    }
    
    // MARK: - Get Movie Credits
    
    /// Get cast and crew for a specific movie
    func getMovieCredits(movieId: Int) async throws -> TMDBCredits {
        var components = URLComponents(string: "\(TMDBConfig.baseURL)/movie/\(movieId)/credits")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: TMDBConfig.apiKey),
            URLQueryItem(name: "language", value: "en-US")
        ]
        
        guard let url = components?.url else {
            throw TMDBError.invalidURL
        }
        
        return try await performRequest(url: url)
    }
    
    // MARK: - Get Popular Movies
    
    /// Get popular movies
    func getPopularMovies(page: Int = 1) async throws -> TMDBSearchResponse {
        var components = URLComponents(string: "\(TMDBConfig.baseURL)/movie/popular")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: TMDBConfig.apiKey),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "language", value: "en-US")
        ]
        
        guard let url = components?.url else {
            throw TMDBError.invalidURL
        }
        
        return try await performRequest(url: url)
    }
    
    // MARK: - Get Trending Movies
    
    /// Get trending movies
    func getTrendingMovies(timeWindow: String = "week") async throws -> TMDBSearchResponse {
        var components = URLComponents(string: "\(TMDBConfig.baseURL)/trending/movie/\(timeWindow)")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: TMDBConfig.apiKey),
            URLQueryItem(name: "language", value: "en-US")
        ]
        
        guard let url = components?.url else {
            throw TMDBError.invalidURL
        }
        
        return try await performRequest(url: url)
    }
    
    // MARK: - Get Similar Movies
    
    /// Get similar movies for a specific movie
    func getSimilarMovies(movieId: Int, page: Int = 1) async throws -> TMDBSearchResponse {
        var components = URLComponents(string: "\(TMDBConfig.baseURL)/movie/\(movieId)/similar")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: TMDBConfig.apiKey),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "language", value: "en-US")
        ]
        
        guard let url = components?.url else {
            throw TMDBError.invalidURL
        }
        
        return try await performRequest(url: url)
    }
    
    // MARK: - Get Movie Images
    
    /// Get images (posters, backdrops) for a specific movie
    func getMovieImages(movieId: Int) async throws -> TMDBImagesResponse {
        var components = URLComponents(string: "\(TMDBConfig.baseURL)/movie/\(movieId)/images")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: TMDBConfig.apiKey)
        ]
        
        guard let url = components?.url else {
            throw TMDBError.invalidURL
        }
        
        return try await performRequest(url: url)
    }
    
    // MARK: - Get Movie Videos
    
    /// Get videos (trailers, clips) for a specific movie
    func getMovieVideos(movieId: Int) async throws -> TMDBVideosResponse {
        var components = URLComponents(string: "\(TMDBConfig.baseURL)/movie/\(movieId)/videos")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: TMDBConfig.apiKey),
            URLQueryItem(name: "language", value: "en-US")
        ]
        
        guard let url = components?.url else {
            throw TMDBError.invalidURL
        }
        
        return try await performRequest(url: url)
    }
    
    // MARK: - Search Person
    
    /// Search for a person by name
    func searchPerson(name: String, page: Int = 1) async throws -> TMDBSearchPersonResponse {
        var components = URLComponents(string: "\(TMDBConfig.baseURL)/search/person")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: TMDBConfig.apiKey),
            URLQueryItem(name: "query", value: name),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "language", value: "en-US")
        ]
        
        guard let url = components?.url else {
            throw TMDBError.invalidURL
        }
        
        return try await performRequest(url: url)
    }
    
    // MARK: - Get Person Movie Credits
    
    /// Get all movies a person has appeared in
    func getPersonMovieCredits(personId: Int) async throws -> TMDBCreditsResponse {
        var components = URLComponents(string: "\(TMDBConfig.baseURL)/person/\(personId)/movie_credits")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: TMDBConfig.apiKey),
            URLQueryItem(name: "language", value: "en-US")
        ]
        
        guard let url = components?.url else {
            throw TMDBError.invalidURL
        }
        
        return try await performRequest(url: url)
    }
    
    // MARK: - Private Helper
    
    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw TMDBError.invalidResponse
            }
            
            guard (200...299).contains(httpResponse.statusCode) else {
                throw TMDBError.apiError("Status code: \(httpResponse.statusCode)")
            }
            
            let decoder = JSONDecoder()
            
            do {
                let result = try decoder.decode(T.self, from: data)
                return result
            } catch {
                print("❌ Decoding error: \(error)")
                print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
                throw TMDBError.decodingError(error)
            }
            
        } catch let error as TMDBError {
            throw error
        } catch {
            throw TMDBError.networkError(error)
        }
    }
}

// MARK: - MovieDetailService Extension

extension MovieDetailService {
    /// Fetch movie detail from TMDB API by Int ID
    func fetchMovieDetailFromTMDB(movieId: Int) async throws -> MovieDetail {
        let tmdbService = TMDBService.shared
        
        // Fetch movie details and credits in parallel
        async let movieDetail = tmdbService.getMovieDetails(movieId: movieId)
        async let credits = tmdbService.getMovieCredits(movieId: movieId)
        
        let (detail, creds) = try await (movieDetail, credits)
        
        return detail.toMovieDetail(credits: creds)
    }
}
