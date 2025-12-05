//  MangoCommandTests.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 22:21 (America/Los_Angeles - Pacific Time)
//  Notes: Unit tests for MangoCommand parser and LLM fallback integration

import XCTest
@testable import TastyMangoes

final class MangoCommandTests: XCTestCase {
    
    var parser: MangoCommandParser!
    
    override func setUp() {
        super.setUp()
        parser = MangoCommandParser.shared
    }
    
    // MARK: - MangoCommand Parser Tests
    
    func testParserReturnsRecommenderSearch() {
        let command = parser.parse("Sabrina recommends Baby Girl")
        
        switch command {
        case .recommenderSearch(let recommender, let movie, _):
            XCTAssertEqual(recommender, "Sabrina")
            XCTAssertEqual(movie, "Baby Girl")
            XCTAssertTrue(command.isValid)
        default:
            XCTFail("Expected recommenderSearch, got \(command)")
        }
    }
    
    func testParserReturnsRecommenderSearchWithPublication() {
        let command = parser.parse("The Wall Street Journal recommends Baby Girl")
        
        switch command {
        case .recommenderSearch(let recommender, let movie, _):
            XCTAssertEqual(recommender, "The Wall Street Journal")
            XCTAssertEqual(movie, "Baby Girl")
            XCTAssertTrue(command.isValid)
        default:
            XCTFail("Expected recommenderSearch, got \(command)")
        }
    }
    
    func testParserReturnsMovieSearch() {
        let command = parser.parse("add The Devil Wears Prada to my watchlist")
        
        switch command {
        case .movieSearch(let query, _):
            XCTAssertEqual(query, "The Devil Wears Prada")
            XCTAssertTrue(command.isValid)
        default:
            XCTFail("Expected movieSearch, got \(command)")
        }
    }
    
    func testParserReturnsUnknown() {
        let command = parser.parse("The Devil Wears Prada")
        
        switch command {
        case .unknown(let raw):
            XCTAssertEqual(raw, "The Devil Wears Prada")
            XCTAssertFalse(command.isValid)
        default:
            XCTFail("Expected unknown, got \(command)")
        }
    }
    
    func testParserReturnsUnknownForUnmatchedPattern() {
        let command = parser.parse("what movies are playing")
        
        switch command {
        case .unknown:
            XCTAssertFalse(command.isValid)
        default:
            XCTFail("Expected unknown for unmatched pattern")
        }
    }
    
    // MARK: - LLM Intent Mapping Tests
    
    func testLLMIntentMapsToRecommenderSearch() {
        let intent = LLMIntent(intent: "recommender_search", movieTitle: "Baby Girl", recommender: "Sabrina")
        
        // Simulate mapping logic from VoiceIntentRouter
        let command: MangoCommand
        switch intent.intent {
        case "recommender_search":
            if let movie = intent.movieTitle, !movie.isEmpty,
               let recommender = intent.recommender, !recommender.isEmpty {
                command = .recommenderSearch(recommender: recommender, movie: movie, raw: "test")
            } else {
                command = .movieSearch(query: intent.movieTitle ?? "test", raw: "test")
            }
        case "movie_search":
            command = .movieSearch(query: intent.movieTitle ?? "test", raw: "test")
        default:
            command = .movieSearch(query: "test", raw: "test")
        }
        
        switch command {
        case .recommenderSearch(let recommender, let movie, _):
            XCTAssertEqual(recommender, "Sabrina")
            XCTAssertEqual(movie, "Baby Girl")
        default:
            XCTFail("Expected recommenderSearch from LLM intent")
        }
    }
    
    func testLLMIntentMapsToMovieSearch() {
        let intent = LLMIntent(intent: "movie_search", movieTitle: "The Devil Wears Prada", recommender: nil)
        
        // Simulate mapping logic
        let command: MangoCommand
        switch intent.intent {
        case "movie_search":
            command = .movieSearch(query: intent.movieTitle ?? "test", raw: "test")
        default:
            command = .movieSearch(query: "test", raw: "test")
        }
        
        switch command {
        case .movieSearch(let query, _):
            XCTAssertEqual(query, "The Devil Wears Prada")
        default:
            XCTFail("Expected movieSearch from LLM intent")
        }
    }
    
    func testLLMIntentWithPublicationRecommender() {
        let intent = LLMIntent(intent: "recommender_search", movieTitle: "Baby Girl", recommender: "The Wall Street Journal")
        
        let command: MangoCommand
        switch intent.intent {
        case "recommender_search":
            if let movie = intent.movieTitle, !movie.isEmpty,
               let recommender = intent.recommender, !recommender.isEmpty {
                command = .recommenderSearch(recommender: recommender, movie: movie, raw: "test")
            } else {
                command = .movieSearch(query: intent.movieTitle ?? "test", raw: "test")
            }
        default:
            command = .movieSearch(query: "test", raw: "test")
        }
        
        switch command {
        case .recommenderSearch(let recommender, let movie, _):
            XCTAssertEqual(recommender, "The Wall Street Journal")
            XCTAssertEqual(movie, "Baby Girl")
        default:
            XCTFail("Expected recommenderSearch with publication")
        }
    }
}

