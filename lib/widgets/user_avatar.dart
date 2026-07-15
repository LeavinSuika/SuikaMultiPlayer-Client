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

  static const _defaultAvatar = 'assets/images/default_avatar.png';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: ClipOval(
        child: _hasAvatar
            ? Image.network(
                avatarUrl!,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultImage(),
              )
            : _defaultImage(),
      ),
    );
  }

  Widget _defaultImage() {
    return Image.asset(
      _defaultAvatar,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallbackCircle(
          backgroundColor ?? Colors.white.withValues(alpha: 0.1)),
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
