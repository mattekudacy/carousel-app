import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/station.dart';
import '../services/station_progression_service.dart';
import '../services/eta_service.dart';
import '../services/station_provider.dart';
import '../services/theme_service.dart';

/// Live status card showing current position in journey
class LiveStatusCard extends ConsumerWidget {
  const LiveStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progression = ref.watch(stationProgressionProvider);
    final eta = ref.watch(etaResultProvider);
    final destination = ref.watch(selectedDestinationProvider);

    if (progression.stationRecords.isEmpty) {
      return const _LoadingCard();
    }

    if (progression.hasArrived) {
      return _ArrivedCard(destination: destination);
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Current Segment Indicator
            _CurrentSegmentDisplay(progression: progression),
            const SizedBox(height: 20),
            
            // Live Stats Row
            _LiveStatsRow(progression: progression, eta: eta),
            const SizedBox(height: 16),
            
            // Progress indicator
            _JourneyProgressIndicator(progression: progression),
          ],
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Initializing journey...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrivedCard extends StatelessWidget {
  final Station? destination;

  const _ArrivedCard({this.destination});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Card(
      elevation: 4,
      color: colors.successLight,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: colors.success,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: colors.isDark ? Colors.black : Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '🎉 You Have Arrived!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.successDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              destination?.name ?? 'Destination',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.success,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Time to alight! Have a great day.',
              style: TextStyle(color: colors.success),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrentSegmentDisplay extends StatelessWidget {
  final StationProgressionState progression;

  const _CurrentSegmentDisplay({required this.progression});

  @override
  Widget build(BuildContext context) {
    final currentStation = progression.currentStation;
    final nextStation = progression.nextStation;

    // Find approaching station from records
    StationPassRecord? approachingRecord;
    for (final record in progression.stationRecords) {
      if (record.status == StationStatus.approaching) {
        approachingRecord = record;
        break;
      }
    }

    final colors = AppColors.of(context);
    String statusText;
    String stationName;
    IconData statusIcon;
    Color statusColor;

    if (currentStation != null) {
      // At a station
      statusText = 'At Station';
      stationName = currentStation.name;
      statusIcon = Icons.location_on;
      statusColor = colors.success;
    } else if (approachingRecord != null) {
      // Approaching a station
      statusText = 'Approaching';
      stationName = approachingRecord.station.name;
      statusIcon = Icons.near_me;
      statusColor = colors.warning;
    } else if (nextStation != null) {
      // In transit
      statusText = 'In Transit To';
      stationName = nextStation.name;
      statusIcon = Icons.directions_bus;
      statusColor = Theme.of(context).colorScheme.primary;
    } else {
      statusText = 'Tracking';
      stationName = 'Unknown';
      statusIcon = Icons.gps_fixed;
      statusColor = colors.neutral;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  stationName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Pulsing indicator for live tracking
          _PulsingDot(color: statusColor),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;

  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _animation.value * 0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LiveStatsRow extends StatelessWidget {
  final StationProgressionState progression;
  final ETAResult eta;

  const _LiveStatsRow({required this.progression, required this.eta});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Remaining Stations
        Expanded(
          child: _StatBox(
            icon: Icons.pin_drop_outlined,
            value: '${progression.remainingCount}',
            label: 'Stations Left',
            valueColor: _getUrgencyColor(context, progression.remainingCount),
            large: true,
          ),
        ),
        const SizedBox(width: 12),
        // ETA
        Expanded(
          child: _StatBox(
            icon: Icons.schedule,
            value: eta.isStationary ? '--' : eta.etaToDestFormatted,
            label: eta.isStationary ? 'Stationary' : 'ETA',
            valueColor: Theme.of(context).colorScheme.primary,
            large: true,
          ),
        ),
        const SizedBox(width: 12),
        // Distance
        Expanded(
          child: _StatBox(
            icon: Icons.straighten,
            value: eta.distanceToDestFormatted,
            label: 'Distance',
            valueColor: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ],
    );
  }

  Color _getUrgencyColor(BuildContext context, int remaining) {
    final colors = AppColors.of(context);
    if (remaining <= 1) return colors.error;
    if (remaining <= 2) return colors.warning;
    if (remaining <= 3) return colors.amber;
    return colors.success;
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color valueColor;
  final bool large;

  const _StatBox({
    required this.icon,
    required this.value,
    required this.label,
    required this.valueColor,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: colors.neutralLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: colors.neutralDark),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: large ? 22 : 18,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: colors.neutralDark,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _JourneyProgressIndicator extends StatelessWidget {
  final StationProgressionState progression;

  const _JourneyProgressIndicator({required this.progression});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final total = progression.stationRecords.length;
    final passed = progression.passedCount;
    final progress = total > 0 ? passed / total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Journey Progress',
              style: TextStyle(
                fontSize: 12,
                color: colors.neutralDark,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: colors.neutralMedium,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$passed of $total stations passed',
          style: TextStyle(
            fontSize: 11,
            color: colors.neutralDark,
          ),
        ),
      ],
    );
  }
}

/// Upcoming stations preview - shows next few stations
class UpcomingStationsCard extends ConsumerWidget {
  final int maxStations;

  const UpcomingStationsCard({super.key, this.maxStations = 4});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progression = ref.watch(stationProgressionProvider);
    final eta = ref.watch(etaResultProvider);
    final destination = ref.watch(selectedDestinationProvider);

    if (progression.stationRecords.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get upcoming stations (not passed)
    final upcoming = progression.stationRecords
        .where((r) => 
            r.status == StationStatus.upcoming || 
            r.status == StationStatus.approaching ||
            r.status == StationStatus.atStation)
        .take(maxStations)
        .toList();

    if (upcoming.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.upcoming,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Upcoming Stations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...upcoming.asMap().entries.map((entry) {
              final index = entry.key;
              final record = entry.value;
              final isDestination = record.station.id == destination?.id;
              final isNext = index == 0;

              return _UpcomingStationTile(
                record: record,
                isDestination: isDestination,
                isNext: isNext,
                etaResult: isNext ? eta : null,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _UpcomingStationTile extends StatelessWidget {
  final StationPassRecord record;
  final bool isDestination;
  final bool isNext;
  final ETAResult? etaResult;

  const _UpcomingStationTile({
    required this.record,
    required this.isDestination,
    required this.isNext,
    this.etaResult,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Color iconColor;
    IconData icon;
    
    if (record.status == StationStatus.atStation) {
      iconColor = colors.success;
      icon = Icons.location_on;
    } else if (record.status == StationStatus.approaching) {
      iconColor = colors.warning;
      icon = Icons.near_me;
    } else if (isDestination) {
      iconColor = colors.error;
      icon = Icons.flag;
    } else {
      iconColor = colors.neutral;
      icon = Icons.circle_outlined;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.station.name,
                  style: TextStyle(
                    fontWeight: isNext || isDestination ? FontWeight.bold : FontWeight.normal,
                    color: isDestination ? colors.errorDark : null,
                  ),
                ),
                if (isNext && etaResult?.etaToNextStation != null)
                  Text(
                    '${etaResult!.etaToNextFormatted} • ${etaResult!.distanceToNextFormatted}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.neutralDark,
                    ),
                  ),
              ],
            ),
          ),
          if (isDestination)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.errorLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'DEST',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colors.errorDark,
                ),
              ),
            ),
          if (isNext && !isDestination)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.infoLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'NEXT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colors.infoDark,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Speed and movement status indicator
class SpeedIndicatorCard extends ConsumerWidget {
  const SpeedIndicatorCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final eta = ref.watch(etaResultProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Speed gauge visualization
            _SpeedGauge(speedKmh: eta.currentSpeedKmh),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eta.isStationary ? 'Stationary' : 'Moving',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: eta.isStationary ? colors.neutral : colors.success,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _SpeedStat(
                        label: 'Current',
                        value: '${eta.currentSpeedKmh.toStringAsFixed(1)} km/h',
                      ),
                      const SizedBox(width: 24),
                      _SpeedStat(
                        label: 'Average',
                        value: '${eta.averageSpeedKmh.toStringAsFixed(1)} km/h',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeedGauge extends StatelessWidget {
  final double speedKmh;

  const _SpeedGauge({required this.speedKmh});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // Normalize speed (assume max 60 km/h for bus)
    final normalized = (speedKmh / 60).clamp(0.0, 1.0);
    
    Color color;
    if (speedKmh < 5) {
      color = colors.neutral;
    } else if (speedKmh < 20) {
      color = colors.warning;
    } else {
      color = colors.success;
    }

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: normalized,
            strokeWidth: 6,
            backgroundColor: colors.neutralMedium,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                speedKmh.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                'km/h',
                style: TextStyle(
                  fontSize: 8,
                  color: colors.neutralDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedStat extends StatelessWidget {
  final String label;
  final String value;

  const _SpeedStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: colors.neutralDark,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}
