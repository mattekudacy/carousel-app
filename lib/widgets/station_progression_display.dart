import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/station_progression_service.dart';
import '../services/theme_service.dart';

/// Widget displaying station progression along the route
class StationProgressionDisplay extends ConsumerWidget {
  final bool showAllStations;
  final int maxVisibleStations;

  const StationProgressionDisplay({
    super.key,
    this.showAllStations = false,
    this.maxVisibleStations = 6,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progression = ref.watch(stationProgressionProvider);

    if (progression.stationRecords.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('Initializing journey...'),
          ),
        ),
      );
    }

    // Determine which stations to show
    List<StationPassRecord> visibleRecords;
    if (showAllStations) {
      visibleRecords = progression.stationRecords;
    } else {
      visibleRecords = _getRelevantStations(progression);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, progression),
            const SizedBox(height: 16),
            _buildProgressBar(context, progression),
            const SizedBox(height: 16),
            _buildStationList(context, visibleRecords, progression),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, StationProgressionState progression) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Icon(
          progression.hasArrived ? Icons.celebration : Icons.route,
          color: progression.hasArrived ? colors.success : Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                progression.hasArrived 
                    ? 'You have arrived!' 
                    : 'Journey Progress',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: progression.hasArrived ? colors.success : null,
                ),
              ),
              Text(
                '${progression.passedCount} of ${progression.stationRecords.length} stations',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.neutralDark,
                ),
              ),
            ],
          ),
        ),
        _buildRemainingBadge(context, progression),
      ],
    );
  }

  Widget _buildRemainingBadge(BuildContext context, StationProgressionState progression) {
    final colors = AppColors.of(context);
    if (progression.hasArrived) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 16, color: colors.success),
            const SizedBox(width: 4),
            Text(
              'Arrived',
              style: TextStyle(
                color: colors.success,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final remaining = progression.remainingCount;
    Color color;
    if (remaining <= 1) {
      color = colors.error;
    } else if (remaining <= 3) {
      color = colors.warning;
    } else {
      color = colors.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$remaining left',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, StationProgressionState progression) {
    final colors = AppColors.of(context);
    final total = progression.stationRecords.length;
    final passed = progression.passedCount;
    final progress = total > 0 ? passed / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: colors.neutralMedium,
            valueColor: AlwaysStoppedAnimation<Color>(
              progression.hasArrived ? colors.success : Theme.of(context).colorScheme.primary,
            ),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(progress * 100).toStringAsFixed(0)}% complete',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.neutralDark,
              ),
            ),
            if (progression.currentStation != null)
              Text(
                'At: ${progression.currentStation!.name}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStationList(
    BuildContext context, 
    List<StationPassRecord> records,
    StationProgressionState progression,
  ) {
    return Column(
      children: [
        for (int i = 0; i < records.length; i++)
          _StationProgressionItem(
            record: records[i],
            isDestination: records[i].station.id == progression.destination?.id,
            isFirst: i == 0,
            isLast: i == records.length - 1,
          ),
      ],
    );
  }

  List<StationPassRecord> _getRelevantStations(StationProgressionState progression) {
    final records = progression.stationRecords;
    
    // Find current/next station index
    int pivotIndex = 0;
    for (int i = 0; i < records.length; i++) {
      final status = records[i].status;
      if (status == StationStatus.atStation) {
        pivotIndex = i;
        break;
      } else if (status == StationStatus.approaching || 
                 status == StationStatus.upcoming) {
        pivotIndex = i;
        break;
      } else if (status == StationStatus.passed || 
                 status == StationStatus.skipped) {
        pivotIndex = i + 1;
      }
    }

    // Show stations around pivot
    final start = (pivotIndex - 2).clamp(0, records.length);
    final end = (pivotIndex + maxVisibleStations - 2).clamp(0, records.length);

    return records.sublist(start, end);
  }
}

class _StationProgressionItem extends StatelessWidget {
  final StationPassRecord record;
  final bool isDestination;
  final bool isFirst;
  final bool isLast;

  const _StationProgressionItem({
    required this.record,
    required this.isDestination,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final status = record.status;
    final isPassed = status == StationStatus.passed || status == StationStatus.skipped;
    final isActive = status == StationStatus.atStation;
    final isApproaching = status == StationStatus.approaching;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Timeline indicator
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Top line
                Container(
                  width: 2,
                  height: 12,
                  color: isFirst 
                      ? Colors.transparent 
                      : (isPassed ? Colors.green : Colors.grey[300]),
                ),
                // Node
                _buildNode(context, status, isDestination),
                // Bottom line
                Container(
                  width: 2,
                  height: 12,
                  color: isLast 
                      ? Colors.transparent 
                      : (isPassed ? Colors.green : Colors.grey[300]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Station info
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getBackgroundColor(status, isDestination),
                borderRadius: BorderRadius.circular(8),
                border: isActive || (isDestination && status == StationStatus.atStation)
                    ? Border.all(
                        color: isDestination ? Colors.green : Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.station.name,
                          style: TextStyle(
                            fontWeight: isActive || isDestination 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                            color: _getTextColor(status, isDestination, context),
                            decoration: status == StationStatus.skipped 
                                ? TextDecoration.lineThrough 
                                : null,
                          ),
                        ),
                        if (isActive || isApproaching || isDestination)
                          Text(
                            _getStatusText(status, isDestination),
                            style: TextStyle(
                              fontSize: 11,
                              color: _getStatusColor(status, isDestination),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildStatusIcon(status, isDestination),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNode(BuildContext context, StationStatus status, bool isDestination) {
    double size;
    Color color;
    IconData? icon;

    switch (status) {
      case StationStatus.passed:
        size = 20;
        color = Colors.green;
        icon = Icons.check;
        break;
      case StationStatus.skipped:
        size = 16;
        color = Colors.grey;
        icon = Icons.remove;
        break;
      case StationStatus.atStation:
        size = 24;
        color = isDestination ? Colors.green : Theme.of(context).colorScheme.primary;
        icon = isDestination ? Icons.flag : Icons.location_on;
        break;
      case StationStatus.approaching:
        size = 20;
        color = Colors.orange;
        icon = null;
        break;
      case StationStatus.upcoming:
        size = isDestination ? 20 : 14;
        color = isDestination ? Colors.red : Colors.grey[400]!;
        icon = isDestination ? Icons.flag : null;
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: icon != null ? color : Colors.white,
        border: Border.all(color: color, width: 2),
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.6, color: Colors.white)
          : null,
    );
  }

  Color _getBackgroundColor(StationStatus status, bool isDestination) {
    if (isDestination && status == StationStatus.atStation) {
      return Colors.green.withValues(alpha: 0.1);
    }
    switch (status) {
      case StationStatus.passed:
        return Colors.green.withValues(alpha: 0.05);
      case StationStatus.skipped:
        return Colors.grey.withValues(alpha: 0.1);
      case StationStatus.atStation:
        return Colors.blue.withValues(alpha: 0.1);
      case StationStatus.approaching:
        return Colors.orange.withValues(alpha: 0.1);
      case StationStatus.upcoming:
        return isDestination 
            ? Colors.red.withValues(alpha: 0.05) 
            : Colors.grey.withValues(alpha: 0.05);
    }
  }

  Color _getTextColor(StationStatus status, bool isDestination, BuildContext context) {
    if (isDestination && status == StationStatus.atStation) {
      return Colors.green;
    }
    switch (status) {
      case StationStatus.passed:
        return Colors.green[700]!;
      case StationStatus.skipped:
        return Colors.grey;
      case StationStatus.atStation:
        return Theme.of(context).colorScheme.primary;
      case StationStatus.approaching:
        return Colors.orange[800]!;
      case StationStatus.upcoming:
        return isDestination ? Colors.red : Colors.grey[700]!;
    }
  }

  Color _getStatusColor(StationStatus status, bool isDestination) {
    if (isDestination && status == StationStatus.atStation) {
      return Colors.green;
    }
    switch (status) {
      case StationStatus.atStation:
        return Colors.blue;
      case StationStatus.approaching:
        return Colors.orange;
      case StationStatus.upcoming:
        return isDestination ? Colors.red : Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(StationStatus status, bool isDestination) {
    if (isDestination && status == StationStatus.atStation) {
      return '🎉 You have arrived!';
    }
    switch (status) {
      case StationStatus.atStation:
        return 'You are here';
      case StationStatus.approaching:
        return 'Approaching...';
      case StationStatus.upcoming:
        return isDestination ? 'Your destination' : '';
      default:
        return '';
    }
  }

  Widget _buildStatusIcon(StationStatus status, bool isDestination) {
    if (isDestination && status == StationStatus.atStation) {
      return const Icon(Icons.celebration, color: Colors.green, size: 20);
    }
    switch (status) {
      case StationStatus.passed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 16);
      case StationStatus.skipped:
        return Icon(Icons.skip_next, color: Colors.grey[400], size: 16);
      case StationStatus.atStation:
        return const Icon(Icons.my_location, color: Colors.blue, size: 16);
      case StationStatus.approaching:
        return const Icon(Icons.trending_flat, color: Colors.orange, size: 16);
      case StationStatus.upcoming:
        return isDestination 
            ? const Icon(Icons.flag, color: Colors.red, size: 16)
            : const SizedBox.shrink();
    }
  }
}

/// Compact station count badge for headers
class StationsRemainingBadge extends ConsumerWidget {
  const StationsRemainingBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(stationsRemainingProvider);
    final hasArrived = ref.watch(hasArrivedProvider);

    if (hasArrived) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 14, color: Colors.green),
            SizedBox(width: 4),
            Text(
              'Arrived',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    Color bgColor;
    Color textColor;
    if (remaining <= 1) {
      bgColor = Colors.red.withValues(alpha: 0.1);
      textColor = Colors.red;
    } else if (remaining <= 3) {
      bgColor = Colors.orange.withValues(alpha: 0.1);
      textColor = Colors.orange;
    } else {
      bgColor = Colors.grey.withValues(alpha: 0.1);
      textColor = Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$remaining stations left',
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Large prominent remaining stations display
class RemainingStationsCard extends ConsumerWidget {
  final bool showNextStation;
  
  const RemainingStationsCard({
    super.key,
    this.showNextStation = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progression = ref.watch(stationProgressionProvider);
    final remaining = progression.remainingCount;
    final hasArrived = progression.hasArrived;
    final nextStation = progression.nextStation;
    final passed = progression.passedCount;
    final total = progression.stationRecords.length;

    if (hasArrived) {
      return Card(
        color: Colors.green.shade50,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(
                Icons.celebration,
                size: 48,
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              Text(
                'You Have Arrived!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                progression.destination?.name ?? '',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Determine urgency colors
    Color primaryColor;
    Color bgColor;
    if (remaining <= 1) {
      primaryColor = Colors.red;
      bgColor = Colors.red.shade50;
    } else if (remaining <= 2) {
      primaryColor = Colors.orange;
      bgColor = Colors.orange.shade50;
    } else if (remaining <= 3) {
      primaryColor = Colors.amber.shade700;
      bgColor = Colors.amber.shade50;
    } else {
      primaryColor = Theme.of(context).colorScheme.primary;
      bgColor = Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3);
    }

    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Main count display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$remaining',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      remaining == 1 ? 'STATION' : 'STATIONS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      'REMAINING',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryColor.withValues(alpha: 0.7),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Progress indicator
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: total > 0 ? passed / total : 0,
                      backgroundColor: Colors.white.withValues(alpha: 0.5),
                      valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$passed/$total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            
            // Next station info
            if (showNextStation && nextStation != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next Stop',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            nextStation.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.grey[400],
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
            
            // Urgency warning
            if (remaining <= 2) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      remaining <= 1 ? Icons.warning : Icons.info_outline,
                      size: 16,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      remaining <= 1 ? 'Prepare to alight!' : 'Almost there!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
