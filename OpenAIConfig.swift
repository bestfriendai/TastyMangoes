//
//  OpenAIConfig.swift
//  TastyMangoes
//
//  Created by ChatGPT on December 4, 2025 at 7:28 PM Pacific Time (California).
//
//  Purpose:
//  This file replaces all previous OpenAI key handling systems (Secrets.xcconfig,
//  Secrets.swift, Info.plist storage, hardcoded keys, etc.). The app now securely
//  loads the API key *only* from an environment variable called OPENAI_API_KEY,
//  which is set inside Xcode’s Scheme → Run → Arguments → Environment Variables.
//
//  No API key is stored in the repository. No real API key value appears in this
//  file or anywhere else in version control. This satisfies GitHub Push Protection
//  and keeps the app secure.
//
//  Usage:
//      let key = OpenAIConfig.apiKey
//
//  If the key is missing, the app will crash with a clear error message.
//

import Foundation

enum OpenAIConfig {

    /// Returns the OpenAI API key from the environment variable OPENAI_API_KEY.
    /// This is the *only* approved method for accessing the key in this project.
    static var apiKey: String {
        guard let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
              !key.isEmpty else {
            fatalError("""
            Missing OPENAI_API_KEY environment variable.

            Fix this in Xcode:
            1. Product → Scheme → Edit Scheme…
            2. Select "Run" on the left
            3. Open the "Arguments" tab
            4. Under Environment Variables, add:
                   Name:  OPENAI_API_KEY
                   Value: <your API key>
            """)
        }

        return key
    }
}

