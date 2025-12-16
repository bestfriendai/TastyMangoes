//  OpenAIConfig.swift
//  Created on 2025-12-04 at 20:37 (America/Los_Angeles - Pacific Time)
//  NOTE: Safe static config for OpenAI client. No secrets stored in Git.
//  Updated by Claude on 2025-12-06 at 21:20 (America/Los_Angeles - Pacific Time)
//  Added trimmingCharacters to fix hidden whitespace in API key from xcconfig

import Foundation

enum OpenAIConfig {
    
    /// The OpenAI API key loaded from Info.plist (injected via Secrets.xcconfig)
    static var apiKey: String {
        guard let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String,
              !key.isEmpty,
              !key.contains("your-") else {
            fatalError("OpenAI API Key not found. Did you set up Secrets.xcconfig?")
        }
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// The default model used for classification
    static let defaultModel: String = "gpt-4o"
    
    /// Base URL for the OpenAI API
    static let baseURL: String = "https://api.openai.com/v1"
    
    /// Timeout for requests
    static let requestTimeout: TimeInterval = 30.0
}
