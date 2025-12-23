import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/station.dart';
import '../services/direction_inference_service.dart';
import '../services/station_provider.dart';
import '../services/theme_service.dart';

/// Widget that displays direction inference status
class DirectionInferenceDisplay extends ConsumerWidget {
  final bool showDetails;
  final VoidCallback? onDirectionOverride;

  const DirectionInferenceDisplay({
    super.key,
    this.showDetails = true,
    this.onDirectionOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inferenceResult = ref.watch(inferredDirectionProvider);
    final manualDirection = ref.watch(selectedDirectionProvider);
    final effectiveDirection = ref.watch(effectiveDirectionProvider);

    if (inferenceResult == null) {
      return _buildGatheringData(context);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, effectiveDirection, manualDirection, inferenceResult),
            if (showDetails) ...[
              const SizedBox(height: 12),
              _buildInferenceDetails(context, inferenceResult),
              const SizedBox(height: 12),
              _buildConfidenceIndicator(context, inferenceResult),
              if (inferenceResult.shouldOverride && 
                  inferenceResult.inferredDirection != manualDirection) ...[
                const SizedBox(height: 12),
                _buildOverrideNotice(context, ref, inferenceResult, manualDirection),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGatheringData(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              'Gathering GPS data...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, 
    RouteDirection? effectiveDirection,
    RouteDirection? manualDirection,
    DirectionInferenceResult inference,
  ) {
    final isInferred = inference.inferredDirection != null && 
                       inference.inferredDirection == effectiveDirection &&
                       effectiveDirection != manualDirection;

    return Row(
      children: [
        Icon(
          effectiveDirection == RouteDirection.northbound
              ? Icons.north
              : Icons.south,
          color: Theme.of(context).colorScheme.primary,
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                effectiveDirection == RouteDirection.northbound
                    ? 'NORTHBOUND'
                    : 'SOUTHBOUND',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                effectiveDirection == RouteDirection.northbound
                    ? 'PITX → Monumento'
                    : 'Monumento → PITX',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.of(context).neutralDark,
                ),
              ),
            ],
          ),
        ),
        if (isInferred)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.of(context).info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 14, color: AppColors.of(context).info),
                const SizedBox(width: 4),
                Text(
                  'Auto',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.of(context).info,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInferenceDetails(BuildContext context, DirectionInferenceResult inference) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.neutralLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.explore, size: 16, color: colors.neutral),
              const SizedBox(width: 8),
              Text(
                'Bearing: ${inference.bearing.toStringAsFixed(0)}°',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: colors.neutral),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  inference.reasoning,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.neutralDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceIndicator(BuildContext context, DirectionInferenceResult inference) {
    final appColors = AppColors.of(context);
    final confidence = inference.confidence;
    Color color;
    String label;

    if (confidence >= 0.85) {
      color = appColors.success;
      label = 'High confidence';
    } else if (confidence >= 0.7) {
      color = appColors.warning;
      label = 'Medium confidence';
    } else if (confidence >= 0.5) {
      color = appColors.amber;
      label = 'Low confidence';
    } else {
      color = appColors.neutral;
      label = 'Uncertain';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: confidence,
                  backgroundColor: appColors.neutralMedium,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${(confidence * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildOverrideNotice(
    BuildContext context,
    WidgetRef ref,
    DirectionInferenceResult inference,
    RouteDirection? manualDirection,
  ) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.info.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_vert, size: 18, color: colors.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Direction auto-detected as ${inference.inferredDirection == RouteDirection.northbound ? "Northbound" : "Southbound"}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.infoDark,
                  ),
                ),
              ),
            ],
          ),
          if (manualDirection != null && manualDirection != inference.inferredDirection) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    // Keep manual selection
                    ref.read(directionManagerProvider.notifier).setDirection(manualDirection);
                  },
                  icon: const Icon(Icons.undo, size: 16),
                  label: const Text('Keep manual'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    // Accept inferred direction
                    ref.read(directionManagerProvider.notifier).enableAutoInference();
                    onDirectionOverride?.call();
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Accept'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact direction indicator with inference status
class DirectionIndicatorBadge extends ConsumerWidget {
  const DirectionIndicatorBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final effectiveDirection = ref.watch(effectiveDirectionProvider);
    final inference = ref.watch(inferredDirectionProvider);
    final manualDirection = ref.watch(selectedDirectionProvider);

    if (effectiveDirection == null) {
      return const SizedBox.shrink();
    }

    final isAutoDetected = inference?.inferredDirection == effectiveDirection &&
                           effectiveDirection != manualDirection;
    
    final dirColor = effectiveDirection == RouteDirection.northbound
        ? colors.info
        : colors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: dirColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: dirColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            effectiveDirection == RouteDirection.northbound
                ? Icons.north
                : Icons.south,
            size: 16,
            color: dirColor,
          ),
          const SizedBox(width: 4),
          Text(
            effectiveDirection == RouteDirection.northbound ? 'NB' : 'SB',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: dirColor,
            ),
          ),
          if (isAutoDetected) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.auto_awesome,
              size: 12,
              color: dirColor,
            ),
          ],
        ],
      ),
    );
  }
}
