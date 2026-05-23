import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String fallback;
  final double radius;
  final Color? backgroundColor;

  const UserAvatar({
    super.key,
    this.avatarUrl,
    required this.fallback,
    required this.radius,
    this.backgroundColor,
  });

  bool get _hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Colors.white.withValues(alpha: 0.1);

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: _hasAvatar
          ? ClipOval(
              child: Image.network(
                avatarUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _fallbackCircle(bg),
              ),
            )
          : _fallbackCircle(bg),
    );
  }

  Widget _fallbackCircle(Color bg) {
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      alignment: Alignment.center,
      child: Text(
        fallback,
        style: TextStyle(
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
