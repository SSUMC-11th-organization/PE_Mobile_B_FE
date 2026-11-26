/// 다음 page 로딩은 ready 목록을 지우지 않고 isLoadingMore로 따로 구분합니다.
enum LoadPhase { idle, loading, ready, empty, error }
