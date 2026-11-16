import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LoginLink extends StatelessWidget {
  const LoginLink({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('이미 계정이 있나요?'),
        TextButton(
          onPressed: () => context.go('/login'),
          child: Text(
            '로그인',
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
