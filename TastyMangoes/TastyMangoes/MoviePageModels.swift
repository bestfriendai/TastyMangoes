import Foundation
import SwiftUI
import Combine


// MARK: - Data Models for Movie Page

/// Main movie data model
struct Movie: Identifiable, Codable {
    let id: String
    let title: String
    let year: Int
    let trailerURL: String?
    let trailerDuration: String
    let posterImageURL: String?
    let tastyScore: Double
    let aiScore: Double
    let genres: [String]
    let rating: String // e.g., "PG-13", "R", etc.
    let director: String
    let runtime: String
    let releaseDate: String
    let language: String
    let overview: String
}

/// Platform data model
struct Platform: Identifiable {
    let id: String
    let name: String
    let logoURL: String?
}

/// Friend data model
struct Friend: Identifiable {
    let id: String
    let name: String
    let avatarURL: String?
}

/// Cast member data model
struct CastMember: Identifiable {
    let id: String
    let name: String
    let character: String
    let imageURL: String?
}

/// Crew member data model
struct CrewMember: Identifiable {
    let id: String
    let name: String
    let role: String
}

/// Review data model
struct Review: Identifiable {
    let id: String
    let userName: String
    let userAvatarURL: String?
    let rating: Double
    let date: Date
    let content: String
    let isFriend: Bool
    let isCritic: Bool
}

/// Movie clip data model
struct MovieClip: Identifiable {
    let id: String
    let title: String
    let duration: String
    let thumbnailURL: String?
    let videoURL: String?
}

/// Photo data model
struct Photo: Identifiable {
    let id: String
    let imageURL: String
    let caption: String?
}

// MARK: - Sample Data for Previews

extension Movie {
    static let sampleMovie = Movie(
        id: "1",
        title: "Interstellar",
        year: 2024,
        trailerURL: nil,
        trailerDuration: "4:20",
        posterImageURL: nil,
        tastyScore: 64.0,
        aiScore: 5.9,
        genres: ["Action", "Sci-Fi"],
        rating: "PG-13",
        director: "Christopher Nolan",
        runtime: "2h 49min",
        releaseDate: "July 21, 2024",
        language: "English",
        overview: "A team of explorers travel through a wormhole in space in an attempt to ensure humanity's survival."
    )
}

extension Platform {
    static let samplePlatforms = [
        Platform(id: "1", name: "Netflix", logoURL: nil),
        Platform(id: "2", name: "Prime Video", logoURL: nil),
        Platform(id: "3", name: "Disney+", logoURL: nil)
    ]
}

extension Friend {
    static let sampleFriends = [
        Friend(id: "1", name: "John Doe", avatarURL: nil),
        Friend(id: "2", name: "Jane Smith", avatarURL: nil),
        Friend(id: "3", name: "Mike Johnson", avatarURL: nil)
    ]
}

extension CastMember {
    static let sampleCast = [
        CastMember(id: "1", name: "Matthew McConaughey", character: "Cooper", imageURL: nil),
        CastMember(id: "2", name: "Anne Hathaway", character: "Brand", imageURL: nil),
        CastMember(id: "3", name: "Jessica Chastain", character: "Murph", imageURL: nil),
        CastMember(id: "4", name: "Michael Caine", character: "Professor Brand", imageURL: nil),
        CastMember(id: "5", name: "Matt Damon", character: "Dr. Mann", imageURL: nil)
    ]
}

extension CrewMember {
    static let sampleCrew = [
        CrewMember(id: "1", name: "Christopher Nolan", role: "Director"),
        CrewMember(id: "2", name: "Emma Thomas", role: "Producer")
    ]
}

extension Review {
    static let sampleReviews = [
        Review(
            id: "1",
            userName: "John Doe",
            userAvatarURL: nil,
            rating: 8.5,
            date: Date().addingTimeInterval(-172800), // 2 days ago
            content: "Amazing movie! The visual effects were stunning and the story kept me engaged throughout...",
            isFriend: true,
            isCritic: false
        ),
        Review(
            id: "2",
            userName: "Jane Smith",
            userAvatarURL: nil,
            rating: 9.0,
            date: Date().addingTimeInterval(-259200), // 3 days ago
            content: "Christopher Nolan delivers another masterpiece. The scientific accuracy combined with emotional depth is remarkable.",
            isFriend: false,
            isCritic: true
        ),
        Review(
            id: "3",
            userName: "Mike Johnson",
            userAvatarURL: nil,
            rating: 7.5,
            date: Date().addingTimeInterval(-345600), // 4 days ago
            content: "Great cinematography and soundtrack. Some parts felt a bit slow but overall very enjoyable.",
            isFriend: true,
            isCritic: false
        )
    ]
}

extension MovieClip {
    static let sampleClips = [
        MovieClip(id: "1", title: "Official Trailer", duration: "2:34", thumbnailURL: nil, videoURL: nil),
        MovieClip(id: "2", title: "Behind the Scenes", duration: "3:45", thumbnailURL: nil, videoURL: nil)
    ]
}

extension Photo {
    static let samplePhotos = (0..<9).map { index in
        Photo(id: "\(index)", imageURL: "", caption: "Photo \(index + 1)")
    }
}

// MARK: - View Models

/// View model for managing movie page state
class MoviePageViewModel: ObservableObject {
    @Published var movie: Movie
    @Published var platforms: [Platform]
    @Published var friends: [Friend]
    @Published var cast: [CastMember]
    @Published var crew: [CrewMember]
    @Published var reviews: [Review]
    @Published var clips: [MovieClip]
    @Published var photos: [Photo]
    @Published var selectedTab: Int = 0
    @Published var selectedReviewFilter: ReviewFilter = .all

    enum ReviewFilter {
        case all, friends, critics
    }

    init(
        movie: Movie = .sampleMovie,
        platforms: [Platform] = Platform.samplePlatforms,
        friends: [Friend] = Friend.sampleFriends,
        cast: [CastMember] = CastMember.sampleCast,
        crew: [CrewMember] = CrewMember.sampleCrew,
        reviews: [Review] = Review.sampleReviews,
        clips: [MovieClip] = MovieClip.sampleClips,
        photos: [Photo] = Photo.samplePhotos
    ) {
        self.movie = movie
        self.platforms = platforms
        self.friends = friends
        self.cast = cast
        self.crew = crew
        self.reviews = reviews
        self.clips = clips
        self.photos = photos
    }

    var filteredReviews: [Review] {
        switch selectedReviewFilter {
        case .all:
            return reviews
        case .friends:
            return reviews.filter { $0.isFriend }
        case .critics:
            return reviews.filter { $0.isCritic }
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Helper Extensions

extension Double {
    /// Format as percentage for Tasty Score
    var asPercentage: String {
        return String(format: "%.0f%%", self)
    }

    /// Format as decimal for AI Score
    var asDecimal: String {
        return String(format: "%.1f", self)
    }
}
// MARK: - Temporary In-Memory Movie "Database"

/// A few sample movies we can use while we design the app.
/// Later, this can be replaced with a real database or API.
let sampleMovies: [Movie] = [
    Movie(
        id: "oppenheimer",
        title: "Oppenheimer",
        year: 2023,
        trailerURL: nil,
        trailerDuration: "4:20",
        posterImageURL: nil,
        tastyScore: 64.0,
        aiScore: 5.9,
        genres: ["Drama", "Sci-Fi"],
        rating: "R",
        director: "Christopher Nolan",
        runtime: "2h 49m",
        releaseDate: "July 21, 2023",
        language: "English",
        overview: "The story of J. Robert Oppenheimer and the creation of the atomic bomb."
    ),
    Movie(
        id: "dune_part_two",
        title: "Dune: Part Two",
        year: 2024,
        trailerURL: nil,
        trailerDuration: "3:15",
        posterImageURL: nil,
        tastyScore: 91.0,
        aiScore: 8.7,
        genres: ["Sci-Fi", "Adventure"],
        rating: "PG-13",
        director: "Denis Villeneuve",
        runtime: "2h 46m",
        releaseDate: "March 1, 2024",
        language: "English",
        overview: "Paul Atreides unites with the Fremen while seeking revenge against those who destroyed his family."
    ),
    Movie(
        id: "barbie",
        title: "Barbie",
        year: 2023,
        trailerURL: nil,
        trailerDuration: "2:30",
        posterImageURL: nil,
        tastyScore: 88.0,
        aiScore: 7.4,
        genres: ["Comedy", "Fantasy"],
        rating: "PG-13",
        director: "Greta Gerwig",
        runtime: "1h 54m",
        releaseDate: "July 21, 2023",
        language: "English",
        overview: "Barbie suffers a crisis that leads her to question her world and her existence."
    )
]


