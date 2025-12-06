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
        
        // Try reading directly from work_cards_cache first (no TMDB calls, instant)
        // Use the SupabaseService method that reads from cache directly
        do {
            if let movieCard = try await SupabaseService.shared.fetchMovieCardFromCache(tmdbId: String(id)) {
                var movieDetail = movieCard.toMovieDetail()
                
                print("🎬 [MovieDetailService] Loaded MovieCard for \(id), cast count: \(movieDetail.cast?.count ?? 0), crew count: \(movieDetail.crew?.count ?? 0)")
                
                // Fetch full crew data from works_meta
                do {
                    if let crew = try await SupabaseService.shared.fetchCrewMembers(workId: movieCard.workId) {
                        print("✅ [MovieDetailService] Fetched \(crew.count) crew members from works_meta")
                        movieDetail = movieDetail.withCrew(crew)
                        print("✅ [MovieDetailService] Updated movieDetail with crew, new crew count: \(movieDetail.crew?.count ?? 0)")
                    } else {
                        print("⚠️ [MovieDetailService] No crew members found in works_meta for workId: \(movieCard.workId)")
                    }
                } catch {
                    print("❌ [MovieDetailService] Error fetching crew: \(error)")
                }
                
                // Cache the result
                movieCache.setObject(MovieDetailWrapper(movieDetail: movieDetail), forKey: NSNumber(value: id))
                
                print("[MOVIE DETAIL] Loaded movie \(id) from work_cards_cache (no TMDB call)")
                return movieDetail
            }
        } catch {
            print("⚠️ [MOVIE DETAIL] work_cards_cache read failed for ID \(id), trying get-movie-card: \(error)")
        }
        
            // Fallback to get-movie-card function (may trigger TMDB if movie not in DB)
            // NOTE: This should rarely happen if movies are already ingested.
            // Watchlist movies should always have cache entries - if we reach here from watchlist,
            // it indicates a data inconsistency that should be investigated.
            do {
                print("[TMDB CALL] MovieDetailService falling back to get-movie-card for ID \(id) (may trigger TMDB)")
                let movieCard = try await SupabaseService.shared.fetchMovieCard(tmdbId: id)
                var movieDetail = movieCard.toMovieDetail()
                
                // Fetch full crew data from works_meta
                if let crew = try await SupabaseService.shared.fetchCrewMembers(workId: movieCard.workId) {
                    movieDetail = movieDetail.withCrew(crew)
                }
                
                // Cache the result
                movieCache.setObject(MovieDetailWrapper(movieDetail: movieDetail), forKey: NSNumber(value: id))
                
                return movieDetail
            } catch {
                print("⚠️ Supabase get-movie-card failed for ID \(id), falling back to TMDB: \(error)")
            }
        
        // Fallback to TMDB API
        // NOTE: This is a true fallback - movie not in Supabase cache or get-movie-card failed.
        // Should be rare for movies that are already in watchlist/database.
        do {
            print("[TMDB CALL] MovieDetailService fetching fresh details from TMDB for tmdbId=\(id)")
            let movieDetail = try await fetchFromTMDB(movieId: id)
            
            // Cache the result
            movieCache.setObject(MovieDetailWrapper(movieDetail: movieDetail), forKey: NSNumber(value: id))
            
            return movieDetail
        } catch {
            print("⚠️ TMDB API failed for ID \(id), falling back to JSON: \(error)")
        }
        
        // Final fallback to JSON
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
        
        // Try to convert string ID to Int for Supabase
        if let movieId = Int(stringId) {
            // Try reading directly from work_cards_cache first (no TMDB calls)
            do {
                if let movieCard = try await SupabaseService.shared.fetchMovieCardFromCache(tmdbId: stringId) {
                    var movieDetail = movieCard.toMovieDetail()
                    
                    // Fetch full crew data from works_meta
                    if let crew = try await SupabaseService.shared.fetchCrewMembers(workId: movieCard.workId) {
                        movieDetail = MovieDetail(
                            id: movieDetail.id,
                            title: movieDetail.title,
                            originalTitle: movieDetail.originalTitle,
                            overview: movieDetail.overview,
                            releaseDate: movieDetail.releaseDate,
                            posterPath: movieDetail.posterPath,
                            backdropPath: movieDetail.backdropPath,
                            runtime: movieDetail.runtime,
                            genres: movieDetail.genres,
                            director: movieDetail.director,
                            rating: movieDetail.rating,
                            tastyScore: movieDetail.tastyScore,
                            aiScore: movieDetail.aiScore,
                            criticsScore: movieDetail.criticsScore,
                            audienceScore: movieDetail.audienceScore,
                            trailerURL: movieDetail.trailerURL,
                            trailerYoutubeId: movieDetail.trailerYoutubeId,
                            trailerDuration: movieDetail.trailerDuration,
                            cast: movieDetail.cast,
                            crew: crew, // Use full crew from works_meta
                            budget: movieDetail.budget,
                            revenue: movieDetail.revenue,
                            tagline: movieDetail.tagline,
                            status: movieDetail.status,
                            voteAverage: movieDetail.voteAverage,
                            voteCount: movieDetail.voteCount,
                            popularity: movieDetail.popularity
                        )
                    }
                    
                    // Cache the result
                    stringIdCache.setObject(MovieDetailWrapper(movieDetail: movieDetail), forKey: stringId as NSString)
                    movieCache.setObject(MovieDetailWrapper(movieDetail: movieDetail), forKey: NSNumber(value: movieId))
                    
                    print("[MOVIE DETAIL] Loaded movie \(stringId) from work_cards_cache (no TMDB call)")
                    return movieDetail
                }
            } catch {
                print("⚠️ [MOVIE DETAIL] work_cards_cache read failed for string ID \(stringId): \(error)")
            }
            
            // Fallback to get-movie-card function (may trigger TMDB if movie not in DB)
            // NOTE: This should rarely happen if movies are already ingested.
            // Watchlist movies should always have cache entries - if we reach here from watchlist,
            // it indicates a data inconsistency that should be investigated.
            do {
                print("[TMDB CALL] MovieDetailService falling back to get-movie-card for string ID \(stringId) (may trigger TMDB)")
                let movieCard = try await SupabaseService.shared.fetchMovieCard(tmdbId: movieId)
                var movieDetail = movieCard.toMovieDetail()
                
                // Fetch full crew data from works_meta
                if let crew = try await SupabaseService.shared.fetchCrewMembers(workId: movieCard.workId) {
                    movieDetail = movieDetail.withCrew(crew)
                }
                
                // Cache the result
                stringIdCache.setObject(MovieDetailWrapper(movieDetail: movieDetail), forKey: stringId as NSString)
                movieCache.setObject(MovieDetailWrapper(movieDetail: movieDetail), forKey: NSNumber(value: movieId))
                
                return movieDetail
            } catch {
                print("⚠️ Supabase get-movie-card failed for string ID \(stringId), falling back to TMDB: \(error)")
            }
            
            // Fallback to TMDB API
            // NOTE: This is a true fallback - movie not in Supabase cache or get-movie-card failed.
            // Should be rare for movies that are already in watchlist/database.
            do {
                print("[TMDB CALL] MovieDetailService fetching fresh details from TMDB for stringId=\(stringId)")
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
