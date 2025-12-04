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
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.47  // natural speaking rate
        synth.speak(utterance)
    }
}


