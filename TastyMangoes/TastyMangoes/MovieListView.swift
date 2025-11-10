import SwiftUI

/// Movie list screen showing multiple movies
struct MovieListView: View {
    var body: some View {
        NavigationStack {
            List(sampleMovies) { movie in
                NavigationLink(destination: MoviePageView()) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(movie.title)
                            .font(.headline)
                        Text(movie.director)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Tasty Mangoes 🍋")
        }
    }
}

#Preview {
    MovieListView()
}
