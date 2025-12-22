//  MangoListeningView.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-12-03 at 09:45 PST (America/Los_Angeles - Pacific Time)
//  Last modified: 2025-12-03 at 11:59 PST by Cursor Assistant
//  Notes: Full-screen listening UI for TalkToMango voice interactions. Refined UX: "Getting ready..." → "Listening..." with strong visual cues (pulsing glow, scale animation). UI flips to listening state exactly when audio engine is ready (tied to "audio engine fully started" log point). Clear signal: when circle glows and label says "Listening...", user can talk.

import SwiftUI
import UIKit

enum ListeningUIState {
    case preparing
    case listening
}

struct MangoListeningView: View {
    @ObservedObject private var speechRecognizer: SpeechRecognizer
    @Binding var isPresented: Bool
    @State private var showTranscript: Bool = false
    @State private var hasReceivedFinalTranscript: Bool = false
    @State private var dismissTimer: Task<Void, Never>?
    @State private var uiState: ListeningUIState = .preparing
    @State private var wasCancelled: Bool = false  // Track if user tapped Stop to prevent processing
    
    init(speechRecognizer: SpeechRecognizer, isPresented: Binding<Bool>) {
        self.speechRecognizer = speechRecognizer
        self._isPresented = isPresented
    }
    
    var body: some View {
        ZStack {
            // Background with slight blur effect
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Large centered Mango icon
                ZStack {
                    // Glowing circle behind Mango - stronger when listening
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#FFA500").opacity(uiState == .listening ? 0.5 : 0.2),
                                    Color(hex: "#FF8C00").opacity(uiState == .listening ? 0.4 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 200, height: 200)
                        .blur(radius: uiState == .listening ? 30 : 15)
                        .scaleEffect(uiState == .listening ? 1.1 : 1.0)
                        .animation(
                            uiState == .listening ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .easeInOut(duration: 0.3),
                            value: uiState == .listening
                        )
                    
                    // Mango icon - pulse when listening
                    MangoLogoIcon(size: 120, color: .white)
                        .shadow(
                            color: Color(hex: "#FFA500").opacity(uiState == .listening ? 0.8 : 0.2),
                            radius: uiState == .listening ? 30 : 10,
                            x: 0,
                            y: 10
                        )
                        .scaleEffect(uiState == .listening ? 1.05 : 0.95)
                        .animation(
                            uiState == .listening ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .easeInOut(duration: 0.3),
                            value: uiState == .listening
                        )
                }
                
                // Listening text
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        // Pulsing dot indicator - only animate when truly listening
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .opacity(uiState == .listening ? 1.0 : 0.3)
                            .animation(
                                uiState == .listening ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                                value: uiState == .listening
                            )
                        
                        Text({
                            switch uiState {
                            case .preparing:
                                // Show "Getting ready..." while audio engine is starting
                                return "Getting ready..."
                            case .listening:
                                // Clear signal: when you see this, you can talk
                                return "Listening..."
                            }
                        }())
                        .font(.custom("Inter-Bold", size: 24))
                        .foregroundColor(.white)
                        .animation(.easeInOut(duration: 0.3), value: uiState)
                    }
                    
                    // Show transcript if available
                    if !speechRecognizer.transcript.isEmpty {
                        VStack(spacing: 20) {
                            Text(speechRecognizer.transcript)
                                .font(.custom("Inter-Regular", size: 18))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                                .transition(.opacity)
                            
                            // Finished button (only show when there's a transcript)
                            Button(action: {
                                finishListening()
                            }) {
                                Text("Finished")
                                    .font(.custom("Inter-Bold", size: 18))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 40)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 30)
                                            .fill(Color(hex: "#90EE90").opacity(0.9)) // Light green
                                    )
                            }
                            .transition(.opacity)
                        }
                    } else {
                        // Show hint text only when listening (not while preparing)
                        if uiState == .listening {
                            Text("Speak naturally...")
                                .font(.custom("Inter-Regular", size: 16))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.top, 8)
                        }
                    }
                }
                .animation(.easeInOut, value: speechRecognizer.transcript)
                .animation(.easeInOut, value: speechRecognizer.state)
                
                Spacer()
                
                // Stop button (lowered)
                Button(action: {
                    stopListening()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 20))
                        Text("Stop")
                            .font(.custom("Inter-Bold", size: 18))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(Color.white.opacity(0.2))
                    )
                }
                .padding(.bottom, 80) // Lowered from 60 to 80
            }
        }
        .onAppear {
            print("🎤 MangoListeningView.onAppear - starting listening")
            hasReceivedFinalTranscript = false
            dismissTimer?.cancel()
            dismissTimer = nil
            uiState = .preparing // Start in preparing state
            startListening()
        }
        .onChange(of: speechRecognizer.isReadyToListen) { oldValue, newValue in
            // ⚠️ UI STATE FLIP POINT: This is where the UI switches from "Getting ready..." to "Listening..."
            // Triggered when SpeechRecognizer sets isReadyToListen = true, which happens right after
            // the "Audio engine fully started, ready to capture speech" log point in SpeechRecognizer.swift
            // At this moment: audioEngine.isRunning == true, state == .listening, and we're truly ready to capture speech
            if newValue && uiState == .preparing {
                print("🎤 UI state: preparing → listening (ready to capture speech)")
                uiState = .listening
                
                // Haptic feedback when ready - clear signal that user can start talking
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                print("🎤 Haptic feedback triggered - user can start speaking")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SpeechRecognizerReadyToListen"))) { _ in
            // ⚠️ BACKUP UI STATE FLIP POINT: Also respond to notification (backup mechanism)
            // Same trigger point as above - ensures UI updates even if onChange doesn't fire
            if uiState == .preparing && speechRecognizer.isReadyToListen {
                print("🎤 UI state: preparing → listening (via notification)")
                uiState = .listening
                
                // Haptic feedback when ready
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }
        .onDisappear {
            print("🎤 MangoListeningView.onDisappear called (state: \(speechRecognizer.state))")
            // Cancel any pending dismiss timer
            dismissTimer?.cancel()
            dismissTimer = nil
            
            // Ensure we stop if view is dismissed unexpectedly
            // But don't call stopListening if we're already stopping/stopped
            let shouldStop: Bool
            switch speechRecognizer.state {
            case .listening, .requesting:
                shouldStop = true
            default:
                shouldStop = false
            }
            
            if shouldStop {
                print("🎤 View disappeared while listening, stopping recording")
                stopListening()
            } else {
                print("🎤 View disappeared but already stopped (state: \(speechRecognizer.state))")
            }
        }
        .onChange(of: speechRecognizer.state) { oldState, newState in
            print("🎤 MangoListeningView: state changed from \(oldState) to \(newState), transcript: '\(speechRecognizer.transcript)'")
            
            // Don't process transcript if user cancelled (tapped Stop) or view is dismissed
            guard !wasCancelled && isPresented else {
                print("🎤 Skipping transcript processing - wasCancelled: \(wasCancelled), isPresented: \(isPresented)")
                return
            }
            
            // When recording finishes (processing), handle the transcript
            if case .processing = newState, case .listening = oldState {
                print("🎤 Recording finished, handling final transcript")
                let hasTranscript = !speechRecognizer.transcript.isEmpty
                handleFinalTranscript()
                
                // If we have a final transcript, schedule dismiss
                if hasTranscript && hasReceivedFinalTranscript {
                    print("🎤 Has final transcript, will dismiss after delay")
                    scheduleDismiss()
                } else if hasTranscript {
                    print("🎤 Has transcript but waiting for final result before dismissing")
                    // Wait for final transcript notification
                } else {
                    // No transcript - this is a "No speech detected" case
                    // Dismiss after a brief delay to let user try again
                    print("⚠️ No transcript detected - will dismiss after brief delay")
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
                        await MainActor.run {
                            if isPresented && !wasCancelled {
                                print("🎤 Dismissing due to no transcript")
                                dismissListeningView()
                            }
                        }
                    }
                }
            }
            
            // If idle, dismiss if we're done (either with transcript or without)
            if case .idle = newState, case .processing = oldState {
                let hasTranscript = !speechRecognizer.transcript.isEmpty
                print("🎤 Recording fully stopped (hasTranscript: \(hasTranscript), hasFinal: \(hasReceivedFinalTranscript))")
                
                if hasTranscript && hasReceivedFinalTranscript {
                    // Has final transcript - dismiss smoothly
                    scheduleDismiss()
                } else if hasTranscript {
                    // Has transcript but no final yet - wait briefly
                    print("⚠️ Has transcript but no final result - waiting briefly")
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
                        await MainActor.run {
                            if isPresented && !wasCancelled {
                                if hasReceivedFinalTranscript {
                                    scheduleDismiss()
                                } else {
                                    // No final result - dismiss anyway
                                    print("🎤 No final result received, dismissing anyway")
                                    dismissListeningView()
                                }
                            }
                        }
                    }
                } else {
                    // No transcript - dismiss after brief delay
                    print("🎤 No transcript - dismissing after brief delay")
                    Task {
                        try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
                        await MainActor.run {
                            if isPresented && !wasCancelled {
                                dismissListeningView()
                            }
                        }
                    }
                }
            }
            
            // If error occurs, dismiss
            if case .error(let errorMessage) = newState {
                print("🎤 Error occurred: \(errorMessage) - dismissing")
                // Stop the recognizer if needed
                let shouldStop: Bool
                switch oldState {
                case .listening, .requesting:
                    shouldStop = true
                default:
                    shouldStop = false
                }
                if shouldStop {
                    Task {
                        speechRecognizer.stopListening(reason: "error")
                    }
                }
                // Dismiss after brief delay
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                    await MainActor.run {
                        if isPresented {
                            dismissListeningView()
                        }
                    }
                }
            }
        }
        .onChange(of: speechRecognizer.transcript) { oldValue, newValue in
            // Track when we get transcript updates (for debugging)
            if !newValue.isEmpty && newValue != oldValue {
                print("🎤 MangoListeningView: transcript updated: '\(newValue)'")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SpeechRecognizerFinalTranscript"))) { notification in
            // Don't process if user cancelled (tapped Stop) or view is dismissed
            guard !wasCancelled && isPresented else {
                print("🎤 Skipping final transcript notification - wasCancelled: \(wasCancelled), isPresented: \(isPresented)")
                return
            }
            
            // When final transcript is received, mark it so we can dismiss
            print("🎤 MangoListeningView: Received final transcript notification")
            hasReceivedFinalTranscript = true
            
            // If we're already in processing state, schedule dismiss
            if case .processing = speechRecognizer.state {
                let hasTranscript = !speechRecognizer.transcript.isEmpty
                if hasTranscript {
                    print("🎤 Final transcript received while processing, scheduling dismiss")
                    scheduleDismiss()
                }
            }
        }
    }
    
    private func startListening() {
        Task {
            // Use TalkToMango config for conversational, longer pauses
            await speechRecognizer.startListening(config: .talkToMango)
        }
    }
    
    private func stopListening() {
        print("🎤 MangoListeningView.stopListening() called (user tapped Stop)")
        print("🎤 Current transcript: '\(speechRecognizer.transcript)'")
        print("🎤 Current state: \(speechRecognizer.state)")
        
        // Set cancellation flag to prevent any transcript processing
        wasCancelled = true
        
        // Cancel any pending dismiss timer
        dismissTimer?.cancel()
        dismissTimer = nil
        
        // Stop the recognizer if it's still running
        let shouldStop: Bool
        switch speechRecognizer.state {
        case .listening, .requesting:
            shouldStop = true
        default:
            shouldStop = false
        }
        if shouldStop {
            Task {
                speechRecognizer.stopListening(reason: "userTappedStop")
            }
        }
        
        // ALWAYS dismiss when user taps Stop, regardless of transcript
        // User explicitly wants to exit and go back to previous screen
        // Navigate to Home tab to avoid showing blank Talk to Mango screen
        print("🎤 User tapped Stop - dismissing view immediately and navigating to Home (cancelled: true)")
        NotificationCenter.default.post(
            name: .mangoNavigateToHome,
            object: nil
        )
        isPresented = false
    }
    
    private func finishListening() {
        print("🎤 MangoListeningView.finishListening() called (user tapped Finished)")
        print("🎤 Current transcript: '\(speechRecognizer.transcript)'")
        
        // Cancel any pending dismiss timer
        dismissTimer?.cancel()
        dismissTimer = nil
        
        // Stop the recognizer if it's still running
        let shouldStop: Bool
        switch speechRecognizer.state {
        case .listening, .requesting:
            shouldStop = true
        default:
            shouldStop = false
        }
        if shouldStop {
            Task {
                speechRecognizer.stopListening(reason: "userTappedFinished")
            }
        }
        
        // Process the transcript and dismiss
        handleFinalTranscript()
        print("🎤 User tapped Finished - processing transcript and dismissing")
        
        // Dismiss after a brief delay to allow transcript processing
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            await MainActor.run {
                if isPresented {
                    isPresented = false
                }
            }
        }
    }
    
    private func dismissListeningView() {
        print("🎤 dismissListeningView() called")
        // Cancel any pending dismiss timer
        dismissTimer?.cancel()
        dismissTimer = nil
        // Dismiss the view
        isPresented = false
    }
    
    private func handleFinalTranscript() {
        // Don't process if user cancelled (tapped Stop) or view is dismissed
        guard !wasCancelled && isPresented else {
            print("🎤 handleFinalTranscript() skipped - wasCancelled: \(wasCancelled), isPresented: \(isPresented)")
            return
        }
        
        let transcript = speechRecognizer.transcript
        if !transcript.isEmpty {
            // Route to VoiceIntentRouter
            VoiceIntentRouter.handle(utterance: transcript, source: .talkToMango)
        }
    }
    
    private func scheduleDismiss() {
        // Cancel any existing dismiss timer
        dismissTimer?.cancel()
        
        // Schedule dismiss after a smooth delay (0.8-1.0s)
        dismissTimer = Task {
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s - smooth delay
            await MainActor.run {
                if isPresented {
                    print("🎤 Dismissing after final transcript with smooth delay")
                    isPresented = false
                }
            }
        }
    }
}

#Preview {
    @Previewable @State var isPresented = true
    MangoListeningView(
        speechRecognizer: SpeechRecognizer(),
        isPresented: $isPresented
    )
}

