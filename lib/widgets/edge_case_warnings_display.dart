import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/edge_case_handler.dart';
import '../services/theme_service.dart';

/// Widget displaying active edge case warnings
class EdgeCaseWarningsDisplay extends ConsumerWidget {
  final bool showAll;
  final bool compact;

  const EdgeCaseWarningsDisplay({
    super.key,
    this.showAll = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warnings = ref.watch(activeWarningsProvider);

    if (warnings.isEmpty) {
      return const SizedBox.shrink();
    }

    if (compact) {
      // Show only the most severe warning as a banner
      final mostSevere = ref.watch(mostSevereWarningProvider);
      if (mostSevere == null) return const SizedBox.shrink();
      
      return _WarningBanner(warning: mostSevere);
    }

    // Show all warnings or just the top one
    final displayWarnings = showAll ? warnings : [warnings.first];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: displayWarnings.map((warning) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _WarningCard(warning: warning),
        );
      }).toList(),
    );
  }
}

class _WarningBanner extends ConsumerWidget {
  final EdgeCaseWarning warning;

  const _WarningBanner({required this.warning});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = _getWarningColors(context, warning.severity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(color: colors.border, width: 2),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              _getWarningIcon(warning.type),
              color: colors.icon,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    warning.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    warning.message,
                    style: TextStyle(
                      color: colors.text.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (warning.isDismissible)
              IconButton(
                icon: Icon(Icons.close, size: 18, color: colors.icon),
                onPressed: () {
                  ref.read(edgeCaseHandlerProvider.notifier).dismissWarning(warning.type);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}

class _WarningCard extends ConsumerWidget {
  final EdgeCaseWarning warning;

  const _WarningCard({required this.warning});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = _getWarningColors(context, warning.severity);

    return Card(
      elevation: 2,
      color: colors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.border, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.icon.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getWarningIcon(warning.type),
                color: colors.icon,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    warning.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colors.text,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    warning.message,
                    style: TextStyle(
                      color: colors.text.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (warning.isDismissible)
              IconButton(
                icon: Icon(Icons.close, color: colors.icon),
                onPressed: () {
                  ref.read(edgeCaseHandlerProvider.notifier).dismissWarning(warning.type);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen fallback for critical errors
class CriticalWarningOverlay extends ConsumerWidget {
  final Widget child;

  const CriticalWarningOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final hasCritical = ref.watch(hasCriticalWarningProvider);
    final mostSevere = ref.watch(mostSevereWarningProvider);

    return Stack(
      children: [
        child,
        if (hasCritical && mostSevere != null)
          Positioned.fill(
            child: Container(
              color: colors.overlay,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getWarningIcon(mostSevere.type),
                          color: colors.error,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          mostSevere.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          mostSevere.message,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        if (mostSevere.type == EdgeCaseType.gpsLost)
                          ElevatedButton.icon(
                            onPressed: () {
                              // Could open location settings
                            },
                            icon: const Icon(Icons.settings),
                            label: const Text('Check GPS Settings'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Status indicator chip for the app bar
class StatusIndicatorChip extends ConsumerWidget {
  const StatusIndicatorChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final gpsStatus = ref.watch(gpsStatusMessageProvider);
    final speedStatus = ref.watch(speedStatusMessageProvider);
    final hasWarnings = ref.watch(activeWarningsProvider).isNotEmpty;

    if (!hasWarnings && gpsStatus == null && speedStatus == null) {
      // All good - show green indicator
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: colors.success.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: colors.success),
            const SizedBox(width: 4),
            Text(
              'OK',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colors.success,
              ),
            ),
          ],
        ),
      );
    }

    // Show warning indicator
    final mostSevere = ref.watch(mostSevereWarningProvider);
    final color = mostSevere?.severity == WarningSeverity.critical
        ? colors.error
        : mostSevere?.severity == WarningSeverity.warning
            ? colors.warning
            : colors.amber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            speedStatus ?? gpsStatus ?? 'Warning',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ============ HELPERS ============

IconData _getWarningIcon(EdgeCaseType type) {
  switch (type) {
    case EdgeCaseType.gpsLost:
      return Icons.gps_off;
    case EdgeCaseType.gpsWeakSignal:
      return Icons.gps_not_fixed;
    case EdgeCaseType.lowSpeed:
      return Icons.traffic;
    case EdgeCaseType.stationary:
      return Icons.pause_circle_outline;
    case EdgeCaseType.wrongDirection:
      return Icons.wrong_location;
    case EdgeCaseType.offRoute:
      return Icons.alt_route;
    case EdgeCaseType.noStationsNearby:
      return Icons.location_off;
  }
}

({Color background, Color border, Color icon, Color text}) _getWarningColors(BuildContext context, WarningSeverity severity) {
  final colors = AppColors.of(context);
  switch (severity) {
    case WarningSeverity.critical:
      return (
        background: colors.errorLight,
        border: colors.errorBorder,
        icon: colors.errorDark,
        text: colors.onError,
      );
    case WarningSeverity.warning:
      return (
        background: colors.warningLight,
        border: colors.warningBorder,
        icon: colors.warningDark,
        text: colors.onWarning,
      );
    case WarningSeverity.info:
      return (
        background: colors.amberLight,
        border: colors.amberBorder,
        icon: colors.amberDark,
        text: colors.onAmber,
      );
  }
}
