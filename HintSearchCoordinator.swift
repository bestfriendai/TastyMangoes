//  HintSearchCoordinator.swift
//  TastyMangoes
//
//  Created by Claude on 2025-12-15 at 20:15 (America/Los_Angeles - Pacific Time)
//  Last modified by Claude: 2025-12-15 at 21:30 (America/Los_Angeles - Pacific Time) / 05:30 UTC
//  Notes: Coordinates hint-based movie search across local database, AI discovery, and TMDB ingestion.
//         Shows local results instantly, then enriches with AI-discovered movies.
//  Fixes: Added import Combine, fixed type conversions for tmdbId and posterURL
//  Updates: Added TMDB ID verification - AI IDs are not trusted, we search TMDB by title+year
//           to get correct IDs before ingestion. Prevents hallucinated ID issues.

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
    let genres: [String]?
    let runtimeDisplay: String?
    let aiScore: Double?
    let voteAverage: Double? // TMDB score (0-10 scale) - used when aiScore is nil
    
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
    @Published var isAISearching = false
    @Published var verificationProgress: (current: Int, total: Int)? = nil
    
    private let tmdbService = TMDBService.shared
    
    // Track current search task to allow cancellation when new search starts
    private var currentSearchTask: Task<HintSearchResponse, Error>?
    
    private init() {}
    
    // MARK: - Main Search Method
    
    /// Performs a hint-aware search: local first, then AI discovery with ingestion
    /// - Parameters:
    ///   - query: The raw user query/utterance
    ///   - hints: Pre-extracted hints (optional, will extract if nil)
    ///   - enableAI: Whether to use AI discovery (default true)
    ///   - onProgress: Optional callback that receives incremental result updates
    /// - Returns: Complete search response with all results
    func search(
        query: String,
        hints: ExtractedMovieHints? = nil,
        enableAI: Bool = true,
        onProgress: (([HintSearchResult]) -> Void)? = nil
    ) async throws -> HintSearchResponse {
        
        // CRITICAL: Cancel any ongoing search/ingestion before starting a new one
        // This prevents old search results (e.g., "James Bond") from appearing in new searches (e.g., "Harry Potter")
        currentSearchTask?.cancel()
        
        // Clear previous results immediately when starting new search
        await MainActor.run {
            allResults = []
            localResults = []
            // IMPORTANT: Clear results in SearchViewModel immediately to prevent old results from showing
            // This fixes the issue where "James Bond" results show up when searching for "Harry Potter"
            onProgress?([])
            
            // Also clear SearchViewModel results directly if possible
            // The onProgress callback should handle this, but we do it here as a safety measure
            #if DEBUG
            print("🔄 [HintSearchCoordinator] Starting new search for '\(query)' - cancelled previous search and cleared results")
            #endif
        }
        
        isSearching = true
        
        // Wrap the entire search in a Task so we can track and cancel it
        let searchTask = Task {
            return try await performSearch(query: query, hints: hints, enableAI: enableAI, onProgress: onProgress)
        }
        
        currentSearchTask = searchTask
        
        do {
            return try await searchTask.value
        } catch is CancellationError {
            // Search was cancelled - return empty results
            #if DEBUG
            print("🔄 [HintSearchCoordinator] Search was cancelled")
            #endif
            await MainActor.run {
                isSearching = false
                progress = .idle
            }
            return HintSearchResponse(
                query: query,
                hints: hints,
                localResults: [],
                aiResults: [],
                allResults: [],
                newlyIngested: 0,
                aiCostCents: nil
            )
        }
    }
    
    /// Internal search implementation - wrapped by public search() method for cancellation support
    private func performSearch(
        query: String,
        hints: ExtractedMovieHints? = nil,
        enableAI: Bool = true,
        onProgress: (([HintSearchResult]) -> Void)? = nil
    ) async throws -> HintSearchResponse {
        progress = .searchingLocal
        verificationProgress = nil
        
        // Step 1: Extract hints if not provided
        let searchHints = hints ?? extractHints(from: query)
        
        #if DEBUG
        print("🔍 [HintSearch] Query: \"\(query)\"")
        if let h = searchHints, h.hasHints {
            print("🔍 [HintSearch] Hints: actor=\(h.actors.isEmpty ? "nil" : h.actors.joined(separator: ", ")), director=\(h.director ?? "nil"), author=\(h.author ?? "nil"), year=\(h.year?.description ?? "nil")")
        }
        #endif
        
        // Step 2: Search local database (instant)
        let localMovies = try await searchLocal(query: query, hints: searchHints)
        localResults = localMovies
        allResults = localMovies
        progress = .localComplete(count: localMovies.count)
        
        // Immediately call progress callback with local results
        onProgress?(localMovies)
        
        #if DEBUG
        print("🔍 [HintSearch] Local results: \(localMovies.count)")
        #endif
        
        // Step 3: AI discovery (if enabled)
        // Call AI if:
        // 1. Hints are present (director/actor/author/year), OR
        // 2. Local search returned 0 results (even without hints)
        var aiMovies: [HintSearchResult] = []
        var newlyIngested = 0
        var aiCost: Double? = nil
        
        // Determine search type and value from hints for cache checking
        var searchType: String? = nil
        var searchValue: String? = nil
        
        if let hints = searchHints {
            if let director = hints.director {
                searchType = "director"
                searchValue = director
            } else if let actor = hints.actors.first {
                searchType = "actor"
                searchValue = actor
            } else if let author = hints.author {
                searchType = "author"
                searchValue = author
            }
        }
        
        // Check if we've done this comprehensive search recently WITH results > 0
        // Fix 1: Only skip AI if cached search has movies (not 0 results)
        var shouldCallAI = true
        if let type = searchType, let value = searchValue {
            do {
                let hasRecent = try await SupabaseService.shared.hasRecentComprehensiveSearch(type: type, value: value)
                if hasRecent {
                    print("⏭️ [HintSearch] Skipping AI - recent comprehensive search with results exists for \(type): \(value)")
                    shouldCallAI = false
                } else {
                    print("✅ [HintSearch] Cache MISS or 0 results - will call AI for \(type): \(value)")
                }
            } catch {
                print("⚠️ [HintSearch] Error checking comprehensive search cache: \(error)")
                // Continue with AI on error
            }
        }
        
        // Call AI if:
        // 1. Hints are present (director/actor/author/year), OR
        // 2. Local search returned 0 results (fallback to AI even without hints), OR
        // 3. Local results don't match the year hint (e.g., user wants 2025 but we found old movies)
        let localResultsMatchYear: Bool = {
            guard let yearHint = searchHints?.year, !localMovies.isEmpty else { return true }
            // Check if any local result matches the year hint
            return localMovies.contains { $0.year == yearHint }
        }()
        
        let shouldUseAI = shouldCallAI && enableAI && (
            (searchHints?.hasHints ?? false) ||  // Has hints
            localMovies.isEmpty ||  // No local results - use AI as fallback
            !localResultsMatchYear  // Local results don't match year hint
        )
        
        #if DEBUG
        if shouldUseAI {
            if localMovies.isEmpty {
                print("🤖 [HintSearch] Will call AI - no local results found")
            } else if !localResultsMatchYear, let yearHint = searchHints?.year {
                print("🤖 [HintSearch] Will call AI - local results don't match year hint (\(yearHint))")
            } else if searchHints?.hasHints == true {
                print("🤖 [HintSearch] Will call AI - hints present")
            }
        } else {
            print("⏭️ [HintSearch] Skipping AI - shouldCallAI=\(shouldCallAI), enableAI=\(enableAI), hasHints=\(searchHints?.hasHints ?? false), localCount=\(localMovies.count), matchYear=\(localResultsMatchYear)")
        }
        #endif
        
        if shouldUseAI {
            isAISearching = true
            progress = .searchingAI
            
            // Create hints if we don't have any (for AI fallback when local search returns 0)
            let hintsForAI = searchHints ?? ExtractedMovieHints(
                titleLikely: query.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            do {
                // Call AI discovery service
                let aiResponse = try await AIDiscoveryService.shared.discoverMovies(
                    query: query,
                    hints: hintsForAI
                )
                
                #if DEBUG
                print("🤖 [HintSearch] AI found \(aiResponse.movies.count) movies")
                #endif
                
                // Calculate cost (placeholder until we track tokens)
                aiCost = 0.05 // ~$0.0005 per query for gpt-4o-mini
                
                // Step 4: Filter out movies we already have locally
                let localTmdbIds = Set(localMovies.map { $0.tmdbId })
                let newAIMovies = aiResponse.movies.filter { suggestion in
                    guard let tmdbId = suggestion.tmdbId else { return true } // Keep if no ID, we'll look it up
                    return !localTmdbIds.contains(tmdbId)
                }
                
                #if DEBUG
                print("🤖 [HintSearch] New movies to verify and ingest: \(newAIMovies.count)")
                #endif
                
                // Step 5: Verify TMDB IDs and ingest new movies with progressive updates
                if !newAIMovies.isEmpty {
                    let (ingestedResults, successCount) = await verifyAndIngestMovies(
                        newAIMovies,
                        onProgress: { [weak self] incrementalResults in
                            guard let self = self else { return }
                            // Check for cancellation before updating progress
                            guard !Task.isCancelled else {
                                #if DEBUG
                                print("🔄 [HintSearchCoordinator] Search cancelled - skipping progress update")
                                #endif
                                return
                            }
                            // Merge local + incremental AI results and call callback
                            let merged = self.mergeResults(local: localMovies, ai: incrementalResults)
                            onProgress?(merged)
                        }
                    )
                    aiMovies = ingestedResults
                    newlyIngested = successCount
                    
                    progress = .aiComplete(count: aiResponse.movies.count, newCount: successCount)
                    
                    // Save comprehensive search to cache after successful verification
                    if let type = searchType, let value = searchValue {
                        let tmdbIds = ingestedResults.map { String($0.tmdbId) }
                        do {
                            try await SupabaseService.shared.saveComprehensiveSearch(type: type, value: value, tmdbIds: tmdbIds)
                            print("💾 [HintSearch] Saved comprehensive search: \(type)=\(value), \(tmdbIds.count) movies")
                        } catch {
                            print("⚠️ [HintSearch] Failed to save comprehensive search: \(error)")
                            // Don't fail the search if cache save fails
                        }
                    }
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
                            matchReason: suggestion.reason,
                            genres: nil,
                            runtimeDisplay: nil,
                            aiScore: nil,
                            voteAverage: nil
                        )
                    }
                    progress = .aiComplete(count: aiMovies.count, newCount: 0)
                    verificationProgress = nil
                    
                    // Update results with AI-discovered movies (already in DB)
                    guard !Task.isCancelled else {
                        #if DEBUG
                        print("🔄 [HintSearchCoordinator] Search cancelled - skipping AI results update")
                        #endif
                        return HintSearchResponse(
                            query: query,
                            hints: searchHints,
                            localResults: localMovies,
                            aiResults: [],
                            allResults: localMovies,
                            newlyIngested: 0,
                            aiCostCents: nil
                        )
                    }
                    let merged = mergeResults(local: localMovies, ai: aiMovies)
                    onProgress?(merged)
                    
                    // Save comprehensive search to cache even if all movies were already in DB
                    if let type = searchType, let value = searchValue {
                        let tmdbIds = aiMovies.map { String($0.tmdbId) }
                        do {
                            try await SupabaseService.shared.saveComprehensiveSearch(type: type, value: value, tmdbIds: tmdbIds)
                            print("💾 [HintSearch] Saved comprehensive search: \(type)=\(value), \(tmdbIds.count) movies")
                        } catch {
                            print("⚠️ [HintSearch] Failed to save comprehensive search: \(error)")
                            // Don't fail the search if cache save fails
                        }
                    }
                }
                
            } catch {
                #if DEBUG
                print("⚠️ [HintSearch] AI discovery failed: \(error)")
                #endif
                // Don't fail the whole search if AI fails
                verificationProgress = nil
            }
            
            // TMDB Fallback: If AI returned 0 results, try direct TMDB title search
            if aiMovies.isEmpty && enableAI {
                print("🎬 [HintSearch] AI returned 0 - trying TMDB title search as fallback")
                
                // Extract the likely title from hints or use cleaned query
                let searchTitle: String
                if let titleLikely = searchHints?.titleLikely, !titleLikely.isEmpty {
                    searchTitle = titleLikely
                } else {
                    // Clean query: remove common words and trim
                    let cleanedQuery = query
                        .replacingOccurrences(of: "the movie", with: "", options: [.caseInsensitive])
                        .replacingOccurrences(of: "movie", with: "", options: [.caseInsensitive])
                        .replacingOccurrences(of: "film", with: "", options: [.caseInsensitive])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    searchTitle = cleanedQuery.isEmpty ? query : cleanedQuery
                }
                
                do {
                    // Call TMDB search API directly
                    let tmdbResponse = try await tmdbService.searchMovies(query: searchTitle, page: 1)
                    
                    if !tmdbResponse.results.isEmpty {
                        print("🎬 [HintSearch] TMDB fallback found \(tmdbResponse.results.count) movies - ingesting top results")
                        
                        // Ingest top 5 TMDB results
                        let topResults = Array(tmdbResponse.results.prefix(5))
                        var tmdbIngested: [HintSearchResult] = []
                        
                        for (index, tmdbMovie) in topResults.enumerated() {
                            progress = .ingesting(current: index + 1, total: topResults.count)
                            verificationProgress = (current: index + 1, total: topResults.count)
                            
                            print("🎬 [HintSearch] TMDB fallback: ingesting \(tmdbMovie.title) (TMDB ID: \(tmdbMovie.id))")
                            
                            do {
                                // Ingest the movie
                                let _ = try await SupabaseService.shared.ingestMovie(tmdbId: String(tmdbMovie.id))
                                
                                // Fetch the card to get full details
                                let card = try await SupabaseService.shared.fetchMovieCardFromCache(tmdbId: String(tmdbMovie.id))
                                
                                // Extract poster URL
                                let posterURLString = card?.poster?.medium ?? card?.poster?.small ?? card?.poster?.large
                                
                                // Extract year from release date if needed
                                let year: Int?
                                if let cardYear = card?.year {
                                    year = cardYear
                                } else if let releaseDate = tmdbMovie.releaseDate, let yearInt = Int(releaseDate.prefix(4)) {
                                    year = yearInt
                                } else {
                                    year = nil
                                }
                                
                                let result = HintSearchResult(
                                    tmdbId: tmdbMovie.id,
                                    title: card?.title ?? tmdbMovie.title,
                                    year: year,
                                    posterURL: posterURLString,
                                    source: .aiIngested,
                                    matchReason: "TMDB fallback search",
                                    genres: card?.genres,
                                    runtimeDisplay: card?.runtimeDisplay,
                        aiScore: card?.aiScore,
                        voteAverage: card?.sourceScores?.tmdb?.score
                    )
                                tmdbIngested.append(result)
                                newlyIngested += 1
                                
                                // Update results incrementally
                                let merged = mergeResults(local: localMovies, ai: tmdbIngested)
                                onProgress?(merged)
                                
                            } catch {
                                print("⚠️ [HintSearch] Failed to ingest TMDB movie \(tmdbMovie.title): \(error)")
                                // Continue with next movie
                            }
                        }
                        
                        // Add TMDB results to aiMovies
                        aiMovies = tmdbIngested
                        progress = .aiComplete(count: tmdbIngested.count, newCount: newlyIngested)
                        verificationProgress = nil
                        
                        // Update final results
                        let merged = mergeResults(local: localMovies, ai: aiMovies)
                        onProgress?(merged)
                        
                        print("🎬 [HintSearch] TMDB fallback completed: ingested \(tmdbIngested.count) movies")
                    } else {
                        print("🎬 [HintSearch] TMDB fallback also returned 0 results")
                        
                        // Actor fallback: If title search failed and we have an actor hint, search by actor
                        if let actorName = searchHints?.actors.first, !actorName.isEmpty {
                            print("🎬 [HintSearch] TMDB title search failed - trying TMDB person search for: \(actorName)")
                            
                            do {
                                // Step 1: Search for the person
                                let personSearchResponse = try await tmdbService.searchPerson(name: actorName, page: 1)
                                
                                if let person = personSearchResponse.results.first {
                                    print("🎬 [HintSearch] Found person: \(person.name) (ID: \(person.id))")
                                    
                                    // Step 2: Get their movie credits
                                    let creditsResponse = try await tmdbService.getPersonMovieCredits(personId: person.id)
                                    
                                    // Combine cast and crew movies, deduplicate by ID
                                    var allMovies: [TMDBMovie] = []
                                    var seenIds = Set<Int>()
                                    
                                    for movie in creditsResponse.cast {
                                        if !seenIds.contains(movie.id) {
                                            allMovies.append(movie)
                                            seenIds.insert(movie.id)
                                        }
                                    }
                                    
                                    for movie in creditsResponse.crew {
                                        if !seenIds.contains(movie.id) {
                                            allMovies.append(movie)
                                            seenIds.insert(movie.id)
                                        }
                                    }
                                    
                                    // Sort by popularity (if available) or release date, take top 10
                                    let sortedMovies = allMovies.sorted { movie1, movie2 in
                                        let pop1 = movie1.popularity ?? 0
                                        let pop2 = movie2.popularity ?? 0
                                        if pop1 != pop2 {
                                            return pop1 > pop2
                                        }
                                        // Fallback to release date
                                        let date1 = movie1.releaseDate ?? ""
                                        let date2 = movie2.releaseDate ?? ""
                                        return date1 > date2
                                    }
                                    
                                    let topMovies = Array(sortedMovies.prefix(10))
                                    
                                    if !topMovies.isEmpty {
                                        print("🎬 [HintSearch] TMDB person search found \(topMovies.count) movies for \(actorName)")
                                        
                                        var tmdbActorIngested: [HintSearchResult] = []
                                        
                                        for (index, tmdbMovie) in topMovies.enumerated() {
                                            progress = .ingesting(current: index + 1, total: topMovies.count)
                                            verificationProgress = (current: index + 1, total: topMovies.count)
                                            
                                            print("🎬 [HintSearch] TMDB fallback: ingesting \(tmdbMovie.title) (TMDB ID: \(tmdbMovie.id))")
                                            
                                            do {
                                                // Ingest the movie
                                                let _ = try await SupabaseService.shared.ingestMovie(tmdbId: String(tmdbMovie.id))
                                                
                                                // Fetch the card to get full details
                                                let card = try await SupabaseService.shared.fetchMovieCardFromCache(tmdbId: String(tmdbMovie.id))
                                                
                                                // Extract poster URL
                                                let posterURLString = card?.poster?.medium ?? card?.poster?.small ?? card?.poster?.large
                                                
                                                // Extract year from release date if needed
                                                let year: Int?
                                                if let cardYear = card?.year {
                                                    year = cardYear
                                                } else if let releaseDate = tmdbMovie.releaseDate, let yearInt = Int(releaseDate.prefix(4)) {
                                                    year = yearInt
                                                } else {
                                                    year = nil
                                                }
                                                
                                                let result = HintSearchResult(
                                                    tmdbId: tmdbMovie.id,
                                                    title: card?.title ?? tmdbMovie.title,
                                                    year: year,
                                                    posterURL: posterURLString,
                                                    source: .aiIngested,
                                                    matchReason: "TMDB actor fallback: \(actorName)",
                                                    genres: card?.genres,
                                                    runtimeDisplay: card?.runtimeDisplay,
                        aiScore: card?.aiScore,
                        voteAverage: card?.sourceScores?.tmdb?.score
                    )
                                                tmdbActorIngested.append(result)
                                                newlyIngested += 1
                                                
                                                // Update results incrementally
                                                let merged = mergeResults(local: localMovies, ai: tmdbActorIngested)
                                                onProgress?(merged)
                                                
                                            } catch {
                                                print("⚠️ [HintSearch] Failed to ingest TMDB movie \(tmdbMovie.title): \(error)")
                                                // Continue with next movie
                                            }
                                        }
                                        
                                        // Add TMDB actor results to aiMovies
                                        aiMovies = tmdbActorIngested
                                        progress = .aiComplete(count: tmdbActorIngested.count, newCount: newlyIngested)
                                        verificationProgress = nil
                                        
                                        // Update final results
                                        let merged = mergeResults(local: localMovies, ai: aiMovies)
                                        onProgress?(merged)
                                        
                                        print("🎬 [HintSearch] TMDB actor fallback completed: ingested \(tmdbActorIngested.count) movies for \(actorName)")
                                    } else {
                                        print("🎬 [HintSearch] TMDB person search returned 0 movies for \(actorName)")
                                    }
                                } else {
                                    print("🎬 [HintSearch] No person found for: \(actorName)")
                                }
                            } catch {
                                print("⚠️ [HintSearch] TMDB actor fallback search failed: \(error)")
                                // Don't fail the whole search if actor fallback fails
                            }
                        }
                    }
                } catch {
                    print("⚠️ [HintSearch] TMDB fallback search failed: \(error)")
                    // Don't fail the whole search if TMDB fallback fails
                }
            }
            
            isAISearching = false
        }
        
        // Step 6: Merge and deduplicate results
        let merged = mergeResults(local: localMovies, ai: aiMovies)
        allResults = merged
        
        progress = .complete
        isSearching = false
        verificationProgress = nil
        
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
        var results: [HintSearchResult] = []
        
        do {
            // Priority 1: If we have director hint, search by director first
            if let director = hints?.director {
                #if DEBUG
                print("🎬 [HintSearch] Searching by director: \(director)")
                #endif
                
                let directorResults = try await SupabaseService.shared.searchMoviesByDirector(director)
                
                for movie in directorResults {
                    // Convert tmdbId from String to Int
                    guard let tmdbIdInt = Int(movie.tmdbId) else {
                        #if DEBUG
                        print("⚠️ [HintSearch] Skipping movie with invalid tmdbId: \(movie.tmdbId)")
                        #endif
                        continue
                    }
                    
                    var matchReason: String? = "Director match"
                    if hints?.year != nil && movie.year == hints?.year {
                        matchReason = "Director + year match"
                    }
                    
                    results.append(HintSearchResult(
                        tmdbId: tmdbIdInt,
                        title: movie.title,
                        year: movie.year,
                        posterURL: movie.posterUrl,
                        source: .local,
                        matchReason: matchReason,
                        genres: movie.genres,
                        runtimeDisplay: movie.runtimeDisplay,
                        aiScore: movie.aiScore,
                        voteAverage: movie.voteAverage
                    ))
                }
                
                #if DEBUG
                print("🎬 [HintSearch] Found \(results.count) movies by director \(director)")
                #endif
                
                // Fallback: If director search found 0 results, try text search
                if results.isEmpty {
                    #if DEBUG
                    print("🔍 [HintSearch] Director search returned 0 results, falling back to text search")
                    #endif
                    let searchQuery = hints?.titleLikely ?? query
                    let searchResults = try await SupabaseService.shared.searchMovies(query: searchQuery)
                    
                    for movie in searchResults {
                        guard let tmdbIdInt = Int(movie.tmdbId) else { continue }
                        results.append(HintSearchResult(
                            tmdbId: tmdbIdInt,
                            title: movie.title,
                            year: movie.year,
                            posterURL: movie.posterUrl,
                            source: .local,
                            matchReason: "Text search fallback",
                            genres: movie.genres,
                            runtimeDisplay: movie.runtimeDisplay,
                            aiScore: movie.aiScore,
                            voteAverage: movie.voteAverage
                        ))
                    }
                    #if DEBUG
                    print("🔍 [HintSearch] Text search fallback found \(searchResults.count) movies")
                    #endif
                }
            }
            // Priority 2: If we have actor hint (and no director), search by actor
            else if let hints = hints, !hints.actors.isEmpty {
                #if DEBUG
                print("🎬 [HintSearch] Searching by actor: \(hints.actors.first!)")
                #endif
                
                // Search by first actor (most specific)
                let actorResults = try await SupabaseService.shared.searchMoviesByActor(hints.actors.first!)
                
                let existingIds = Set(results.map { $0.tmdbId })
                for movie in actorResults {
                    // Skip if already added from director search
                    guard let tmdbIdInt = Int(movie.tmdbId), !existingIds.contains(tmdbIdInt) else {
                        continue
                    }
                    
                    var matchReason: String? = "Actor match"
                    if hints.year != nil && movie.year == hints.year {
                        matchReason = "Actor + year match"
                    }
                    
                    results.append(HintSearchResult(
                        tmdbId: tmdbIdInt,
                        title: movie.title,
                        year: movie.year,
                        posterURL: movie.posterUrl,
                        source: .local,
                        matchReason: matchReason,
                        genres: movie.genres,
                        runtimeDisplay: movie.runtimeDisplay,
                        aiScore: movie.aiScore,
                        voteAverage: movie.voteAverage
                    ))
                }
                
                #if DEBUG
                print("🎬 [HintSearch] Found \(actorResults.count) movies with actor \(hints.actors.first!)")
                #endif
                
                // Fallback: If actor search found 0 results, try text search
                if results.isEmpty {
                    #if DEBUG
                    print("🔍 [HintSearch] Actor search returned 0 results, falling back to text search")
                    #endif
                    let searchQuery = hints.titleLikely ?? query
                    let searchResults = try await SupabaseService.shared.searchMovies(query: searchQuery)
                    
                    for movie in searchResults {
                        guard let tmdbIdInt = Int(movie.tmdbId) else { continue }
                        results.append(HintSearchResult(
                            tmdbId: tmdbIdInt,
                            title: movie.title,
                            year: movie.year,
                            posterURL: movie.posterUrl,
                            source: .local,
                            matchReason: "Text search fallback",
                            genres: movie.genres,
                            runtimeDisplay: movie.runtimeDisplay,
                            aiScore: movie.aiScore,
                            voteAverage: movie.voteAverage
                        ))
                    }
                    #if DEBUG
                    print("🔍 [HintSearch] Text search fallback found \(searchResults.count) movies")
                    #endif
                }
            }
            // Priority 3: If no director/actor hints, do text search
            else {
                let searchQuery = hints?.titleLikely ?? query
                
                #if DEBUG
                print("🔍 [HintSearch] Text search for: \(searchQuery)")
                #endif
                
                let searchResults = try await SupabaseService.shared.searchMovies(query: searchQuery)
                
                #if DEBUG
                print("🔍 [HintSearch] Received \(searchResults.count) results from searchMovies")
                for (index, movie) in searchResults.prefix(5).enumerated() {
                    print("   [\(index)] \(movie.title) - aiScore: \(movie.aiScore?.description ?? "nil"), voteAverage: \(movie.voteAverage?.description ?? "nil"), posterUrl: \(movie.posterUrl?.prefix(50) ?? "nil")")
                }
                #endif
                
                for movie in searchResults {
                    // Convert tmdbId from String to Int
                    guard let tmdbIdInt = Int(movie.tmdbId) else {
                        #if DEBUG
                        print("⚠️ [HintSearch] Skipping movie with invalid tmdbId: \(movie.tmdbId)")
                        #endif
                        continue
                    }
                    
                    var matchReason: String? = nil
                    if hints?.year != nil && movie.year == hints?.year {
                        matchReason = "Year match"
                    }
                    
                    #if DEBUG
                    let isDbMovie = movie.aiScore != nil && movie.aiScore! > 10
                    print("🔍 [HintSearch] Creating HintSearchResult for \(movie.title): aiScore=\(movie.aiScore?.description ?? "nil"), voteAverage=\(movie.voteAverage?.description ?? "nil"), isInDatabase=\(isDbMovie)")
                    #endif
                    
                    results.append(HintSearchResult(
                        tmdbId: tmdbIdInt,
                        title: movie.title,
                        year: movie.year,
                        posterURL: movie.posterUrl,
                        source: .local,
                        matchReason: matchReason,
                        genres: movie.genres,
                        runtimeDisplay: movie.runtimeDisplay,
                        aiScore: movie.aiScore,
                        voteAverage: movie.voteAverage
                    ))
                }
                
                #if DEBUG
                print("🔍 [HintSearch] Text search found \(searchResults.count) movies")
                #endif
            }
            
        } catch {
            #if DEBUG
            print("⚠️ [HintSearch] Local search error: \(error)")
            #endif
            // Don't throw - return empty results on error
        }
        
        // Sort by AI score descending (highest rated first)
        results.sort { ($0.aiScore ?? 0) > ($1.aiScore ?? 0) }
        
        return results
    }
    
    
    // MARK: - TMDB ID Verification
    
    /// Verify a TMDB ID by searching TMDB for the title and finding the best match
    /// Returns the verified TMDB ID, or nil if not found
    private func verifyTmdbId(title: String, year: Int?) async -> Int? {
        do {
            // Search TMDB for the title
            let searchResponse = try await tmdbService.searchMovies(query: title)
            
            guard !searchResponse.results.isEmpty else {
                #if DEBUG
                print("⚠️ [HintSearch] TMDB search returned no results for: \(title)")
                #endif
                return nil
            }
            
            // Find the best match by title and year
            let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            for result in searchResponse.results {
                let resultTitle = result.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Extract year from release_date (format: "YYYY-MM-DD")
                var resultYear: Int? = nil
                if let releaseDate = result.releaseDate, releaseDate.count >= 4 {
                    resultYear = Int(releaseDate.prefix(4))
                }
                
                // Check for title match (exact or very close)
                let titleMatches = resultTitle == normalizedTitle ||
                                   resultTitle.contains(normalizedTitle) ||
                                   normalizedTitle.contains(resultTitle)
                
                // Check for year match (if we have both years)
                let yearMatches = year == nil || resultYear == nil || year == resultYear
                
                if titleMatches && yearMatches {
                    #if DEBUG
                    print("✅ [HintSearch] Verified TMDB ID for '\(title)' (\(year ?? 0)): \(result.id) -> '\(result.title)' (\(resultYear ?? 0))")
                    #endif
                    return result.id
                }
            }
            
            // If no exact match, return the first result if title is close enough
            if let firstResult = searchResponse.results.first {
                let firstTitle = firstResult.title.lowercased()
                // Use Levenshtein-like check: if first few words match
                let titleWords = normalizedTitle.split(separator: " ").prefix(2).joined(separator: " ")
                let resultWords = firstTitle.split(separator: " ").prefix(2).joined(separator: " ")
                
                if titleWords == resultWords {
                    #if DEBUG
                    print("⚠️ [HintSearch] Using first TMDB result for '\(title)': \(firstResult.id) -> '\(firstResult.title)'")
                    #endif
                    return firstResult.id
                }
            }
            
            #if DEBUG
            print("⚠️ [HintSearch] No good TMDB match found for: \(title) (\(year ?? 0))")
            #endif
            return nil
            
        } catch {
            #if DEBUG
            print("⚠️ [HintSearch] TMDB search failed for '\(title)': \(error)")
            #endif
            return nil
        }
    }
    
    // MARK: - Ingestion
    
    /// Verify TMDB IDs and ingest multiple movies from AI suggestions
    /// AI-provided TMDB IDs are NOT trusted - we search TMDB by title+year to get correct IDs
    /// - Parameters:
    ///   - suggestions: AI movie suggestions to verify and ingest
    ///   - onProgress: Optional callback that receives incremental results as each movie is processed
    /// - Returns: Tuple of (results, successCount)
    private func verifyAndIngestMovies(
        _ suggestions: [AIMovieSuggestion],
        onProgress: (([HintSearchResult]) -> Void)? = nil
    ) async -> (results: [HintSearchResult], successCount: Int) {
        var results: [HintSearchResult] = []
        var successCount = 0
        
        for (index, suggestion) in suggestions.enumerated() {
            // Check for cancellation before processing each movie
            // This prevents old ingestion results from appearing in new searches
            if Task.isCancelled {
                #if DEBUG
                print("🔄 [HintSearchCoordinator] Ingestion cancelled - stopping at \(index) of \(suggestions.count)")
                #endif
                break
            }
            
            progress = .ingesting(current: index + 1, total: suggestions.count)
            verificationProgress = (current: index + 1, total: suggestions.count)
            
            #if DEBUG
            print("🔍 [HintSearch] Verifying TMDB ID for: \(suggestion.title) (\(suggestion.year ?? 0)) - AI said: \(suggestion.tmdbId ?? -1)")
            #endif
            
            // CRITICAL: Don't trust AI's TMDB ID - verify by searching TMDB
            guard let verifiedTmdbId = await verifyTmdbId(title: suggestion.title, year: suggestion.year) else {
                #if DEBUG
                print("⚠️ [HintSearch] Could not verify TMDB ID for: \(suggestion.title)")
                #endif
                
                // Still add to results as AI-discovered (without ingestion)
                if let aiTmdbId = suggestion.tmdbId {
                    let result = HintSearchResult(
                        tmdbId: aiTmdbId,
                        title: suggestion.title,
                        year: suggestion.year,
                        posterURL: nil,
                        source: .aiDiscovered,
                        matchReason: suggestion.reason,
                        genres: nil,
                        runtimeDisplay: nil,
                        aiScore: nil,
                        voteAverage: nil
                    )
                    results.append(result)
                    // Call progress callback with updated results (only if not cancelled)
                    if !Task.isCancelled {
                        onProgress?(results)
                    }
                }
                continue
            }
            
            // Log if AI's ID was wrong
            #if DEBUG
            if let aiId = suggestion.tmdbId, aiId != verifiedTmdbId {
                print("🔧 [HintSearch] CORRECTED TMDB ID: AI said \(aiId), actual is \(verifiedTmdbId) for '\(suggestion.title)'")
            }
            #endif
            
            // STEP 1: Show quick results immediately with TMDB data (fast)
            var quickResult: HintSearchResult
            do {
                // Fetch basic TMDB details (fast - just one API call)
                let tmdbDetails = try await TMDBService.shared.getMovieDetails(movieId: verifiedTmdbId)
                
                // Build poster URL from TMDB
                let posterURL: String?
                if let posterPath = tmdbDetails.posterPath {
                    posterURL = "https://image.tmdb.org/t/p/w342\(posterPath)"
                } else {
                    posterURL = nil
                }
                
                // Extract year from release date
                let year: Int?
                if let releaseDate = tmdbDetails.releaseDate, let yearInt = Int(releaseDate.prefix(4)) {
                    year = yearInt
                } else {
                    year = suggestion.year
                }
                
                // Extract genres from TMDB
                let genres: [String]? = tmdbDetails.genres?.map { $0.name }
                
                // Extract runtime
                let runtimeDisplay: String?
                if let runtime = tmdbDetails.runtime, runtime > 0 {
                    let hours = runtime / 60
                    let minutes = runtime % 60
                    if hours > 0 {
                        runtimeDisplay = "\(hours)h \(minutes)m"
                    } else {
                        runtimeDisplay = "\(minutes)m"
                    }
                } else {
                    runtimeDisplay = nil
                }
                
                // Create quick result with TMDB data only (no AI scores, no tasty scores)
                quickResult = HintSearchResult(
                    tmdbId: verifiedTmdbId,
                    title: tmdbDetails.title.isEmpty ? suggestion.title : tmdbDetails.title,
                    year: year,
                    posterURL: posterURL,
                    source: .aiDiscovered, // Will be updated to .aiIngested when full ingestion completes
                    matchReason: suggestion.reason,
                    genres: genres,
                    runtimeDisplay: runtimeDisplay,
                    aiScore: nil, // Will be populated when full ingestion completes
                    voteAverage: tmdbDetails.voteAverage // TMDB score available immediately
                )
                
                results.append(quickResult)
                
                // Show results immediately (fast!)
                if !Task.isCancelled {
                    onProgress?(results)
                }
                
                #if DEBUG
                let displayTitle = tmdbDetails.title.isEmpty ? suggestion.title : tmdbDetails.title
                print("⚡ [HintSearch] Quick result shown: \(displayTitle) [TMDB: \(verifiedTmdbId)]")
                #endif
                
            } catch {
                #if DEBUG
                print("⚠️ [HintSearch] Failed to fetch TMDB details for \(suggestion.title): \(error)")
                #endif
                
                // Fallback: Show result without poster if TMDB fetch fails
                quickResult = HintSearchResult(
                    tmdbId: verifiedTmdbId,
                    title: suggestion.title,
                    year: suggestion.year,
                    posterURL: nil,
                    source: .aiDiscovered,
                    matchReason: suggestion.reason,
                    genres: nil,
                    runtimeDisplay: nil,
                    aiScore: nil,
                    voteAverage: nil
                )
                results.append(quickResult)
                if !Task.isCancelled {
                    onProgress?(results)
                }
            }
            
            // STEP 2: Trigger background ingestion (slow - includes AI scores, tasty scores, etc.)
            // Don't wait for this - it happens in the background
            Task {
                do {
                    // Call ingestMovie with the VERIFIED TMDB ID (this is slow)
                    let _ = try await SupabaseService.shared.ingestMovie(tmdbId: String(verifiedTmdbId))
                    
                    // Fetch the full card with AI scores and tasty scores
                    let card = try await SupabaseService.shared.fetchMovieCardFromCache(tmdbId: String(verifiedTmdbId))
                    
                    // Update the result with full data
                    if let cardIndex = results.firstIndex(where: { $0.tmdbId == verifiedTmdbId }) {
                        // Extract poster URL from cached card (may be different from TMDB URL)
                        let posterURLString = card?.poster?.medium ?? card?.poster?.small ?? card?.poster?.large ?? quickResult.posterURL
                        
                        // Update result with full data
                        results[cardIndex] = HintSearchResult(
                            tmdbId: verifiedTmdbId,
                            title: card?.title ?? quickResult.title,
                            year: card?.year ?? quickResult.year,
                            posterURL: posterURLString,
                            source: .aiIngested, // Now fully ingested
                            matchReason: quickResult.matchReason,
                            genres: card?.genres ?? quickResult.genres,
                            runtimeDisplay: card?.runtimeDisplay ?? quickResult.runtimeDisplay,
                            aiScore: card?.aiScore, // Now includes AI score!
                            voteAverage: card?.sourceScores?.tmdb?.score ?? quickResult.voteAverage
                        )
                        
                        successCount += 1
                        
                        // Update UI with full data (only if not cancelled)
                        if !Task.isCancelled {
                            onProgress?(results)
                        }
                        
                        #if DEBUG
                        print("✅ [HintSearch] Background ingestion complete: \(card?.title ?? suggestion.title) [TMDB: \(verifiedTmdbId)]")
                        #endif
                    }
                } catch {
                    #if DEBUG
                    print("⚠️ [HintSearch] Background ingestion failed for \(suggestion.title): \(error)")
                    #endif
                    // Result already shown with TMDB data, so user still sees something
                }
            }
        }
        
        // Reset verification progress when done
        verificationProgress = nil
        
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
        
        // Sort by AI score descending (highest rated first)
        merged.sort { ($0.aiScore ?? 0) > ($1.aiScore ?? 0) }
        
        return merged
    }
}
