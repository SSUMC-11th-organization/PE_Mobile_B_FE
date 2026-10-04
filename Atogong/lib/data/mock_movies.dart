import '../models/movie.dart';

const genres = ['전체', '드라마', 'SF', '애니메이션', '스릴러'];

const movies = [
  Movie(
    id: 1,
    title: '별빛 아래 우리',
    genre: '드라마',
    year: 2024,
    runtime: 124,
    rating: 4.5,
    ratingCount: 1245,
    posterAsset: 'assets/images/posters/hero_under_the_starlight.jpg',
    tags: ['로맨스', '드라마', '감동적인'],
    synopsis:
        '바쁜 현대 사회 속에서 서로의 존재를 잊고 살아가던 두 남녀가 우연한 계기로 작은 천문대에서 만나게 됩니다. '
        '매일 밤 별을 관측하며 서로의 상처를 치유하고, 잊고 있던 꿈과 사랑을 다시금 깨닫게 되는 따뜻한 이야기입니다.\n\n'
        '별이 쏟아지는 밤하늘 아래, 그들이 나눈 조용한 약속들은 과연 영원할 수 있을까요?',
  ),
  Movie(
    id: 2,
    title: '우주의 끝에서',
    genre: 'SF',
    year: 2024,
    runtime: 138,
    rating: 4.2,
    ratingCount: 980,
    posterAsset: 'assets/images/posters/poster_echoes_of_the_void.jpg',
    tags: ['SF', '우주', '모험'],
    synopsis: '인류 마지막 탐사선이 우주의 끝에서 마주한 것은 무엇이었을까. 고독과 희망을 그린 SF 대서사시.',
  ),
  Movie(
    id: 3,
    title: '기억의 숲',
    genre: '애니메이션',
    year: 2024,
    runtime: 96,
    rating: 4.9,
    ratingCount: 2310,
    posterAsset: 'assets/images/posters/poster_whispering_woods.jpg',
    tags: ['애니메이션', '판타지', '우정'],
    synopsis: '속삭이는 숲에서 길을 잃은 소녀가 숲의 정령들과 함께 잃어버린 기억을 찾아가는 이야기.',
  ),
  Movie(
    id: 4,
    title: '밤의 그림자',
    genre: '스릴러',
    year: 2024,
    runtime: 118,
    rating: 3.8,
    ratingCount: 654,
    posterAsset: 'assets/images/posters/poster_night_shadows.jpg',
    tags: ['스릴러', '누아르', '긴장감'],
    synopsis: '네온 불빛 아래 도시의 밤을 쫓는 형사. 진실에 다가갈수록 그림자는 짙어진다.',
  ),

  Movie(
    id: 5,
    title: '심연을 걷는 자',
    genre: '스릴러',
    year: 2023,
    runtime: 110,
    rating: 4.0,
    ratingCount: 512,
    posterAsset: 'assets/images/posters/poster_abyss_walker.jpg',
    tags: ['스릴러', '미스터리'],
    synopsis: '심연 끝에서 자신을 마주한 한 남자의 이야기.',
  ),
  Movie(
    id: 6,
    title: '네 번째 오후',
    genre: '드라마',
    year: 2023,
    runtime: 102,
    rating: 4.4,
    ratingCount: 830,
    posterAsset: 'assets/images/posters/poster_fourth_afternoon.jpg',
    tags: ['드라마', '일상', '잔잔한'],
    synopsis: '평범한 오후, 네 번째 만남에서 시작된 작은 변화.',
  ),
];

Movie? findMovieById(int? id) {
  for (final movie in movies) {
    if (movie.id == id) return movie;
  }
  return null;
}
