// DashboardView.swift
// Created automatically by Cursor Assistant
// Created on: 2025-01-15 at 14:35 (America/Los_Angeles - Pacific Time)
// Last modified by Claude: 2025-12-15 at 11:15 (America/Los_Angeles - Pacific Time) / 19:15 UTC
// Notes: Voice events debugging dashboard for monitoring voice interactions and analytics
//        Phase 2: Added search_intent filter, intent badges, confidence display, extracted hints

import SwiftUI
import Supabase

typealias VoiceEvent = SupabaseService.VoiceEvent

struct DashboardView: View {
    @State private var events: [VoiceEvent] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFilter: FilterType = .all
    @State private var selectedIntentFilter: IntentFilterType = .all
    @State private var selectedEvent: VoiceEvent?
    
    enum FilterType: String, CaseIterable {
        case all = "All"
        case success = "Success"
        case failed = "Failed"
        case llm = "LLM"
    }
    
    // New: Intent filter
    enum IntentFilterType: String, CaseIterable {
        case all = "All Intents"
        case direct = "Direct"
        case fuzzy = "Fuzzy"
        case actionOnly = "Actions"
        case unknown = "Unknown"
        
        var dbValue: String? {
            switch self {
            case .all: return nil
            case .direct: return "direct"
            case .fuzzy: return "fuzzy"
            case .actionOnly: return "action_only"
            case .unknown: return nil // Will filter for nil/unknown
            }
        }
    }
    
    var filteredEvents: [VoiceEvent] {
        var filtered = events
        
        // Apply result filter
        switch selectedFilter {
        case .all:
            break
        case .success:
            filtered = filtered.filter { $0.handler_result == "success" }
        case .failed:
            filtered = filtered.filter { $0.handler_result == "no_results" || $0.handler_result == "parse_error" }
        case .llm:
            filtered = filtered.filter { $0.llm_used == true }
        }
        
        // Apply intent filter
        switch selectedIntentFilter {
        case .all:
            break
        case .unknown:
            filtered = filtered.filter { $0.search_intent == nil || $0.search_intent == "unknown" }
        default:
            if let intentValue = selectedIntentFilter.dbValue {
                filtered = filtered.filter { $0.search_intent == intentValue }
            }
        }
        
        return filtered
    }
    
    var stats: (total: Int, success: Int, failed: Int, llmUsed: Int, successRate: Int) {
        let total = events.count
        let success = events.filter { $0.handler_result == "success" }.count
        let failed = events.filter { $0.handler_result == "no_results" || $0.handler_result == "parse_error" }.count
        let llmUsed = events.filter { $0.llm_used == true }.count
        let successRate = total > 0 ? Int((Double(success) / Double(total)) * 100) : 0
        return (total, success, failed, llmUsed, successRate)
    }
    
    // New: Intent stats
    var intentStats: (direct: Int, fuzzy: Int, actions: Int, unknown: Int) {
        let direct = events.filter { $0.search_intent == "direct" }.count
        let fuzzy = events.filter { $0.search_intent == "fuzzy" }.count
        let actions = events.filter { $0.search_intent == "action_only" }.count
        let unknown = events.filter { $0.search_intent == nil || $0.search_intent == "unknown" }.count
        return (direct, fuzzy, actions, unknown)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats Bar
                statsBar
                
                // Intent Stats Bar (New)
                intentStatsBar
                
                // Filters
                filterBar
                
                // Intent Filters (New)
                intentFilterBar
                
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
    
    // New: Intent stats bar
    private var intentStatsBar: some View {
        let stats = self.intentStats
        return HStack(spacing: 16) {
            StatItem(label: "Direct", value: "\(stats.direct)", color: .blue)
            StatItem(label: "Fuzzy", value: "\(stats.fuzzy)", color: .purple)
            StatItem(label: "Actions", value: "\(stats.actions)", color: .gray)
            StatItem(label: "Unknown", value: "\(stats.unknown)", color: .orange)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(hex: "#fafafa"))
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
    
    // New: Intent filter bar
    private var intentFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(IntentFilterType.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedIntentFilter = filter
                    }) {
                        Text(filter.rawValue)
                            .font(.custom("Inter-Regular", size: 12))
                            .foregroundColor(selectedIntentFilter == filter ? .white : Color(hex: "#666666"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(selectedIntentFilter == filter ? intentColor(for: filter) : Color(hex: "#f0f0f0"))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 4)
        .background(Color.white)
    }
    
    private func intentColor(for filter: IntentFilterType) -> Color {
        switch filter {
        case .all: return Color(hex: "#FEA500")
        case .direct: return .blue
        case .fuzzy: return .purple
        case .actionOnly: return .gray
        case .unknown: return .orange
        }
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
                
                // New: Intent badge
                IntentBadge(intent: event.search_intent, confidence: event.confidence_score)
                
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
            
            HStack {
                if let commandType = event.final_command_type ?? event.mango_command_type {
                    Text(commandType)
                        .font(.custom("Inter-Regular", size: 12))
                        .foregroundColor(Color(hex: "#666666"))
                }
                
                Spacer()
                
                // New: Show confidence bar if available
                if let confidence = event.confidence_score {
                    ConfidenceIndicator(score: confidence)
                }
            }
            
            // New: Show extracted hints preview if available
            if let hints = event.extracted_hints, !hints.isEmpty {
                HintsPreview(hintsJson: hints)
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

// New: Intent badge component
struct IntentBadge: View {
    let intent: String?
    let confidence: Double?
    
    var body: some View {
        if let intent = intent {
            Text(intentLabel(intent))
                .font(.custom("Inter-Regular", size: 10))
                .foregroundColor(intentColor(intent))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(intentColor(intent).opacity(0.15))
                .cornerRadius(4)
        }
    }
    
    private func intentLabel(_ intent: String) -> String {
        switch intent {
        case "direct": return "Direct"
        case "fuzzy": return "Fuzzy"
        case "action_only": return "Action"
        case "import": return "Import"
        default: return intent
        }
    }
    
    private func intentColor(_ intent: String) -> Color {
        switch intent {
        case "direct": return .blue
        case "fuzzy": return .purple
        case "action_only": return .gray
        case "import": return .green
        default: return .orange
        }
    }
}

// New: Confidence indicator
struct ConfidenceIndicator: View {
    let score: Double
    
    var body: some View {
        HStack(spacing: 4) {
            // Mini bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(hex: "#e0e0e0"))
                    Rectangle()
                        .fill(barColor)
                        .frame(width: geo.size.width * score)
                }
            }
            .frame(width: 30, height: 4)
            .cornerRadius(2)
            
            Text("\(Int(score * 100))%")
                .font(.custom("Inter-Regular", size: 10))
                .foregroundColor(Color(hex: "#999999"))
        }
    }
    
    private var barColor: Color {
        if score >= 0.82 {
            return .green
        } else if score >= 0.70 {
            return .yellow
        } else {
            return .red
        }
    }
}

// New: Hints preview component
struct HintsPreview: View {
    let hintsJson: String
    
    var body: some View {
        if let hints = parseHints() {
            HStack(spacing: 8) {
                if let year = hints.year {
                    HintChip(icon: "📅", text: "\(year)")
                }
                if let decade = hints.decade {
                    HintChip(icon: "📅", text: "\(decade)s")
                }
                if !hints.actors.isEmpty {
                    HintChip(icon: "🎭", text: hints.actors.first ?? "")
                }
                if let director = hints.director {
                    HintChip(icon: "🎬", text: director)
                }
                if hints.isRemakeHint {
                    HintChip(icon: "🔄", text: "remake")
                }
            }
        }
    }
    
    private func parseHints() -> ParsedHints? {
        guard let data = hintsJson.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ParsedHints.self, from: data)
    }
    
    struct ParsedHints: Codable {
        var titleLikely: String?
        var year: Int?
        var decade: Int?
        var actors: [String]
        var director: String?
        var keywords: [String]
        var isRemakeHint: Bool
        
        enum CodingKeys: String, CodingKey {
            case titleLikely = "title_likely"
            case year
            case decade
            case actors
            case director
            case keywords
            case isRemakeHint = "is_remake_hint"
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            titleLikely = try container.decodeIfPresent(String.self, forKey: .titleLikely)
            year = try container.decodeIfPresent(Int.self, forKey: .year)
            decade = try container.decodeIfPresent(Int.self, forKey: .decade)
            actors = try container.decodeIfPresent([String].self, forKey: .actors) ?? []
            director = try container.decodeIfPresent(String.self, forKey: .director)
            keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
            isRemakeHint = try container.decodeIfPresent(Bool.self, forKey: .isRemakeHint) ?? false
        }
    }
}

struct HintChip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 2) {
            Text(icon)
                .font(.system(size: 10))
            Text(text)
                .font(.custom("Inter-Regular", size: 10))
                .foregroundColor(Color(hex: "#666666"))
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color(hex: "#f5f5f5"))
        .cornerRadius(4)
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
                    // Basic Info
                    EventDetailRow(label: "Time", value: formatFullTime(event.created_at))
                    EventDetailRow(label: "Utterance", value: event.utterance)
                    EventDetailRow(label: "Command Type", value: event.final_command_type ?? event.mango_command_type ?? "—")
                    EventDetailRow(label: "Result", value: event.handler_result ?? "—")
                    if let count = event.result_count {
                        EventDetailRow(label: "Result Count", value: "\(count)")
                    }
                    EventDetailRow(label: "LLM Used", value: event.llm_used == true ? "Yes" : "No")
                    
                    // New: Phase 2 Intent Info Section
                    Divider()
                    Text("Intent Analysis")
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(Color(hex: "#333333"))
                    
                    EventDetailRow(label: "Search Intent", value: event.search_intent ?? "—")
                    if let confidence = event.confidence_score {
                        EventDetailRow(label: "Confidence", value: String(format: "%.0f%%", confidence * 100))
                    }
                    if let candidates = event.candidates_shown {
                        EventDetailRow(label: "Candidates Shown", value: "\(candidates)")
                    }
                    if let selectedMovie = event.selected_movie_id {
                        EventDetailRow(label: "Selected Movie ID", value: "\(selectedMovie)")
                    }
                    
                    // New: Extracted Hints Section
                    if let hints = event.extracted_hints, !hints.isEmpty {
                        Divider()
                        Text("Extracted Hints")
                            .font(.custom("Nunito-Bold", size: 16))
                            .foregroundColor(Color(hex: "#333333"))
                        
                        ExtractedHintsDetailView(hintsJson: hints)
                    }
                    
                    // New: Handoff Info Section
                    if event.handoff_initiated == true {
                        Divider()
                        Text("External Handoff")
                            .font(.custom("Nunito-Bold", size: 16))
                            .foregroundColor(Color(hex: "#333333"))
                        
                        EventDetailRow(label: "Handoff Initiated", value: "Yes")
                        EventDetailRow(label: "Returned", value: event.handoff_returned == true ? "Yes" : "No")
                    }
                    
                    // New: Clarification Section
                    if let question = event.clarifying_question_asked {
                        Divider()
                        Text("Clarification")
                            .font(.custom("Nunito-Bold", size: 16))
                            .foregroundColor(Color(hex: "#333333"))
                        
                        EventDetailRow(label: "Question Asked", value: question)
                        EventDetailRow(label: "Answer", value: event.clarifying_answer ?? "—")
                    }
                    
                    // Original fields
                    Divider()
                    Text("Original Parse")
                        .font(.custom("Nunito-Bold", size: 16))
                        .foregroundColor(Color(hex: "#333333"))
                    
                    if let title = event.mango_command_movie_title {
                        EventDetailRow(label: "Movie Title", value: title)
                    }
                    if let recommender = event.mango_command_recommender {
                        EventDetailRow(label: "Recommender", value: recommender)
                    }
                    if let error = event.error_message {
                        EventDetailRow(label: "Error", value: error)
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

// New: Detailed hints view for EventDetailView
struct ExtractedHintsDetailView: View {
    let hintsJson: String
    
    var body: some View {
        if let hints = parseHints() {
            VStack(alignment: .leading, spacing: 8) {
                if let title = hints.titleLikely {
                    EventDetailRow(label: "Likely Title", value: title)
                }
                if let year = hints.year {
                    EventDetailRow(label: "Year", value: "\(year)")
                }
                if let decade = hints.decade {
                    EventDetailRow(label: "Decade", value: "\(decade)s")
                }
                if !hints.actors.isEmpty {
                    EventDetailRow(label: "Actors", value: hints.actors.joined(separator: ", "))
                }
                if let director = hints.director {
                    EventDetailRow(label: "Director", value: director)
                }
                if !hints.keywords.isEmpty {
                    EventDetailRow(label: "Keywords", value: hints.keywords.joined(separator: ", "))
                }
                if hints.isRemakeHint {
                    EventDetailRow(label: "Remake Hint", value: "Yes")
                }
                if !hints.plotClues.isEmpty {
                    EventDetailRow(label: "Plot Clues", value: hints.plotClues.joined(separator: "; "))
                }
            }
        } else {
            Text("Could not parse hints")
                .font(.custom("Inter-Regular", size: 14))
                .foregroundColor(Color(hex: "#999999"))
        }
    }
    
    private func parseHints() -> ParsedHints? {
        guard let data = hintsJson.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ParsedHints.self, from: data)
    }
    
    struct ParsedHints: Codable {
        var titleLikely: String?
        var year: Int?
        var decade: Int?
        var actors: [String]
        var director: String?
        var keywords: [String]
        var plotClues: [String]
        var isRemakeHint: Bool
        
        enum CodingKeys: String, CodingKey {
            case titleLikely = "title_likely"
            case year
            case decade
            case actors
            case director
            case keywords
            case plotClues = "plot_clues"
            case isRemakeHint = "is_remake_hint"
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            titleLikely = try container.decodeIfPresent(String.self, forKey: .titleLikely)
            year = try container.decodeIfPresent(Int.self, forKey: .year)
            decade = try container.decodeIfPresent(Int.self, forKey: .decade)
            actors = try container.decodeIfPresent([String].self, forKey: .actors) ?? []
            director = try container.decodeIfPresent(String.self, forKey: .director)
            keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
            plotClues = try container.decodeIfPresent([String].self, forKey: .plotClues) ?? []
            isRemakeHint = try container.decodeIfPresent(Bool.self, forKey: .isRemakeHint) ?? false
        }
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
