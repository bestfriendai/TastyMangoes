//  SpeechRecognizer.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 22:30 (America/Los_Angeles - Pacific Time)
//  Notes: Speech-to-text service for voice search functionality

import Foundation
import Combine
import Speech
import AVFoundation

@MainActor
class SpeechRecognizer: ObservableObject {
    
    enum State: Equatable {
        case idle
        case requesting    // Requesting permission
        case listening     // Actively recording
        case processing    // Processing final result
        case error(String)
    }
    
    @Published var state: State = .idle
    @Published var transcript: String = ""
    @Published var isAvailable: Bool = false
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    init() {
        checkAvailability()
    }
    
    private func checkAvailability() {
        isAvailable = speechRecognizer?.isAvailable ?? false
    }
    
    func requestPermission() async -> Bool {
        state = .requesting
        
        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard speechStatus == .authorized else {
            state = .error("Speech recognition not authorized")
            return false
        }
        
        // Request microphone permission
        let micStatus = await AVAudioApplication.requestRecordPermission()
        
        guard micStatus else {
            state = .error("Microphone access not authorized")
            return false
        }
        
        state = .idle
        return true
    }
    
    func startListening() async {
        // Check/request permissions first
        let authorized = await requestPermission()
        guard authorized else {
            print("🎤 Permission denied")
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            let errorMsg = "Speech recognition not available"
            print("🎤 Error: \(errorMsg)")
            state = .error(errorMsg)
            return
        }
        
        print("🎤 Speech recognizer is available, starting...")
        
        // Reset
        transcript = ""
        stopListening()
        
        // Small delay to ensure cleanup is complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            state = .error("Audio session error: \(error.localizedDescription)")
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            state = .error("Unable to create recognition request")
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false // Set true for offline-only
        
        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            state = .error("Unable to create audio engine")
            return
        }
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                let errorDescription = error.localizedDescription
                print("🎤 Recognition error: \(errorDescription)")
                
                // Don't stop on cancellation errors (user manually stopped)
                let nsError = error as NSError
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                    print("🎤 Recognition was cancelled (user stopped)")
                    return
                }
                
                Task { @MainActor in
                    // Keep transcript if we have one, even on error
                    if !self.transcript.isEmpty {
                        print("🎤 Keeping transcript despite error: '\(self.transcript)'")
                    } else {
                        #if targetEnvironment(simulator)
                        print("🎤 No transcript captured - this is normal in iOS Simulator")
                        #else
                        print("🎤 No transcript captured")
                        #endif
                    }
                    self.stopListening()
                }
                return
            }
            
            guard let result = result else {
                print("🎤 No result and no error - recognition may still be processing")
                return
            }
            
            Task { @MainActor in
                let newTranscript = result.bestTranscription.formattedString
                if newTranscript != self.transcript {
                    self.transcript = newTranscript
                    print("🎤 Transcript updated: '\(self.transcript)'")
                }
                
                // If final, ensure we keep the transcript
                if result.isFinal {
                    print("🎤 Final transcript received: '\(self.transcript)'")
                    // Don't stop here - let user stop manually or auto-stop after silence
                }
            }
        }
        
        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            state = .listening
            print("🎤 Started listening...")
        } catch {
            state = .error("Audio engine error: \(error.localizedDescription)")
            stopListening()
        }
    }
    
    func stopListening() {
        print("🎤 Stopping... (current transcript: '\(transcript)')")
        
        guard case .listening = state else {
            print("🎤 Already stopped or not listening (state: \(state))")
            return
        }
        
        // End audio input to finalize recognition
        recognitionRequest?.endAudio()
        
        // Wait a moment for final transcript, then stop engine
        Task { @MainActor in
            // Give recognition a moment to finalize (longer wait for better results)
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            
            // Stop audio engine
            audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)
            
            // Cancel recognition task (but keep transcript)
            recognitionTask?.cancel()
            
            // Clean up
            audioEngine = nil
            recognitionRequest = nil
            recognitionTask = nil
            
            // Reset audio session
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            
            // Update state
            state = .processing
            print("🎤 State changed to processing, transcript: '\(transcript)'")
            
            // Brief delay then idle
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            if case .processing = state {
                state = .idle
                print("🎤 State changed to idle, final transcript: '\(transcript)'")
            }
        }
    }
}

