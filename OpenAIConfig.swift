//  OpenAIConfig.swift
//  Created on 2025-12-04 at 20:37 (America/Los_Angeles - Pacific Time)
//  NOTE: Safe static config for OpenAI client. No secrets stored in Git.
//  Updated by Claude on 2025-12-06 at 19:19 (America/Los_Angeles - Pacific Time)
//  Changed to read API key from Secrets.xcconfig via Info.plist instead of environment variables

import Foundation

enum OpenAIConfig {
    
    /// The OpenAI API key loaded from Info.plist (injected via Secrets.xcconfig)
    static var apiKey: String {
        guard let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String,
              !key.isEmpty,
              !key.contains("your-") else {
            fatalError("OpenAI API Key not found. Did you set up Secrets.xcconfig?")
        }
        return key
    }
    
    /// The default model used for classification
    static let defaultModel: String = "gpt-4o-mini"
    
    /// Base URL for the OpenAI API
    static let baseURL: String = "https://api.openai.com/v1"
    
    /// Timeout for requests
    static let requestTimeout: TimeInterval = 30.0
}
