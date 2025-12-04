//  OpenAIConfig.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 22:21 (America/Los_Angeles - Pacific Time)
//  Notes: OpenAI API configuration - reads API key from environment variable or Info.plist

import Foundation

struct OpenAIConfig {
    /// OpenAI API key - set via OPENAI_API_KEY environment variable or Info.plist
    /// 
    /// ⚠️ SECURITY WARNING: Never commit real API keys to version control!
    /// 
    /// For local development:
    ///   1. Set OPENAI_API_KEY in Xcode scheme environment variables (Product > Scheme > Edit Scheme > Run > Arguments > Environment Variables)
    ///   2. This takes precedence over Info.plist and is never committed
    /// 
    /// For production builds:
    ///   - Use Xcode scheme environment variables (recommended)
    ///   - Or set via CI/CD environment variables
    ///   - Info.plist should only contain placeholder values like "YOUR_LOCAL_OPENAI_KEY_HERE"
    /// 
    /// The environment variable approach is preferred because:
    ///   - It's never committed to git
    ///   - Each developer can use their own key
    ///   - CI/CD can inject keys securely
    static var apiKey: String {
        // First try environment variable (for CI/CD, local dev, Xcode scheme)
        // This is the preferred method - never committed to git
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        // Fallback to Info.plist (for app builds)
        // ⚠️ WARNING: Only use placeholder values in Info.plist, never real keys!
        // Real keys should be set via Xcode scheme environment variables
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String,
           !plistKey.isEmpty,
           plistKey != "YOUR_LOCAL_OPENAI_KEY_HERE" {
            // Only return if it's not the placeholder value
            return plistKey
        }
        
        // Return empty string if not found (will cause client to fail gracefully)
        // Don't print warning here - let OpenAIClient handle it quietly
        return ""
    }
    
    /// OpenAI API base URL
    static let baseURL = "https://api.openai.com/v1"
    
    /// Default model for chat completions
    static let defaultModel = "gpt-4o-mini"
    
    /// Request timeout in seconds
    static let requestTimeout: TimeInterval = 10.0
}

