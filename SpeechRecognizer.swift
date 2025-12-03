//  SpeechRecognizer.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 22:30 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-12-03 at 09:40 PST by Cursor Assistant
//  Notes: Speech-to-text service for voice search functionality. Fixed instant UI feedback. Fixed premature stop on subsequent recordings - check state before setting to .requesting. Fixed syntax error with pattern matching. Increased final transcript wait time to 0.8s.

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
    private var recordingStartTime: Date?
    private let minRecordingDuration: TimeInterval = 2.0 // Minimum 2 seconds before auto-stop
    private let silenceTimeout: TimeInterval = 5.0 // 5 seconds of silence before auto-stop
    private var silenceTimer: Task<Void, Never>?
    private var hasReceivedTranscript: Bool = false // Track if we've gotten any transcript yet
    
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
        print("🎙 startListening() called (current state: \(state))")
        
        // If already listening, don't restart
        if case .listening = state {
            print("🎤 Already listening, ignoring start request")
            return
        }
        
        // If requesting, don't restart
        if case .requesting = state {
            print("🎤 Already requesting, ignoring start request")
            return
        }
        
        // Stop any existing recording FIRST (before changing state)
        // This ensures cleanup happens before we start new recording
        let needsCleanup: Bool
        switch state {
        case .listening, .processing:
            needsCleanup = true
        default:
            needsCleanup = false
        }
        
        if needsCleanup {
            print("🎤 Stopping existing recording before starting new one")
            stopListening(reason: "startingNewRecording")
            // Wait for cleanup to complete
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
        }
        
        // IMMEDIATE UI UPDATE - show "requesting" state right away
        state = .requesting
        
        // Cancel any existing silence timer
        silenceTimer?.cancel()
        silenceTimer = nil
        
        // Reset transcript and flags for new recording
        transcript = ""
        hasReceivedTranscript = false
        
        // Now do async permission check
        let authorized = await requestPermission()
        guard authorized else {
            print("🎤 Permission denied")
            state = .error("Microphone permission denied")
            return
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            let errorMsg = "Speech recognition not available"
            print("🎤 Error: \(errorMsg)")
            state = .error(errorMsg)
            return
        }
        
        print("🎤 Speech recognizer is available, starting...")
        
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
                    self.stopListening(reason: "error")
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
                    self.hasReceivedTranscript = true
                    print("🎤 Transcript updated: '\(self.transcript)'")
                    
                    // Reset silence timer on any transcript update (only if timer exists)
                    // This means user is still speaking, so extend the timeout
                    // But don't start timer if grace period hasn't passed yet
                    if case .listening = self.state, self.silenceTimer != nil {
                        print("🎤 Resetting silence timer due to transcript update")
                        self.startSilenceTimer()
                    }
                }
                
                // If final, ensure we keep the transcript
                if result.isFinal {
                    print("🎤 Final transcript received: '\(self.transcript)'")
                    // Don't stop here - let user stop manually or auto-stop after silence
                    // Reset silence timer since we got a final result (user might continue)
                    // But only if timer exists (grace period has passed)
                    if case .listening = self.state, self.silenceTimer != nil {
                        print("🎤 Resetting silence timer due to final transcript")
                        self.startSilenceTimer()
                    }
                }
            }
        }
        
        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            recordingStartTime = Date()
            state = .listening
            print("🎤 Started listening... (state set to .listening)")
            
            // Don't start silence timer immediately - always wait grace period
            // This gives user time to start speaking without premature timeout
            Task { @MainActor in
                // Always wait full grace period (3 seconds) before starting silence timer
                // This ensures consistent behavior on first and subsequent recordings
                let gracePeriod: TimeInterval = 3.0
                try? await Task.sleep(nanoseconds: UInt64(gracePeriod * 1_000_000_000))
                
                // Only start silence timer if we're still listening
                // By this point, user has had time to start speaking
                if case .listening = self.state {
                    print("🎤 Grace period ended, starting silence timer")
                    self.startSilenceTimer()
                }
            }
        } catch {
            state = .error("Audio engine error: \(error.localizedDescription)")
            stopListening(reason: "error")
        }
    }
    
    private func startSilenceTimer() {
        // Cancel any existing timer
        silenceTimer?.cancel()
        
        silenceTimer = Task {
            // Wait for silence timeout before auto-stopping
            let timeoutNanoseconds = UInt64(silenceTimeout * 1_000_000_000)
            try? await Task.sleep(nanoseconds: timeoutNanoseconds)
            
            // Only auto-stop if we're still listening and minimum duration has passed
            if case .listening = state,
               let startTime = recordingStartTime,
               Date().timeIntervalSince(startTime) >= minRecordingDuration {
                print("🎤 Auto-stopping due to silence timeout (after \(silenceTimeout)s of silence)")
                await MainActor.run {
                    stopListening(reason: "silenceTimeout")
                }
            }
        }
    }
    
    func stopListening(reason: String = "userTappedStop") {
        print("🎙 stopListening() called (reason: \(reason))")
        
        // Cancel silence timer
        silenceTimer?.cancel()
        silenceTimer = nil
        
        // Only proceed if we're actually listening or requesting
        let canStop: Bool
        switch state {
        case .listening, .requesting:
            canStop = true
        default:
            canStop = false
        }
        
        guard canStop else {
            print("🎤 Already stopped or not listening (state: \(state))")
            return
        }
        
        print("🎤 Stopping... (current transcript: '\(transcript)', reason: \(reason))")
        
        // End audio input to finalize recognition
        recognitionRequest?.endAudio()
        
        // Wait a moment for final transcript, then stop engine
        Task { @MainActor in
            // Give recognition more time to finalize for better results
            // Wait longer to ensure we get the final transcript
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s - increased for better final transcript
            
            // Stop audio engine
            audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)
            
            // Don't cancel recognition task immediately - let it finish processing
            // The task will complete naturally after endAudio()
            
            // Clean up (but keep transcript!)
            audioEngine = nil
            recognitionRequest = nil
            // Don't nil recognitionTask yet - let it finish
            recordingStartTime = nil
            // Don't reset hasReceivedTranscript - we might want to know if we got one
            
            // Reset audio session
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            
            // Update state to processing (transcript is preserved)
            state = .processing
            print("🎤 State changed to processing, transcript preserved: '\(transcript)'")
            
            // Wait a bit longer before going to idle to ensure final transcript is captured
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            
            // Now cancel the recognition task (it should be done by now)
            recognitionTask?.cancel()
            recognitionTask = nil
            
            // Finally go to idle
            if case .processing = state {
                state = .idle
                print("🎤 State changed to idle, final transcript: '\(transcript)'")
            }
        }
    }
}

