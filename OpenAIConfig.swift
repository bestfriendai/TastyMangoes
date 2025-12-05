//  OpenAIConfig.swift
//  Created on 2025-12-04 at 20:37 (America/Los_Angeles - Pacific Time)
//  NOTE: Safe static config for OpenAI client. No secrets stored in Git.

// ❗IMPORTANT
// You must set your API key in Xcode > Edit Scheme > Run > Arguments > Environment Variables
// Name: OPENAI_API_KEY
// Value: your-real-key-here

import Foundation

enum OpenAIConfig {
    
    /// The OpenAI API key loaded safely from environment variables at runtime.
    static var apiKey: String {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    }
    
    /// The default model used for classification
    static let defaultModel: String = "gpt-4o-mini"
    
    /// Base URL for the OpenAI API
    static let baseURL: String = "https://api.openai.com/v1"
    
    /// Timeout for requests
    static let requestTimeout: TimeInterval = 30.0
}
