//  MangoSpeaker.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 18:12 (America/Los_Angeles - Pacific Time)
//  Notes: Text-to-speech service for Mango voice responses using AVSpeechSynthesizer

import AVFoundation

final class MangoSpeaker {
    static let shared = MangoSpeaker()
    
    private let synth = AVSpeechSynthesizer()
    
    private init() {}
    
    func speak(_ text: String) {
        // Ensure audio session is active for playback
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ [MangoSpeaker] Failed to configure audio session: \(error)")
        }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.47
        synth.speak(utterance)
        print("🗣 [MangoSpeaker] Speaking: '\(text)'")
    }
}


