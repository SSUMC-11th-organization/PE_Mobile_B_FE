import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 50),

            Text(
              "Flutter 0주차",
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, letterSpacing: 1.5),
            ),

            const SizedBox(height: 60),

            SvgPicture.asset(
              'assets/logos/movielog_logo.svg',
              width: 72,
              height: 72,
              semanticsLabel: 'MovieLog 로고',
            ),

            const SizedBox(height: 60),

            Text(
              "영화의 순간을\n기록하세요",
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              "보고 싶은 영화부터 나만의 평점까지\n한 곳에서 관리해요",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),

            const SizedBox(height: 300),

            ElevatedButton(
              onPressed: () => context.go('/register'),

              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("시작하기"),
            ),
          ],
        ),
      ),
    );
  }
}
