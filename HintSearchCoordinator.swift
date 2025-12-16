//  HintSearchCoordinator.swift
//  TastyMangoes
//
//  Created by Claude on 2025-12-15 at 20:15 (America/Los_Angeles - Pacific Time)
//  Last modified by Claude: 2025-12-15 at 21:00 (America/Los_Angeles - Pacific Time) / 05:00 UTC
//  Notes: Coordinates hint-based movie search across local database, AI discovery, and TMDB ingestion.
//         Shows local results instantly, then enriches with AI-discovered movies.
//  Fixes: Added import Combine, fixed type conversions for tmdbId and posterURL

import Foundation
import Combine

// MARK: - Search Result Models

/// A movie result from hint-based search
struct HintSearchResult: Identifiable {
    let tmdbId: Int
    let title: String
    let year: Int?
    let posterURL: String?
    let source: ResultSource
    let matchReason: String?
    
    var id: Int { tmdbId }
    
    enum ResultSource: String {
        case local = "local"           // Already in our database
        case aiDiscovered = "ai"       // Found by AI, may need ingestion
        case aiIngested = "ingested"   // Found by AI and just ingested
    }
}

/// Progress state for UI updates
enum HintSearchProgress {
    case idle
    case searchingLocal
    case localComplete(count: Int)
    case searchingAI
    case aiComplete(count: Int, newCount: Int)
    case ingesting(current: Int, total: Int)
    case complete
    case error(String)
}

/// Full search response
struct HintSearchResponse {
    let query: String
    let hints: ExtractedMovieHints?
    let localResults: [HintSearchResult]
    let aiResults: [HintSearchResult]
    let allResults: [HintSearchResult]  // Deduplicated, merged
    let newlyIngested: Int
    let aiCostCents: Double?
}

// MARK: - Hint Search Coordinator

@MainActor
class HintSearchCoordinator: ObservableObject {
    static let shared = HintSearchCoordinator()
    
    @Published var progress: HintSearchProgress = .idle
    @Published var localResults: [HintSearchResult] = []
    @Published var allResults: [HintSearchResult] = []
    @Published var isSearching = false
    
    private init() {}
    
    // MARK: - Main Search Method
    
    /// Performs a hint-aware search: local first, then AI discovery with ingestion
    /// - Parameters:
    ///   - query: The raw user query/utterance
    ///   - hints: Pre-extracted hints (optional, will extract if nil)
    ///   - enableAI: Whether to use AI discovery (default true)
    /// - Returns: Complete search response with all results
    func search(
        query: String,
        hints: ExtractedMovieHints? = nil,
        enableAI: Bool = true
    ) async throws -> HintSearchResponse {
        
        isSearching = true
        progress = .searchingLocal
        
        // Step 1: Extract hints if not provided
        let searchHints = hints ?? extractHints(from: query)
        
        #if DEBUG
        print("🔍 [HintSearch] Query: \"\(query)\"")
        if let h = searchHints, h.hasHints {
            print("🔍 [HintSearch] Hints: actor=\(h.actors.isEmpty ? "nil" : h.actors.joined(separator: ", ")), director=\(h.director ?? "nil"), year=\(h.year?.description ?? "nil")")
        }
        #endif
        
        // Step 2: Search local database (instant)
        let localMovies = try await searchLocal(query: query, hints: searchHints)
        localResults = localMovies
        allResults = localMovies
        progress = .localComplete(count: localMovies.count)
        
        #if DEBUG
        print("🔍 [HintSearch] Local results: \(localMovies.count)")
        #endif
        
        // Step 3: AI discovery (if enabled and hints present)
        var aiMovies: [HintSearchResult] = []
        var newlyIngested = 0
        var aiCost: Double? = nil
        
        if enableAI, let hints = searchHints, hints.hasHints {
            progress = .searchingAI
            
            do {
                // Call AI discovery service
                let aiResponse = try await AIDiscoveryService.shared.discoverMovies(
                    query: query,
                    hints: hints
                )
                
                #if DEBUG
                print("🤖 [HintSearch] AI found \(aiResponse.movies.count) movies")
                #endif
                
                // Calculate cost (placeholder until we track tokens)
                aiCost = 0.05 // ~$0.0005 per query for gpt-4o-mini
                
                // Step 4: Filter out movies we already have locally
                let localTmdbIds = Set(localMovies.map { $0.tmdbId })
                let newAIMovies = aiResponse.movies.filter { suggestion in
                    guard let tmdbId = suggestion.tmdbId else { return false }
                    return !localTmdbIds.contains(tmdbId)
                }
                
                #if DEBUG
                print("🤖 [HintSearch] New movies to ingest: \(newAIMovies.count)")
                #endif
                
                // Step 5: Ingest new movies
                if !newAIMovies.isEmpty {
                    let (ingestedResults, successCount) = await ingestMovies(newAIMovies)
                    aiMovies = ingestedResults
                    newlyIngested = successCount
                    
                    progress = .aiComplete(count: aiResponse.movies.count, newCount: successCount)
                } else {
                    // AI found movies but they're all in local DB already
                    aiMovies = aiResponse.movies.compactMap { suggestion in
                        guard let tmdbId = suggestion.tmdbId else { return nil }
                        return HintSearchResult(
                            tmdbId: tmdbId,
                            title: suggestion.title,
                            year: suggestion.year,
                            posterURL: nil,
                            source: .aiDiscovered,
                            matchReason: suggestion.reason
                        )
                    }
                    progress = .aiComplete(count: aiMovies.count, newCount: 0)
                }
                
            } catch {
                #if DEBUG
                print("⚠️ [HintSearch] AI discovery failed: \(error)")
                #endif
                // Don't fail the whole search if AI fails
            }
        }
        
        // Step 5: Merge and deduplicate results
        let merged = mergeResults(local: localMovies, ai: aiMovies)
        allResults = merged
        
        progress = .complete
        isSearching = false
        
        return HintSearchResponse(
            query: query,
            hints: searchHints,
            localResults: localMovies,
            aiResults: aiMovies,
            allResults: merged,
            newlyIngested: newlyIngested,
            aiCostCents: aiCost
        )
    }
    
    // MARK: - Local Search
    
    /// Search local Supabase database for movies matching hints
    private func searchLocal(query: String, hints: ExtractedMovieHints?) async throws -> [HintSearchResult] {
        // For now, use the existing search infrastructure
        // TODO: Add direct JSONB queries for cast/crew filtering
        
        var results: [HintSearchResult] = []
        
        // If we have a likely title, search for it
        let searchQuery = hints?.titleLikely ?? query
        
        do {
            // Use existing search endpoint
            let searchResults = try await SupabaseService.shared.searchMovies(query: searchQuery)
            
            // Filter by hints if present
            for movie in searchResults {
                var matchReason: String? = nil
                
                // For now, include all search results
                // TODO: Filter by actor/director/year when we have that data in search results
                if hints?.year != nil && movie.year == hints?.year {
                    matchReason = "Year match"
                }
                
                // Convert tmdbId from String to Int
                guard let tmdbIdInt = Int(movie.tmdbId) else {
                    #if DEBUG
                    print("⚠️ [HintSearch] Skipping movie with invalid tmdbId: \(movie.tmdbId)")
                    #endif
                    continue
                }
                
                results.append(HintSearchResult(
                    tmdbId: tmdbIdInt,
                    title: movie.title,
                    year: movie.year,
                    posterURL: movie.posterUrl,
                    source: .local,
                    matchReason: matchReason
                ))
            }
            
            // If we have actor/director hints, also search our local works_meta
            if let hints = hints, !hints.actors.isEmpty {
                let actorResults = try await searchByActor(actors: hints.actors, titleHint: hints.titleLikely)
                
                // Add any results not already in the list
                let existingIds = Set(results.map { $0.tmdbId })
                for result in actorResults {
                    if !existingIds.contains(result.tmdbId) {
                        results.append(result)
                    }
                }
            }
            
            if let director = hints?.director {
                let directorResults = try await searchByDirector(director: director)
                
                let existingIds = Set(results.map { $0.tmdbId })
                for result in directorResults {
                    if !existingIds.contains(result.tmdbId) {
                        results.append(result)
                    }
                }
            }
            
        } catch {
            #if DEBUG
            print("⚠️ [HintSearch] Local search error: \(error)")
            #endif
        }
        
        return results
    }
    
    /// Search local database by actor name using JSONB query
    private func searchByActor(actors: [String], titleHint: String?) async throws -> [HintSearchResult] {
        // Build SQL query to search cast_members JSONB
        // This queries works + works_meta tables
        
        // TODO: Implement direct JSONB query via SupabaseService.executeSQL()
        // For now, we'll skip this and rely on AI discovery
        
        for actor in actors {
            #if DEBUG
            print("🔍 [HintSearch] Would search for actor: \(actor)")
            #endif
        }
        
        return []
    }
    
    /// Search local database by director name
    private func searchByDirector(director: String) async throws -> [HintSearchResult] {
        // Similar to searchByActor but for crew_members where job = 'Director'
        #if DEBUG
        print("🔍 [HintSearch] Would search for director: \(director)")
        #endif
        return []
    }
    
    // MARK: - Ingestion
    
    /// Ingest multiple movies from AI suggestions
    private func ingestMovies(_ suggestions: [AIMovieSuggestion]) async -> (results: [HintSearchResult], successCount: Int) {
        var results: [HintSearchResult] = []
        var successCount = 0
        
        for (index, suggestion) in suggestions.enumerated() {
            progress = .ingesting(current: index + 1, total: suggestions.count)
            
            guard let tmdbId = suggestion.tmdbId else {
                #if DEBUG
                print("⚠️ [HintSearch] Skipping \(suggestion.title) - no TMDB ID")
                #endif
                continue
            }
            
            do {
                // Call ingestMovie to fetch from TMDB and store locally
                let _ = try await SupabaseService.shared.ingestMovie(tmdbId: String(tmdbId))
                
                // Fetch the card to get poster URL
                let card = try await SupabaseService.shared.fetchMovieCardFromCache(tmdbId: String(tmdbId))
                
                // Extract poster URL from PosterUrls struct (use medium size)
                let posterURLString = card?.poster?.medium ?? card?.poster?.small ?? card?.poster?.large
                
                results.append(HintSearchResult(
                    tmdbId: tmdbId,
                    title: suggestion.title,
                    year: suggestion.year,
                    posterURL: posterURLString,
                    source: .aiIngested,
                    matchReason: suggestion.reason
                ))
                
                successCount += 1
                
                #if DEBUG
                print("✅ [HintSearch] Ingested: \(suggestion.title) (\(suggestion.year ?? 0))")
                #endif
                
            } catch {
                #if DEBUG
                print("⚠️ [HintSearch] Failed to ingest \(suggestion.title): \(error)")
                #endif
                
                // Still add to results as AI-discovered (will ingest when user views)
                results.append(HintSearchResult(
                    tmdbId: tmdbId,
                    title: suggestion.title,
                    year: suggestion.year,
                    posterURL: nil,
                    source: .aiDiscovered,
                    matchReason: suggestion.reason
                ))
            }
        }
        
        return (results, successCount)
    }
    
    // MARK: - Helpers
    
    /// Extract hints from query using MovieHintExtractor
    private func extractHints(from query: String) -> ExtractedMovieHints? {
        let extracted = MovieHintExtractor.extract(from: query)
        guard extracted.hasAnyHints else { return nil }
        return ExtractedMovieHints(from: extracted)
    }
    
    /// Merge local and AI results, deduplicating by tmdbId
    private func mergeResults(local: [HintSearchResult], ai: [HintSearchResult]) -> [HintSearchResult] {
        var merged: [HintSearchResult] = local
        let existingIds = Set(local.map { $0.tmdbId })
        
        for aiResult in ai {
            if !existingIds.contains(aiResult.tmdbId) {
                merged.append(aiResult)
            }
        }
        
        // Sort: local first, then by year descending
        merged.sort { result1, result2 in
            // Local results come first
            if result1.source == .local && result2.source != .local {
                return true
            }
            if result1.source != .local && result2.source == .local {
                return false
            }
            // Then sort by year (newest first)
            return (result1.year ?? 0) > (result2.year ?? 0)
        }
        
        return merged
    }
}
