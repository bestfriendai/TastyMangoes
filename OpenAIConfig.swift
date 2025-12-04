//
//  OpenAIConfig.swift
//  Updated by ChatGPT on: 2025-12-04 at 09:52 AM (America/Los_Angeles - Pacific Time)
//  Notes: Loads your OpenAI API key from Info.plist using the key "OPENAI_API_KEY"
//

import Foundation

enum OpenAIConfig {

    // MARK: - Read API Key from Info.plist
    static var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String ?? ""
    }

    // MARK: - API Settings
    static let baseURL = "https://api.openai.com/v1"
    static let defaultModel = "gpt-4o-mini"
    static let requestTimeout: TimeInterval = 30
}
