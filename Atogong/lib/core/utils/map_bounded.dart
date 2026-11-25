/// values를 convert로 변환하되, 동시에 최대 concurrency개만 실행. 결과는 입력과 같은 순서.
/// 즐겨찾기가 100개여도 TMDB 요청을 한 번에 100개 보내지 않으려고 사용
Future<List<R>> mapBounded<T, R>(
  Iterable<T> values,
  int concurrency,
  Future<R> Function(T value) convert,
) async {
  final input = values.toList(growable: false);
  if (input.isEmpty) return <R>[];
  if (concurrency <= 0) {
    throw ArgumentError.value(concurrency, 'concurrency', 'must be positive');
  }
  final output = List<R?>.filled(input.length, null);
  var next = 0;

  // worker 하나가 "다음 차례 꺼내기 → 변환"을 반복. worker 수가 곧 동시 요청 수
  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= input.length) return;
      output[index] = await convert(input[index]);
    }
  }

  final workers = List.generate(
    concurrency.clamp(1, input.length),
    (_) => worker(),
  );
  await Future.wait(workers);
  return output.cast<R>();
}
