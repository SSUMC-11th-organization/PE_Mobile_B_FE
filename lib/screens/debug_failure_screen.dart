import 'package:flutter/material.dart';

import '../core/debug/debug_failure.dart';
import 'button_width_demo_screen.dart';

/// 저장 실패 / 저장 성공 후 GET 실패를 재현하는 디버그 화면 (kDebugMode 전용)
class DebugFailureScreen extends StatelessWidget {
  const DebugFailureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = DebugFailureSettings.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('디버그: 실패 시뮬레이션'),
        actions: [TextButton(onPressed: s.reset, child: const Text('초기화'))],
      ),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('쓰기 요청(가입·등록·수정·삭제) 실패',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            RadioGroup<WriteFailure>(
              groupValue: s.writeFailure,
              onChanged: (v) => s.update(() => s.writeFailure = v!),
              child: Column(
                children: [
                  for (final f in WriteFailure.values)
                    RadioListTile<WriteFailure>(
                      title: Text(f.label),
                      value: f,
                    ),
                ],
              ),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('내 평점 GET 실패'),
              subtitle: const Text('GET /v6/members/{id}/ratings만 네트워크 오류'),
              value: s.failRatingsGet,
              onChanged: (v) => s.update(() => s.failRatingsGet = v),
            ),
            SwitchListTile(
              title: const Text('모든 요청 1.5초 지연'),
              subtitle: const Text('로딩 표시·연타 방지·뒤로가기 차단 확인용'),
              value: s.slow,
              onChanged: (v) => s.update(() => s.slow = v),
            ),
            const Divider(),
            ListTile(
              title: const Text('MovieLogButton 너비 비교'),
              subtitle: const Text('회원가입 화면에서 분리한 스터디 인증용 화면'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ButtonWidthDemoScreen()),
              ),
            ),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '[저장 실패 + 입력 유지]\n'
                '1. 쓰기 실패를 "네트워크 오류"로 선택\n'
                '2. 평점 Dialog에서 별점·코멘트 입력 후 확인\n'
                '→ Dialog 안 오류 문구, 입력 유지, 버튼 로딩 해제\n\n'
                '[저장 성공 후 GET만 실패]\n'
                '1. 쓰기는 "끔", "내 평점 GET 실패"를 켬\n'
                '2. 마이페이지에서 수정/삭제 실행 (쓰기는 서버에 실제 반영됨)\n'
                '→ "저장은 완료됐지만…" + 조회 다시 시도 버튼\n'
                '3. GET 실패를 끄고 "조회 다시 시도" → 목록 복구(POST 재전송 없음)\n\n'
                '※ 이 화면의 가짜 응답 message는 평점 기준 고정 문구입니다 '
                '(가입 409에도 같은 문구가 나옵니다).\n'
                '※ 마이페이지 진입 GET을 막으려면 진입 전에 켜세요.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
