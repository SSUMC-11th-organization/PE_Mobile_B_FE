// values의 각 원소를 convert로 변환하되, 동시에 진행하는 요청은 최대 concurrency개로 제한
// 결과는 입력과 같은 순서. convert가 예외를 던지면 전체가 실패하므로
// 원소별 실패는 convert 안에서 결과 값(예: null)으로 바꿔서 넘길 것
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

  // worker마다 다음 index를 하나씩 가져가 처리 (Dart는 단일 스레드라 next++가 겹치지 않음)
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
