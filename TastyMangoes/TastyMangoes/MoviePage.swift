import SwiftUI

// MARK: - Color Theme (from Figma)
extension Color {
    // Primary Colors
    static let background = Color(red: 0/255, green: 0/255, blue: 0/255)
    static let primaryText = Color(red: 26/255, green: 26/255, blue: 26/255)
    static let secondaryText = Color(red: 102/255, green: 102/255, blue: 102/255)
    static let tertiaryText = Color(red: 153/255, green: 153/255, blue: 153/255)

    // Surface Colors
    static let surfacePrimary = Color(red: 51/255, green: 51/255, blue: 51/255)
    static let surfaceSecondary = Color(red: 243/255, green: 243/255, blue: 243/255)
    static let surfaceTertiary = Color(red: 253/255, green: 253/255, blue: 253/255)

    // Accent Colors
    static let mangoGreen = Color(red: 100/255, green: 141/255, blue: 0/255)
    static let mangoYellow = Color(red: 196/255, green: 197/255, blue: 92/255)
    static let aiOrange = Color(red: 254/255, green: 165/255, blue: 0/255)
    static let accentBrown = Color(red: 181/255, green: 105/255, blue: 0/255)

    // Text from Figma
    static let lightText = Color(red: 243/255, green: 243/255, blue: 243/255)
    static let midGray = Color(red: 128/255, green: 128/255, blue: 128/255)
}

// MARK: - Main Movie Page View
struct MoviePageView: View {
    let movie: Movie
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Body Section
                VStack(spacing: 16) {
                    // General Info Section
                    GeneralSection()

                    // Rate Bloc
                    RateBlocSection()

                    // Card Group (Platform & Friends)
                    CardGroupSection()
                }
                .padding(.horizontal, 16)

                // Tab Bar
                TabBarSection(selectedTab: $selectedTab)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                // Tab Content
                VStack(spacing: 24) {
                    switch selectedTab {
                    case 0:
                        OverviewSection()
                    case 1:
                        CastAndCrewSection()
                    case 2:
                        ReviewsSection()
                    case 3:
                        MoreToWatchSection()
                    case 4:
                        MovieClipsSection()
                    case 5:
                        PhotosSection()
                    default:
                        OverviewSection()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
            }
            .padding(.bottom, 32)
        }
        .background(Color.background)
    }
}

// MARK: - General Section (Video + Rate)
struct GeneralSection: View {
    var body: some View {
        VStack(spacing: 12) {
            // Video Frame
            VideoFrame()

            // Container (Poster + Score)
            HStack(alignment: .top, spacing: 12) {
                // Movie Poster Image
                ImgFrame()
                    .frame(width: 84, height: 124)

                // Score Section
                ScoreSection()

                Spacer()
            }
        }
    }
}

// MARK: - Video Frame
struct VideoFrame: View {
    var body: some View {
        ZStack {
            // Video Background with Gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.6),
                            Color.black.opacity(0.4),
                            Color.black.opacity(0.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    // Placeholder for video/image
                    Color.gray.opacity(0.3)
                )
                .cornerRadius(8)
                .frame(height: 193)

            // Video Content Overlay
            VStack {
                Spacer()
                HStack(spacing: 6) {
                    // Play Icon
                    Image(systemName: "play.fill")
                        .resizable()
                        .frame(width: 14, height: 14)
                        .foregroundColor(.lightText)

                    // Text Bloc
                    HStack(spacing: 4) {
                        Text("Play Trailer")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.lightText)

                        Text("4:20")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 236/255, green: 236/255, blue: 236/255))
                    }

                    Spacer()
                }
                .padding(12)
            }
        }
    }
}

// MARK: - Image Frame (Poster)
struct ImgFrame: View {
    var body: some View {
        Rectangle()
            .fill(Color.surfacePrimary)
            .overlay(
                // Placeholder for movie poster
                Image(systemName: "film")
                    .resizable()
                    .scaledToFit()
                    .padding(20)
                    .foregroundColor(.midGray)
            )
            .cornerRadius(8)
    }
}

// MARK: - Score Section
struct ScoreSection: View {
    var body: some View {
        HStack(spacing: 8) {
            // Tasty Score Card
            CardTastyScore(percentage: "64%")

            // Divider
            Rectangle()
                .fill(Color(red: 236/255, green: 236/255, blue: 236/255))
                .frame(width: 1, height: 40)

            // AI Score Card
            CardAIScore(score: "5.9")
        }
    }
}

// MARK: - Card / Tasty Score
struct CardTastyScore: View {
    let percentage: String

    var body: some View {
        VStack(spacing: 2) {
            // Description
            HStack(spacing: 2) {
                // Mango Icon
                Image(systemName: "leaf.fill")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundColor(.mangoGreen)

                Text("Tasty Score")
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)

                // Info Icon
                Image(systemName: "info.circle")
                    .resizable()
                    .frame(width: 14, height: 14)
                    .foregroundColor(.secondaryText)
            }

            // Rate Score
            Text(percentage)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primaryText)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

// MARK: - Card / AI Score
struct CardAIScore: View {
    let score: String

    var body: some View {
        VStack(spacing: 2) {
            // Description
            HStack(spacing: 2) {
                // AI Icon
                Image(systemName: "brain")
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundColor(.aiOrange)

                Text("AI Score")
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)

                // Info Icon
                Image(systemName: "info.circle")
                    .resizable()
                    .frame(width: 14, height: 14)
                    .foregroundColor(.secondaryText)
            }

            // Rate Score
            Text(score)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primaryText)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

// MARK: - Rate Bloc Section
struct RateBlocSection: View {
    var body: some View {
        HStack(spacing: 8) {
            // Badge with AI icon
            HStack(spacing: 4) {
                Image(systemName: "brain")
                    .resizable()
                    .frame(width: 12, height: 12)
                    .foregroundColor(.aiOrange)

                Text("AI Generated")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondaryText)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.surfaceSecondary)
            .cornerRadius(4)

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Card Group Section
struct CardGroupSection: View {
    var body: some View {
        HStack(spacing: 12) {
            // Platform Card
            CardPlatform()

            // Friends Card
            CardFriends()
        }
    }
}

// MARK: - Card / Platform
struct CardPlatform: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top Section
            HStack {
                Text("Platforms")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .resizable()
                    .frame(width: 8, height: 12)
                    .foregroundColor(.secondaryText)
            }

            // Avatar Group
            HStack(spacing: -8) {
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(Color.surfacePrimary)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(Color.background, lineWidth: 2)
                        )
                }
            }
        }
        .padding(12)
        .background(Color.surfaceSecondary)
        .cornerRadius(8)
    }
}

// MARK: - Card / Friends
struct CardFriends: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top Section
            HStack {
                Text("Friends")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryText)

                Spacer()

                Image(systemName: "chevron.right")
                    .resizable()
                    .frame(width: 8, height: 12)
                    .foregroundColor(.secondaryText)
            }

            // Avatar Group
            HStack(spacing: -8) {
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(Color.surfacePrimary)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(Color.background, lineWidth: 2)
                        )
                }
            }
        }
        .padding(12)
        .background(Color.surfaceSecondary)
        .cornerRadius(8)
    }
}

// MARK: - Tab Bar Section
struct TabBarSection: View {
    @Binding var selectedTab: Int
    let tabs = ["Overview", "Cast & Crew", "Reviews", "More to Watch", "Clips", "Photos"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    TabButton(
                        title: tabs[index],
                        isSelected: selectedTab == index,
                        action: { selectedTab = index }
                    )
                }
            }
        }
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .primaryText : .secondaryText)

                if isSelected {
                    Rectangle()
                        .fill(Color.mangoGreen)
                        .frame(height: 2)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 2)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Overview Section
struct OverviewSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Badge Group
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["Action", "Sci-Fi", "2024", "PG-13"], id: \.self) { badge in
                        BadgeView(text: badge)
                    }
                }
            }

            // Table (Movie Info)
            VStack(spacing: 12) {
                TableRow(label: "Director", value: "Christopher Nolan")
                TableRow(label: "Runtime", value: "2h 49min")
                TableRow(label: "Release Date", value: "July 21, 2024")
                TableRow(label: "Language", value: "English")
            }
            .padding(12)
            .background(Color.surfaceSecondary)
            .cornerRadius(8)

            // Read More Button
            Button(action: {}) {
                HStack {
                    Text("Read More")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primaryText)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .resizable()
                        .frame(width: 8, height: 12)
                        .foregroundColor(.secondaryText)
                }
                .padding(12)
                .background(Color.surfaceSecondary)
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Table Row
struct TableRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondaryText)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primaryText)
        }
    }
}

// MARK: - Badge View
struct BadgeView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.primaryText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.surfaceSecondary)
            .cornerRadius(16)
    }
}

// MARK: - Cast & Crew Section
struct CastAndCrewSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Top
            SectionTop(title: "Cast & Crew")

            // Actor Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<5) { _ in
                        CardActor()
                    }
                }
            }

            // Crew Table
            VStack(spacing: 12) {
                TableRow(label: "Director", value: "Christopher Nolan")
                TableRow(label: "Producer", value: "Emma Thomas")
            }
            .padding(12)
            .background(Color.surfaceSecondary)
            .cornerRadius(8)
        }
    }
}

// MARK: - Section Top
struct SectionTop: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primaryText)

            Spacer()

            Button(action: {}) {
                HStack(spacing: 4) {
                    Text("See All")
                        .font(.system(size: 14))
                        .foregroundColor(.secondaryText)

                    Image(systemName: "chevron.right")
                        .resizable()
                        .frame(width: 8, height: 12)
                        .foregroundColor(.secondaryText)
                }
            }
        }
    }
}

// MARK: - Card / Actor
struct CardActor: View {
    var body: some View {
        VStack(spacing: 8) {
            // Actor Image
            Circle()
                .fill(Color.surfacePrimary)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                        .foregroundColor(.midGray)
                )

            // Text Bloc
            VStack(spacing: 2) {
                Text("Actor Name")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primaryText)

                Text("Character")
                    .font(.system(size: 10))
                    .foregroundColor(.secondaryText)
            }
        }
        .frame(width: 100)
    }
}

// MARK: - Reviews Section
struct ReviewsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Top
            SectionTop(title: "Reviews")

            // Filter Badges
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(["All", "Friends", "Critics"], id: \.self) { filter in
                        BadgeView(text: filter)
                    }
                }
            }

            // Review Cards
            VStack(spacing: 12) {
                ForEach(0..<3) { _ in
                    CardReview()
                }
            }

            // Write Review Button
            Button(action: {}) {
                HStack {
                    Image(systemName: "square.and.pencil")
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundColor(.primaryText)

                    Text("Write a Review")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primaryText)

                    Spacer()
                }
                .padding(12)
                .background(Color.surfaceSecondary)
                .cornerRadius(8)
            }
        }
    }
}

// MARK: - Card / Review
struct CardReview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top Section
            HStack(alignment: .top, spacing: 12) {
                // Avatar
                Circle()
                    .fill(Color.surfacePrimary)
                    .frame(width: 40, height: 40)

                // User Info
                VStack(alignment: .leading, spacing: 4) {
                    Text("John Doe")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primaryText)

                    Text("2 days ago")
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                }

                Spacer()

                // Mango Score
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .resizable()
                        .frame(width: 12, height: 12)
                        .foregroundColor(.aiOrange)

                    Text("8.5")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primaryText)
                }
            }

            // Review Content
            Text("Amazing movie! The visual effects were stunning and the story kept me engaged throughout...")
                .font(.system(size: 14))
                .foregroundColor(.primaryText)
                .lineLimit(3)
        }
        .padding(12)
        .background(Color.surfaceSecondary)
        .cornerRadius(8)
    }
}

// MARK: - More to Watch Section
struct MoreToWatchSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Top
            SectionTop(title: "More to Watch")

            // Movie Recommendation Cards
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<3) { _ in
                        CardMovieRecommendation()
                    }
                }
            }

            // Promotional Card
            VStack(alignment: .leading, spacing: 12) {
                Text("Discover More")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primaryText)

                Text("Explore thousands of movies and shows")
                    .font(.system(size: 14))
                    .foregroundColor(.secondaryText)

                Button(action: {}) {
                    HStack {
                        Text("Browse")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primaryText)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .resizable()
                            .frame(width: 8, height: 12)
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            .padding(16)
            .background(Color.surfaceSecondary)
            .cornerRadius(8)
        }
    }
}

// MARK: - Card / Movie Recommendation
struct CardMovieRecommendation: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Movie Poster
            Rectangle()
                .fill(Color.surfacePrimary)
                .frame(width: 120, height: 180)
                .cornerRadius(8)
                .overlay(
                    Image(systemName: "film")
                        .resizable()
                        .scaledToFit()
                        .padding(30)
                        .foregroundColor(.midGray)
                )

            // Text Bloc
            VStack(alignment: .leading, spacing: 4) {
                Text("Movie Title")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryText)
                    .lineLimit(2)

                Text("2024 • Action")
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
            }

            // Rate Section
            HStack(spacing: 8) {
                // Tasty Score
                HStack(spacing: 2) {
                    Image(systemName: "leaf.fill")
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundColor(.mangoGreen)

                    Text("72%")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primaryText)
                }

                // AI Score
                HStack(spacing: 2) {
                    Image(systemName: "brain")
                        .resizable()
                        .frame(width: 10, height: 10)
                        .foregroundColor(.aiOrange)

                    Text("7.2")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primaryText)
                }
            }
        }
        .frame(width: 120)
    }
}

// MARK: - Movie Clips Section
struct MovieClipsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Top
            SectionTop(title: "Movie Clips")

            // Clip Cards
            VStack(spacing: 12) {
                ForEach(0..<2) { _ in
                    CardMovieClip()
                }
            }
        }
    }
}

// MARK: - Card / Movie Clips
struct CardMovieClip: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Clip Thumbnail
            ZStack {
                Rectangle()
                    .fill(Color.surfacePrimary)
                    .frame(height: 200)
                    .cornerRadius(8)

                // Play Icon
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "play.fill")
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundColor(.white)
                    )
            }

            // Text Bloc
            VStack(alignment: .leading, spacing: 4) {
                Text("Clip Title")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryText)

                Text("2:34")
                    .font(.system(size: 12))
                    .foregroundColor(.secondaryText)
            }
        }
    }
}

// MARK: - Photos Section
struct PhotosSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Top
            SectionTop(title: "Photos")

            // Photo Grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(0..<9) { _ in
                    Rectangle()
                        .fill(Color.surfacePrimary)
                        .aspectRatio(1, contentMode: .fit)
                        .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - Preview
struct MoviePageView_Previews: PreviewProvider {
    static var previews: some View {
        MoviePageView(movie: sampleMovies[0])
    }
}
