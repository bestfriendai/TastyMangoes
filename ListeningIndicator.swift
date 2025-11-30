//  ListeningIndicator.swift
//  Created automatically by Cursor Assistant
//  Created on: 2025-01-15 at 22:30 (America/Los_Angeles - Pacific Time)
//  Notes: Visual indicator component for speech recognition listening state

import SwiftUI

struct ListeningIndicator: View {
    let transcript: String
    let onStop: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Waveform animation
            HStack(spacing: 4) {
                ForEach(0..<5) { i in
                    WaveformBar(delay: Double(i) * 0.1)
                }
            }
            .frame(height: 30)
            
            // Live transcript or placeholder
            if !transcript.isEmpty {
                Text(transcript)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Text("Listening...")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            // Stop button
            Button(action: onStop) {
                HStack(spacing: 8) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 20))
                    Text("Stop Recording")
                        .font(.custom("Nunito-Bold", size: 16))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.red)
                .cornerRadius(24)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding()
    }
}

struct WaveformBar: View {
    let delay: Double
    @State private var animating = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.red)
            .frame(width: 4, height: animating ? 24 : 8)
            .animation(
                .easeInOut(duration: 0.4)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: animating
            )
            .onAppear {
                animating = true
            }
    }
}


