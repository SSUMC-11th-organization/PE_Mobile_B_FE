/// 쓰기 요청(회원가입 POST, 평점 등록 POST)의 제출 상태. 여러 ViewModel이 같이 써서 파일을 분리
enum SubmitStatus { idle, submitting, success, error }
