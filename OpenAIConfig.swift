//  OpenAIConfig.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 22:21 (America/Los_Angeles - Pacific Time)
//  Notes: OpenAI API configuration - reads API key from environment variable or Info.plist

import Foundation

struct OpenAIConfig {
    /// OpenAI API key - set via OPENAI_API_KEY environment variable or Info.plist
    static var apiKey: String {
        // First try environment variable (for CI/CD, local dev)
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        // Fallback to Info.plist (for app builds)
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let key = plist["OPENAI_API_KEY"] as? String, !key.isEmpty {
            return key
        }
        
        // Return empty string if not found (will cause client to fail gracefully)
        print("⚠️ OpenAI API key not found. Set OPENAI_API_KEY environment variable or add to Info.plist")
        return ""
    }
    
    /// OpenAI API base URL
    static let baseURL = "https://api.openai.com/v1"
    
    /// Default model for chat completions
    static let defaultModel = "gpt-4o-mini"
    
    /// Request timeout in seconds
    static let requestTimeout: TimeInterval = 10.0
}

