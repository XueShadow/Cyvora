import 'package:material_ui/material_ui.dart';

import '../theme/cyvora_theme.dart';
import 'cyvora_logo.dart';

class CyvoraBackground extends StatelessWidget {
  const CyvoraBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: CyvoraGradients.background),
      child: child,
    );
  }
}

class CyvoraWordmark extends StatelessWidget {
  const CyvoraWordmark({super.key, this.fontSize = 28, this.centered = true});

  final double fontSize;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Text(
      'CYVORA',
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: TextStyle(
        color: CyvoraColors.text,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    );
  }
}

class CyvoraTagline extends StatelessWidget {
  const CyvoraTagline({super.key, this.fontSize = 14});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Scan. Check. Stay Safe.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: CyvoraColors.secondaryText,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class CyvoraPrimaryButton extends StatelessWidget {
  const CyvoraPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed == null ? null : CyvoraGradients.primary,
          color: onPressed == null ? CyvoraColors.deep : null,
          borderRadius: BorderRadius.circular(CyvoraRadii.button),
          boxShadow: onPressed == null
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x667C3AED),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
        ),
        child: FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: CyvoraColors.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CyvoraRadii.button),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class CyvoraCard extends StatelessWidget {
  const CyvoraCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CyvoraColors.surface,
        borderRadius: BorderRadius.circular(CyvoraRadii.card),
        border: Border.all(color: CyvoraColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class CyvoraRiskBadge extends StatelessWidget {
  const CyvoraRiskBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class CyvoraEmptyState extends StatelessWidget {
  const CyvoraEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return CyvoraCard(
      child: Column(
        children: [
          Icon(icon, color: CyvoraColors.light, size: 36),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: CyvoraColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: CyvoraColors.secondaryText),
          ),
        ],
      ),
    );
  }
}

class CyvoraBrandLockup extends StatelessWidget {
  const CyvoraBrandLockup({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CyvoraShieldLogo(size: compact ? 72 : 96),
        SizedBox(height: compact ? 8 : 12),
        CyvoraWordmark(fontSize: compact ? 28 : 34),
        const SizedBox(height: 4),
        CyvoraTagline(fontSize: compact ? 13 : 15),
      ],
    );
  }
}
