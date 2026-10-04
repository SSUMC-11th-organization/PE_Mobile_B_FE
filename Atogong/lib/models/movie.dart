class Movie {
  const Movie({
    required this.id,
    required this.title,
    required this.genre,
    required this.year,
    required this.runtime,
    required this.rating,
    required this.ratingCount,
    required this.posterAsset,
    required this.tags,
    required this.synopsis,
  });

  final int id;
  final String title;
  final String genre;
  final int year;
  final int runtime; // 분
  final double rating;
  final int ratingCount;
  final String posterAsset;
  final List<String> tags;
  final String synopsis;
}
