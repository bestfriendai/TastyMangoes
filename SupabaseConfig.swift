//  SupabaseConfig.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 15:45 (America/Los_Angeles - Pacific Time)
//  Notes: Supabase configuration and client setup for TastyMangoes app

import Foundation

struct SupabaseConfig {
    static let supabaseURL = "https://zyywpjddzvkqvjosifiy.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp5eXdwamRkenZrcXZqb3NpZml5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQwMTExMDAsImV4cCI6MjA3OTU4NzEwMH0.viVGZrED5d8rDlnqcfog6seKPSczzKut4qUXiiliCbE"
    
    // Available streaming platforms
    static let availablePlatforms = [
        "Netflix",
        "Prime Video",
        "Disney+",
        "Max",
        "Hulu",
        "Criterion",
        "Paramount+",
        "Apple TV+",
        "Peacock",
        "Tubi"
    ]
}

