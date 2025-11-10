import SwiftUI

struct MovieListView: View {
    // Our data source
    @StateObject private var store = MovieStore()

    var body: some View {
        NavigationStack {
            List(store.movies) { movie in
                NavigationLink(destination: MoviePageView(movie: movie)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(movie.title)
                            .font(.headline)

                        Text(movie.director)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Tasty Mangoes 🍿")
        }
    }
}

#Preview {
    MovieListView()
}
