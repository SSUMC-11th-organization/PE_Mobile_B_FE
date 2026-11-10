import 'package:flutter/material.dart';

/// 화면 위에 떠 있는 드래그 가능한 디버그 버튼. 탭하면 [onTap], 끌면 위치 이동.
/// MaterialApp.builder의 Stack 안에서 사용합니다.
class DebugFab extends StatefulWidget {
  const DebugFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  State<DebugFab> createState() => _DebugFabState();
}

class _DebugFabState extends State<DebugFab> {
  static const _size = 44.0;
  Offset? _offset; // null이면 첫 빌드에서 기본 위치(오른쪽, AppBar 아래)로 계산

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final minY = media.padding.top;
    final maxY = size.height - media.padding.bottom - _size;
    final offset = _offset ??
        Offset(size.width - _size - 8, media.padding.top + kToolbarHeight + 8);

    return Positioned(
      left: offset.dx.clamp(0.0, size.width - _size),
      top: offset.dy.clamp(minY, maxY),
      child: GestureDetector(
        onTap: widget.onTap,
        onPanUpdate: (d) => setState(() => _offset = offset + d.delta),
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: Colors.redAccent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.bug_report, color: Colors.white),
        ),
      ),
    );
  }
}
