import Foundation
import Combine

final class MovieStore: ObservableObject {
    @Published var movies: [Movie] = []

    init() {
        loadMovies()
    }

    private func loadMovies() {
        guard let url = Bundle.main.url(forResource: "movies", withExtension: "json") else {
            print("❌ Could not find movies.json in app bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let decoded = try decoder.decode([Movie].self, from: data)
            print("✅ Loaded \(decoded.count) movies from movies.json")

            DispatchQueue.main.async {
                self.movies = decoded
            }
        } catch {
            print("❌ Failed to decode movies.json:", error)
        }
    }
}
