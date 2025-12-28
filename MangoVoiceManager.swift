//  MangoVoiceManager.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 23:00 (America/Los_Angeles - Pacific Time)
//  Notes: Text-to-speech manager for Mango's voice responses

import AVFoundation
import Combine

@MainActor
class MangoVoiceManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = MangoVoiceManager()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published var isSpeaking = false
    @Published var currentText: String?
    
    // Mango's voice settings
    private let voiceIdentifier = "com.apple.voice.compact.en-IE.Moira" // Irish accent
    private let speechRate: Float = 0.48  // Slightly slower (0.5 is default)
    private let pitchMultiplier: Float = 1.0
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func speak(_ text: String) {
        // Stop any current speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        let utterance = AVSpeechUtterance(string: text)
        
        // Try to get Moira (Irish), fall back to Samantha
        if let moira = AVSpeechSynthesisVoice(identifier: voiceIdentifier) {
            utterance.voice = moira
        } else if let samantha = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = samantha
        }
        
        utterance.rate = speechRate
        utterance.pitchMultiplier = pitchMultiplier
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.1
        
        currentText = text
        isSpeaking = true
        synthesizer.speak(utterance)
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}

