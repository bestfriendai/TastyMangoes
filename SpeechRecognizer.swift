//  SpeechRecognizer.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 22:30 (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-12-03 at 12:07 PST by Cursor Assistant
//  Notes: Speech-to-text service with configurable modes. TalkToMango: Two-timer system - pre-speech timer detects "no speech", post-speech timer detects silence after user stops talking. Post-speech timer resets on each transcript update, fires after 7s silence. Still respects Apple's isFinal if it comes first. Prevents sessions staying open too long.

import Foundation
import Combine
import Speech
import AVFoundation

/// Mode for voice session - determines timeout behavior
enum VoiceSessionMode {
    case talkToMango    // Conversational, longer pauses allowed
    case quickSearch    // Quick input, shorter timeouts
}

/// Mode for TalkToMango sessions - determines silence timeout after speech
enum TalkToMangoMode {
    case oneShot        // First tap experience - shorter silence timeout (~5s)
    case interactive    // Back-and-forth sessions - longer silence timeout (~10s)
}

/// Configuration for TalkToMango sessions
struct TalkToMangoConfig {
    var gracePeriod: TimeInterval
    var silenceTimeoutAfterSpeech: TimeInterval  // Timeout after user stops speaking
    var maxDuration: TimeInterval
    
    nonisolated static let oneShot = TalkToMangoConfig(
        gracePeriod: 1.5,
        silenceTimeoutAfterSpeech: 5.0,  // 5 seconds of silence after speech stops
        maxDuration: 60.0
    )
    
    nonisolated static let interactive = TalkToMangoConfig(
        gracePeriod: 1.5,
        silenceTimeoutAfterSpeech: 10.0, // 10 seconds of silence for back-and-forth
        maxDuration: 60.0
    )
}

/// Configuration for voice recognition session
struct SpeechConfig {
    var mode: VoiceSessionMode
    var gracePeriod: TimeInterval
    var silenceTimeout: TimeInterval
    var maxDuration: TimeInterval
    
    nonisolated static let talkToMango = SpeechConfig(
        mode: .talkToMango,
        gracePeriod: 1.5,      // Reduced from 3.0s - faster initial response
        silenceTimeout: 7.0,   // Reduced from 15.0s - shorter wait when nothing heard (legacy, will be replaced by TalkToMangoConfig)
        maxDuration: 60.0      // Hard upper bound to avoid infinite sessions
    )
    
    nonisolated static let quickSearch = SpeechConfig(
        mode: .quickSearch,
        gracePeriod: 3.0,
        silenceTimeout: 8.0,   // Shorter timeout for quick searches
        maxDuration: 30.0
    )
}

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
    @Published var isReadyToListen: Bool = false // True when audio engine is running and ready to capture speech
    
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recordingStartTime: Date?
    private var sessionStartTime: Date? // Track when startListening() was called for timing logs
    private var firstResultTime: Date? // Track when first recognition result arrives
    private let minRecordingDuration: TimeInterval = 2.0 // Minimum 2 seconds before auto-stop
    private var currentConfig: SpeechConfig = .quickSearch // Default config
    private var currentTalkToMangoConfig: TalkToMangoConfig? // TalkToMango-specific config (nil for non-TalkToMango modes)
    private var silenceTimer: Task<Void, Never>? // Pre-speech timer: detects "no speech at all"
    private var postSpeechSilenceTimer: Task<Void, Never>? // Post-speech timer: detects silence after user stops talking
    private var maxDurationTimer: Task<Void, Never>?
    private var hasReceivedTranscript: Bool = false // Track if we've gotten any transcript yet
    private var isFirstResult: Bool = true // Track if this is the first recognition result
    private var hasReceivedAnyResult: Bool = false // Track if we've received any recognition result (for TalkToMango endpointing)
    private var lastSpeechTime: Date? // Track when last transcript update occurred (for post-speech timer)
    private var shouldProcessTranscript: Bool = true // Set to false when user cancels (taps Stop) to prevent processing
    
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
    
    func startListening(config: SpeechConfig = SpeechConfig.quickSearch, talkToMangoMode: TalkToMangoMode = .oneShot) async {
        sessionStartTime = Date()
        isFirstResult = true
        isReadyToListen = false
        shouldProcessTranscript = true  // Reset flag for new session
        
        print("🎙 startListening() called (current state: \(state), mode: \(config.mode))")
        if let startTime = sessionStartTime {
            print("⏱ [TalkToMango] startListening at \(startTime.timeIntervalSince1970)")
        }
        
        // Store config for this session
        currentConfig = config
        
        // For TalkToMango mode, store the TalkToMango-specific config
        if config.mode == .talkToMango {
            currentTalkToMangoConfig = talkToMangoMode == .oneShot ? .oneShot : .interactive
        } else {
            currentTalkToMangoConfig = nil
        }
        
        // Log config details for TalkToMango mode
        if config.mode == .talkToMango, let talkToMangoConfig = currentTalkToMangoConfig {
            print("🎤 TalkToMango session: grace=\(talkToMangoConfig.gracePeriod)s, silenceTimeout=\(talkToMangoConfig.silenceTimeoutAfterSpeech)s, maxDuration=\(talkToMangoConfig.maxDuration)s")
        }
        
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
        isReadyToListen = false
        isFirstResult = true
        hasReceivedAnyResult = false
        firstResultTime = nil
        lastSpeechTime = nil
        // Cancel any existing timers
        postSpeechSilenceTimer?.cancel()
        postSpeechSilenceTimer = nil
        
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
        
        // Increase task hint for better recognition of longer phrases
        recognitionRequest.taskHint = .dictation // Better for longer, conversational input
        
        // Create audio engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            state = .error("Unable to create audio engine")
            return
        }
        
        // IMPORTANT: Remove any existing tap first to avoid conflicts
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("🎤 Recording format: \(recordingFormat)")
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.recognitionRequest?.append(buffer)
        }
        print("🎤 Audio tap installed on input node")
        
        // Start recognition task BEFORE starting audio engine
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                let errorDescription = error.localizedDescription
                print("🎤 Recognition error: \(errorDescription)")
                
                // Log detailed error info
                if let nsError = error as NSError? {
                    print("🎤 Recognition error code: \(nsError.code), domain: \(nsError.domain)")
                }
                
                // Don't stop on cancellation errors (user manually stopped)
                let nsError = error as NSError
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                    print("🎤 Recognition was cancelled (user stopped)")
                    return
                }
                
                // "No speech detected" is a terminal error - treat it as such
                // Don't try to keep recording, just stop cleanly
                let isNoSpeechError = errorDescription.contains("No speech") || 
                                      errorDescription.contains("no speech") ||
                                      (nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216)
                
                Task { @MainActor in
                    if isNoSpeechError {
                        print("🎤 No speech detected - treating as terminal error, stopping")
                        // Stop the recognizer cleanly
                        self.stopListening(reason: "noSpeechDetected")
                    } else if !self.transcript.isEmpty {
                        // Other error but we have transcript - stop and keep transcript
                        print("🎤 Keeping transcript despite error: '\(self.transcript)'")
                        self.stopListening(reason: "error")
                    } else {
                        // Other error with no transcript - stop anyway
                        print("⚠️ Error with no transcript - stopping")
                        self.stopListening(reason: "error")
                    }
                }
                return
            }
            
            guard let result = result else {
                print("🎤 No result and no error - recognition may still be processing")
                return
            }
            
            Task { @MainActor in
                let newTranscript = result.bestTranscription.formattedString
                
                // Track if we've received any result (for TalkToMango endpointing logic)
                if !newTranscript.isEmpty && !self.hasReceivedAnyResult {
                    self.hasReceivedAnyResult = true
                    // Log timing for first result
                    if let startTime = self.sessionStartTime {
                        let elapsed = Date().timeIntervalSince(startTime)
                        print("⏱ [TalkToMango] first recognition result after \(String(format: "%.2f", elapsed))s: '\(newTranscript)'")
                    }
                    
                    // For TalkToMango: once we have any transcript, cancel pre-speech timer
                    // and start post-speech timer instead
                    if self.currentConfig.mode == .talkToMango {
                        print("🎤 [TalkToMango] Received first transcript - canceling pre-speech timer, starting post-speech timer")
                        self.silenceTimer?.cancel()
                        self.silenceTimer = nil
                        // Start post-speech timer - will reset on each new transcript update
                        self.lastSpeechTime = Date()
                        self.startPostSpeechSilenceTimer()
                    }
                }
                
                // Log timing for first result (legacy support)
                if self.isFirstResult {
                    self.firstResultTime = Date()
                    self.isFirstResult = false
                }
                
                print("🎙 recognitionTask result: '\(newTranscript)' isFinal=\(result.isFinal), error=\(String(describing: error))")
                
                if newTranscript != self.transcript {
                    self.transcript = newTranscript
                    self.hasReceivedTranscript = true
                    print("🎤 Transcript updated: '\(self.transcript)'")
                    
                    // For TalkToMango: update lastSpeechTime and reset post-speech timer on each transcript update
                    // This gives user up to silenceTimeout seconds of silence after they stop talking
                    if self.currentConfig.mode == .talkToMango && self.hasReceivedAnyResult {
                        self.lastSpeechTime = Date()
                        print("⏱ [TalkToMango] updating lastSpeechTime at \(self.lastSpeechTime?.timeIntervalSince1970 ?? 0)")
                        // Reset post-speech timer - user is still speaking or just spoke
                        self.startPostSpeechSilenceTimer()
                    }
                }
                
                // If final, stop listening and let Apple's endpointing decide
                if result.isFinal {
                    print("🎤 [TalkToMango] isFinal=true – stopping based on Apple's endpointing")
                    print("🎤 Final transcript received: '\(self.transcript)'")
                    
                    // Cancel post-speech timer since Apple has determined utterance is complete
                    if self.currentConfig.mode == .talkToMango {
                        self.postSpeechSilenceTimer?.cancel()
                        self.postSpeechSilenceTimer = nil
                    }
                    
                    // Post notification that final transcript is ready
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SpeechRecognizerFinalTranscript"),
                        object: nil,
                        userInfo: ["transcript": self.transcript]
                    )
                    
                    // Handle TalkToMango transcript through VoiceIntentRouter
                    // Only process if user didn't cancel (tapped Stop)
                    if self.currentConfig.mode == .talkToMango && self.shouldProcessTranscript {
                        Task {
                            await VoiceIntentRouter.handleTalkToMangoTranscript(self.transcript)
                        }
                    } else if !self.shouldProcessTranscript {
                        print("🎤 Skipping transcript processing - user cancelled (tapped Stop)")
                    }
                    
                    // Stop listening - Apple has determined the utterance is complete
                    self.stopListening(reason: "finalFromApple")
                    return
                }
            }
        }
        
        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            recordingStartTime = Date()
            
            // Verify audio engine is actually running before setting state to listening
            // This ensures we're ready to capture speech before showing "Listening..."
            guard audioEngine.isRunning else {
                state = .error("Audio engine failed to start")
                print("❌ Audio engine failed to start")
                return
            }
            
            state = .listening
            isReadyToListen = true // Signal that we're ready to capture speech
            
            if let startTime = sessionStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                print("⏱ [TalkToMango] audio engine fully started at \(String(format: "%.2f", elapsed))s since startListening")
            }
            print("🎤 Audio engine fully started, ready to capture speech")
            print("🎤 Started listening... (state set to .listening)")
            print("🎤 audioEngine.isRunning = \(audioEngine.isRunning)")
            
            // ⚠️ UI STATE FLIP POINT: This is where we signal the UI to switch from "Getting ready..." to "Listening..."
            // The UI observes isReadyToListen and switches uiState from .preparing to .listening
            // This happens right after audioEngine.isRunning == true, ensuring we're truly ready to capture speech
            // Post notification that we're ready (for haptic feedback in UI)
            NotificationCenter.default.post(
                name: NSNotification.Name("SpeechRecognizerReadyToListen"),
                object: nil
            )
            
            // Verify recognition task is running
            if let task = recognitionTask {
                print("🎤 Recognition task state: isFinishing=\(task.isFinishing), isCancelled=\(task.isCancelled)")
            } else {
                print("⚠️ Recognition task is nil!")
            }
            
            // Don't start silence timer immediately - always wait grace period
            // This gives user time to start speaking without premature timeout
            Task { @MainActor in
                // Use grace period from config
                let gracePeriod = self.currentConfig.gracePeriod
                try? await Task.sleep(nanoseconds: UInt64(gracePeriod * 1_000_000_000))
                
                // Only start silence timer if we're still listening
                // By this point, user has had time to start speaking
                if case .listening = self.state {
                    print("🎤 Grace period ended, starting silence timer (mode: \(self.currentConfig.mode))")
                    self.startSilenceTimerIfNeeded()
                    self.startMaxDurationTimer()
                }
            }
        } catch {
            state = .error("Audio engine error: \(error.localizedDescription)")
            stopListening(reason: "error")
        }
    }
    
    // ⚠️ PRE-SPEECH TIMER: Detects "no speech at all" case
    // Starts when audio engine is ready, fires if no transcript received within silenceTimeout
    private func startSilenceTimerIfNeeded() {
        // For TalkToMango: only use pre-speech timer if we haven't received any transcript yet
        // Once we have transcript, post-speech timer takes over
        if currentConfig.mode == .talkToMango {
            if hasReceivedAnyResult {
                print("🎤 [TalkToMango] Not starting pre-speech timer – already have transcript (hasReceivedAnyResult = true)")
                return
            } else {
                print("🎤 [TalkToMango] No transcript yet - starting pre-speech timer for 'no speech' detection")
            }
        }
        
        // Cancel any existing pre-speech timer
        silenceTimer?.cancel()
        
        silenceTimer = Task {
            // Wait for silence timeout from config before auto-stopping
            let timeoutNanoseconds = UInt64(currentConfig.silenceTimeout * 1_000_000_000)
            try? await Task.sleep(nanoseconds: timeoutNanoseconds)
            
            // Only auto-stop if we're still listening and minimum duration has passed
            if case .listening = state,
               let startTime = recordingStartTime,
               Date().timeIntervalSince(startTime) >= minRecordingDuration {
                
                // For TalkToMango: defensive check - if we have transcript, don't cut off
                if currentConfig.mode == .talkToMango {
                    if hasReceivedAnyResult {
                        print("⚠️ [TalkToMango] Pre-speech timer fired but we already have transcript – ignoring, post-speech timer handles this.")
                        return
                    } else {
                        print("🎤 [TalkToMango] No speech at all before timeout – stopping as noSpeechDetected")
                        await MainActor.run {
                            stopListening(reason: "noSpeechDetected")
                        }
                        return
                    }
                }
                
                // For other modes (quickSearch), use existing behavior
                let reason = "silenceTimeout"
                print("🎤 Auto-stopping due to silence timeout (after \(currentConfig.silenceTimeout)s of silence, mode: \(currentConfig.mode))")
                await MainActor.run {
                    stopListening(reason: reason)
                }
            }
        }
    }
    
    // ⚠️ POST-SPEECH TIMER: Detects silence after user stops talking
    // Starts/resets on each recognition result after first transcript, fires after silenceTimeout seconds of silence
    private func startPostSpeechSilenceTimer() {
        // Only for TalkToMango mode
        guard currentConfig.mode == .talkToMango else { return }
        
        // Only start if we've received at least one transcript
        guard hasReceivedAnyResult, let lastSpeech = lastSpeechTime else {
            print("⚠️ [TalkToMango] Cannot start post-speech timer - no transcript yet")
            return
        }
        
        // Cancel any existing post-speech timer
        postSpeechSilenceTimer?.cancel()
        
        postSpeechSilenceTimer = Task {
            // Get silence timeout from TalkToMango config (not SpeechConfig)
            guard let talkToMangoConfig = currentTalkToMangoConfig else {
                print("⚠️ [TalkToMango] No TalkToMango config available for post-speech timer")
                return
            }
            
            // Wait for silence timeout from config (seconds since last transcript update)
            let timeoutNanoseconds = UInt64(talkToMangoConfig.silenceTimeoutAfterSpeech * 1_000_000_000)
            try? await Task.sleep(nanoseconds: timeoutNanoseconds)
            
            // Check if we're still listening and if silence has actually occurred
            // (i.e., lastSpeechTime hasn't been updated since we started this timer)
            if case .listening = state,
               let lastSpeechCheck = lastSpeechTime,
               lastSpeechCheck == lastSpeech { // lastSpeechTime hasn't changed = user stopped talking
                
                // Check if Apple already sent isFinal (shouldn't happen, but defensive)
                // If isFinal came, we would have already stopped, so this is just a safety check
                print("🎤 [TalkToMango] Post-speech timer fired - auto-stopping after \(talkToMangoConfig.silenceTimeoutAfterSpeech)s of silence since last transcript")
                await MainActor.run {
                    stopListening(reason: "TalkToMangoSilenceAfterSpeech")
                }
            } else {
                // lastSpeechTime was updated (user spoke again), timer was already reset
                print("🎤 [TalkToMango] Post-speech timer fired but user spoke again - timer already reset")
            }
        }
    }
    
    // Legacy method name for compatibility (used in transcript update reset logic)
    private func startSilenceTimer() {
        startSilenceTimerIfNeeded()
    }
    
    private func startMaxDurationTimer() {
        // Cancel any existing timer
        maxDurationTimer?.cancel()
        
        maxDurationTimer = Task {
            // Wait for max duration from config before auto-stopping (safety net)
            let maxDurationNanoseconds = UInt64(currentConfig.maxDuration * 1_000_000_000)
            try? await Task.sleep(nanoseconds: maxDurationNanoseconds)
            
            // Auto-stop if we're still listening
            if case .listening = state {
                let reason = currentConfig.mode == .talkToMango ? "TalkToMango maxDuration" : "maxDuration"
                print("🎤 Auto-stopping \(currentConfig.mode == .talkToMango ? "TalkToMango" : "") due to max duration (\(currentConfig.maxDuration)s)")
                await MainActor.run {
                    stopListening(reason: reason)
                }
            }
        }
    }
    
    func stopListening(reason: String = "userTappedStop") {
        print("🎙 stopListening() called (reason: \(reason), current state: \(state))")
        
        // Cancel all timers FIRST
        silenceTimer?.cancel()
        silenceTimer = nil
        postSpeechSilenceTimer?.cancel()
        postSpeechSilenceTimer = nil
        maxDurationTimer?.cancel()
        maxDurationTimer = nil
        
        // Only proceed if we're actually listening or requesting
        let canStop: Bool
        switch state {
        case .listening, .requesting, .processing:
            canStop = true
        default:
            canStop = false
        }
        
        guard canStop else {
            print("🎤 Already stopped or not listening (state: \(state))")
            return
        }
        
        print("🎤 Stopping... (current transcript: '\(transcript)', reason: \(reason))")
        
        // If user tapped Stop, prevent any transcript processing
        if reason == "userTappedStop" {
            shouldProcessTranscript = false
            print("🎤 User cancelled - setting shouldProcessTranscript = false")
        }
        
        // Handle TalkToMango transcript if we have one and haven't already handled it
        // (This covers the silence timeout case where isFinal might not have fired yet)
        // Skip if user cancelled (tapped Stop)
        if currentConfig.mode == .talkToMango && !transcript.isEmpty && reason != "finalFromApple" && shouldProcessTranscript {
            // Only handle if we have a transcript and it wasn't already handled via isFinal
            Task {
                await VoiceIntentRouter.handleTalkToMangoTranscript(transcript)
            }
        } else if reason == "userTappedStop" {
            print("🎤 Skipping transcript processing - user cancelled (tapped Stop)")
        }
        
        // IMMEDIATELY stop audio engine and remove tap
        if let audioEngine = audioEngine {
            print("🎤 Stopping audio engine...")
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            print("🎤 audioEngine.isRunning = \(audioEngine.isRunning)")
        }
        
        // End audio input to finalize recognition
        recognitionRequest?.endAudio()
        print("🎤 Ended audio input to recognition request")
        
        // Update state to processing immediately (so UI can react)
        state = .processing
        print("🎤 State changed to processing, transcript preserved: '\(transcript)'")
        
        // Wait for final transcript, then clean up
        Task { @MainActor in
            // Give recognition time to finalize (but shorter wait for responsiveness)
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
            
            // Cancel recognition task
            recognitionTask?.cancel()
            recognitionTask = nil
            print("🎤 Recognition task cancelled")
            
            // Clean up
            audioEngine = nil
            recognitionRequest = nil
            recordingStartTime = nil
            
            // Reset audio session
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("🎤 Audio session deactivated")
            
            // Finally go to idle
            if case .processing = state {
                state = .idle
                isReadyToListen = false
                print("🎤 State changed to idle, final transcript: '\(transcript)'")
            }
        }
    }
}

