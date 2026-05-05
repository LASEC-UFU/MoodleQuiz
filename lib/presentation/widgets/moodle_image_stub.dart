import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class MoodleImage extends StatelessWidget {
  final String src;
  final String? alt;
  final double maxHeight;

  const MoodleImage({
    super.key,
    required this.src,
    this.alt,
    this.maxHeight = 240,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Image.network(
        src,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => MoodleImageError(src: src, alt: alt),
      ),
    );
  }
}

class MoodleImageError extends StatelessWidget {
  final String src;
  final String? alt;

  const MoodleImageError({
    super.key,
    required this.src,
    this.alt,
  });

  @override
  Widget build(BuildContext context) {
    final label =
        (alt?.trim().isNotEmpty ?? false) ? alt!.trim() : 'Imagem da questão';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label não carregada',
        style: const TextStyle(
          color: AppTheme.warning,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
