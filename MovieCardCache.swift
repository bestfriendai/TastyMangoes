//  MovieCardCache.swift
//  TastyMangoes
//
//  Created by Claude on 2025-12-09 at 16:45 (America/Los_Angeles - Pacific Time)
//  Notes: Local persistence layer for MovieCard objects. Enables instant loading of
//         watchlist movies without network calls. Cards are stored on device and only
//         missing cards are fetched from Supabase.

import Foundation
import Combine

/// Local cache for MovieCard objects - enables instant watchlist loading
@MainActor
class MovieCardCache: ObservableObject {
    static let shared = MovieCardCache()
    
    /// In-memory cache for fast access
    @Published private(set) var cards: [String: MovieCard] = [:]
    
    /// File URL for persistent storage
    private let cacheFileURL: URL
    
    /// Cache version for future migrations
    private let cacheVersion = 1
    
    private init() {
        // Store in Documents directory for persistence
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheFileURL = documentsPath.appendingPathComponent("movie_cards_cache_v\(cacheVersion).json")
        
        // Load cached cards from disk on init
        loadFromDisk()
        print("🎬 [MovieCardCache] Initialized with \(cards.count) cached cards")
    }
    
    // MARK: - Public API
    
    /// Get a single card by TMDB ID (instant, from memory)
    func getCard(tmdbId: String) -> MovieCard? {
        return cards[tmdbId]
    }
    
    /// Get multiple cards by TMDB IDs (instant, from memory)
    func getCards(tmdbIds: [String]) -> [String: MovieCard] {
        var result: [String: MovieCard] = [:]
        for tmdbId in tmdbIds {
            if let card = cards[tmdbId] {
                result[tmdbId] = card
            }
        }
        return result
    }
    
    /// Check which IDs are missing from local cache
    func getMissingIds(from tmdbIds: [String]) -> [String] {
        return tmdbIds.filter { cards[$0] == nil }
    }
    
    /// Check which IDs we already have cached
    func getCachedIds(from tmdbIds: [String]) -> [String] {
        return tmdbIds.filter { cards[$0] != nil }
    }
    
    /// Store a single card
    func setCard(_ card: MovieCard) {
        cards[card.tmdbId] = card
        saveToDiskDebounced()
    }
    
    /// Store multiple cards at once
    func setCards(_ newCards: [MovieCard]) {
        for card in newCards {
            cards[card.tmdbId] = card
        }
        saveToDiskDebounced()
        print("🎬 [MovieCardCache] Cached \(newCards.count) new cards (total: \(cards.count))")
    }
    
    /// Remove a card from cache
    func removeCard(tmdbId: String) {
        cards.removeValue(forKey: tmdbId)
        saveToDiskDebounced()
    }
    
    /// Clear all cached cards
    func clearCache() {
        cards.removeAll()
        saveToDiskDebounced()
        print("🎬 [MovieCardCache] Cache cleared")
    }
    
    /// Get count of cached cards
    var count: Int {
        return cards.count
    }
    
    // MARK: - Persistence
    
    /// Save task for debouncing
    private var saveTask: Task<Void, Never>?
    
    /// Debounced save to avoid excessive disk writes
    private func saveToDiskDebounced() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second debounce
            if !Task.isCancelled {
                saveToDisk()
            }
        }
    }
    
    /// Save cache to disk
    private func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(Array(cards.values))
            try data.write(to: cacheFileURL)
            print("🎬 [MovieCardCache] Saved \(cards.count) cards to disk")
        } catch {
            print("⚠️ [MovieCardCache] Failed to save to disk: \(error)")
        }
    }
    
    /// Load cache from disk
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            print("🎬 [MovieCardCache] No cache file found, starting fresh")
            return
        }
        
        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoder = JSONDecoder()
            let loadedCards = try decoder.decode([MovieCard].self, from: data)
            
            // Convert array to dictionary keyed by tmdbId
            cards = Dictionary(uniqueKeysWithValues: loadedCards.map { ($0.tmdbId, $0) })
            print("🎬 [MovieCardCache] Loaded \(cards.count) cards from disk")
        } catch {
            print("⚠️ [MovieCardCache] Failed to load from disk: \(error)")
            // If loading fails, start fresh
            cards = [:]
        }
    }
    
    /// Force save (call on app backgrounding)
    func forceSave() {
        saveTask?.cancel()
        saveToDisk()
    }
}
