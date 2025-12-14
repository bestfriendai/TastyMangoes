// DashboardView.swift
// Created automatically by Cursor Assistant
// Created on: 2025-01-15 at 14:35 (America/Los_Angeles - Pacific Time)
// Notes: Voice events debugging dashboard for monitoring voice interactions and analytics

import SwiftUI
import Supabase

typealias VoiceEvent = SupabaseService.VoiceEvent

struct DashboardView: View {
    @State private var events: [VoiceEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFilter: FilterType = .all
    @State private var selectedEvent: VoiceEvent?
    
    enum FilterType: String, CaseIterable {
        case all = "All"
        case success = "Success"
        case failed = "Failed"
        case llm = "LLM"
    }
    
    var filteredEvents: [VoiceEvent] {
        switch selectedFilter {
        case .all:
            return events
        case .success:
            return events.filter { $0.handler_result == "success" }
        case .failed:
            return events.filter { $0.handler_result == "no_results" || $0.handler_result == "parse_error" }
        case .llm:
            return events.filter { $0.llm_used == true }
        }
    }
    
    var stats: (total: Int, success: Int, failed: Int, llmUsed: Int, successRate: Int) {
        let total = events.count
        let success = events.filter { $0.handler_result == "success" }.count
        let failed = events.filter { $0.handler_result == "no_results" || $0.handler_result == "parse_error" }.count
        let llmUsed = events.filter { $0.llm_used == true }.count
        let successRate = total > 0 ? Int((Double(success) / Double(total)) * 100) : 0
        return (total, success, failed, llmUsed, successRate)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats Bar
                statsBar
                
                // Filters
                filterBar
                
                // Events List
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = errorMessage {
                    VStack {
                        Text("Error: \(errorMessage)")
                            .foregroundColor(.red)
                            .padding()
                        Button("Retry") {
                            Task {
                                await fetchEvents()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    eventsList
                }
            }
            .navigationTitle("Voice Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task {
                            await fetchEvents()
                        }
                    }
                }
            }
            .task {
                await fetchEvents()
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event)
            }
        }
    }
    
    private var statsBar: some View {
        let stats = self.stats
        return HStack(spacing: 16) {
            StatItem(label: "Total", value: "\(stats.total)", color: .orange)
            StatItem(label: "Success", value: "\(stats.success)", color: .green)
            StatItem(label: "Failed", value: "\(stats.failed)", color: .red)
            StatItem(label: "LLM", value: "\(stats.llmUsed)", color: .purple)
            StatItem(label: "Rate", value: "\(stats.successRate)%", color: .blue)
        }
        .padding()
        .background(Color(hex: "#f3f3f3"))
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterType.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                    }) {
                        Text(filter.rawValue)
                            .font(.custom("Inter-Regular", size: 14))
                            .foregroundColor(selectedFilter == filter ? .white : Color(hex: "#333333"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedFilter == filter ? Color(hex: "#FEA500") : Color.white)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color.white)
    }
    
    private var eventsList: some View {
        List(filteredEvents) { event in
            EventRowView(event: event)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedEvent = event
                }
        }
        .listStyle(PlainListStyle())
    }
    
    private func fetchEvents() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await SupabaseService.shared.getVoiceEvents(limit: 100)
            
            await MainActor.run {
                self.events = response
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

struct StatItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("Nunito-Bold", size: 20))
                .foregroundColor(color)
            Text(label)
                .font(.custom("Inter-Regular", size: 12))
                .foregroundColor(Color(hex: "#666666"))
        }
        .frame(maxWidth: .infinity)
    }
}

struct EventRowView: View {
    let event: VoiceEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatTime(event.created_at))
                    .font(.custom("Inter-Regular", size: 12))
                    .foregroundColor(Color(hex: "#666666"))
                
                Spacer()
                
                if event.llm_used == true {
                    Text("🤖")
                        .font(.system(size: 14))
                }
                
                ResultBadge(result: event.handler_result, count: event.result_count)
            }
            
            Text("\"\(event.utterance)\"")
                .font(.custom("Inter-Regular", size: 16))
                .foregroundColor(Color(hex: "#333333"))
                .lineLimit(2)
            
            if let commandType = event.final_command_type ?? event.mango_command_type {
                Text(commandType)
                    .font(.custom("Inter-Regular", size: 12))
                    .foregroundColor(Color(hex: "#666666"))
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm:ss"
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct ResultBadge: View {
    let result: String?
    let count: Int?
    
    var body: some View {
        if let result = result {
            let (color, text) = badgeInfo(for: result)
            HStack(spacing: 4) {
                Text(text)
                    .font(.custom("Inter-Regular", size: 10))
                if result == "success", let count = count {
                    Text("(\(count))")
                        .font(.custom("Inter-Regular", size: 10))
                        .opacity(0.7)
                }
            }
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .cornerRadius(4)
        } else {
            Text("—")
                .font(.custom("Inter-Regular", size: 10))
                .foregroundColor(Color(hex: "#999999"))
        }
    }
    
    private func badgeInfo(for result: String) -> (Color, String) {
        switch result {
        case "success":
            return (.green, "✓")
        case "no_results":
            return (.orange, "∅")
        case "ambiguous":
            return (.blue, "?")
        case "network_error", "parse_error":
            return (.red, "✗")
        default:
            return (.gray, result)
        }
    }
}

struct EventDetailView: View {
    let event: VoiceEvent
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    EventDetailRow(label: "Time", value: formatFullTime(event.created_at))
                    EventDetailRow(label: "Utterance", value: event.utterance)
                    EventDetailRow(label: "Command Type", value: event.final_command_type ?? event.mango_command_type ?? "—")
                    EventDetailRow(label: "Result", value: event.handler_result ?? "—")
                    if let count = event.result_count {
                        EventDetailRow(label: "Result Count", value: "\(count)")
                    }
                    EventDetailRow(label: "LLM Used", value: event.llm_used == true ? "Yes" : "No")
                    if let title = event.mango_command_movie_title {
                        EventDetailRow(label: "Movie Title", value: title)
                    }
                    if let recommender = event.mango_command_recommender {
                        EventDetailRow(label: "Recommender", value: recommender)
                    }
                }
                .padding()
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatFullTime(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, yyyy 'at' HH:mm:ss"
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct EventDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Inter-Regular", size: 12))
                .foregroundColor(Color(hex: "#666666"))
            Text(value)
                .font(.custom("Inter-Regular", size: 16))
                .foregroundColor(Color(hex: "#333333"))
        }
    }
}


#Preview {
    DashboardView()
}
