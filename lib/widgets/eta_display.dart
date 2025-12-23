import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/eta_service.dart';
import '../services/theme_service.dart';

/// Widget displaying ETA information
class ETADisplay extends ConsumerWidget {
  final bool showDetails;
  final bool compact;

  const ETADisplay({
    super.key,
    this.showDetails = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eta = ref.watch(etaResultProvider);

    if (compact) {
      return _buildCompactView(context, eta);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, eta),
            const SizedBox(height: 16),
            _buildMainETA(context, eta),
            if (showDetails && eta.nextStation != null) ...[
              const Divider(height: 24),
              _buildNextStationETA(context, eta),
            ],
            if (showDetails) ...[
              const Divider(height: 24),
              _buildSpeedInfo(context, eta),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactView(BuildContext context, ETAResult eta) {
    if (eta.destination == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            eta.isStationary ? Icons.pause_circle_outline : Icons.schedule,
            size: 18,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                eta.isStationary ? eta.distanceToDestFormatted : eta.etaToDestFormatted,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              Text(
                eta.isStationary ? 'to destination' : 'to destination',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ETAResult eta) {
    return Row(
      children: [
        Icon(
          Icons.timer_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          'Estimated Arrival',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        _buildStatusChip(context, eta),
      ],
    );
  }

  Widget _buildStatusChip(BuildContext context, ETAResult eta) {
    final colors = AppColors.of(context);
    Color bgColor;
    Color textColor;
    IconData icon;

    if (eta.status == 'Arrived!') {
      bgColor = colors.success.withValues(alpha: 0.15);
      textColor = colors.success;
      icon = Icons.check_circle;
    } else if (eta.isStationary) {
      bgColor = colors.warning.withValues(alpha: 0.15);
      textColor = colors.warning;
      icon = Icons.pause;
    } else if (eta.status == 'Good traffic flow') {
      bgColor = colors.success.withValues(alpha: 0.15);
      textColor = colors.success;
      icon = Icons.speed;
    } else if (eta.status == 'Slow traffic') {
      bgColor = colors.error.withValues(alpha: 0.15);
      textColor = colors.error;
      icon = Icons.traffic;
    } else {
      bgColor = colors.info.withValues(alpha: 0.15);
      textColor = colors.info;
      icon = Icons.directions_bus;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            eta.status,
            style: TextStyle(
              fontSize: 11,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainETA(BuildContext context, ETAResult eta) {
    final colors = AppColors.of(context);
    if (eta.destination == null) {
      return const Center(
        child: Text('No destination selected'),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.flag, color: colors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  eta.destination!.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ETAInfoBox(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: eta.distanceToDestFormatted,
                  color: colors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ETAInfoBox(
                  icon: Icons.schedule,
                  label: 'ETA',
                  value: eta.etaToDestFormatted,
                  color: colors.success,
                  isHighlighted: !eta.isStationary,
                ),
              ),
            ],
          ),
          if (eta.arrivalTimeToDest != null && !eta.isStationary) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 14, color: colors.neutralDark),
                const SizedBox(width: 4),
                Text(
                  'Arriving at ${_formatTime(eta.arrivalTimeToDest!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.neutralDark,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNextStationETA(BuildContext context, ETAResult eta) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.warning.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.location_on, color: colors.warning, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Next Stop',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.neutralDark,
                ),
              ),
              Text(
                eta.nextStation?.name ?? '--',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              eta.distanceToNextFormatted,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              eta.isStationary ? 'away' : eta.etaToNextFormatted,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: eta.isStationary ? colors.neutral : colors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpeedInfo(BuildContext context, ETAResult eta) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: _SpeedIndicator(
            label: 'Current',
            speed: eta.currentSpeedKmh,
            icon: Icons.speed,
          ),
        ),
        Container(
          width: 1,
          height: 40,
          color: colors.divider,
        ),
        Expanded(
          child: _SpeedIndicator(
            label: 'Average',
            speed: eta.averageSpeedKmh,
            icon: Icons.trending_flat,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}

class _ETAInfoBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isHighlighted;

  const _ETAInfoBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.neutralLight,
        borderRadius: BorderRadius.circular(8),
        border: isHighlighted 
            ? Border.all(color: color.withValues(alpha: 0.5), width: 2)
            : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.neutralDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpeedIndicator extends StatelessWidget {
  final String label;
  final double speed;
  final IconData icon;

  const _SpeedIndicator({
    required this.label,
    required this.speed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: colors.neutralDark),
          const SizedBox(width: 8),
          Column(
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
                '${speed.toStringAsFixed(1)} km/h',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact ETA badge for app bar or headers
class ETABadge extends ConsumerWidget {
  const ETABadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eta = ref.watch(etaResultProvider);

    if (eta.destination == null) {
      return const SizedBox.shrink();
    }

    final displayValue = eta.isStationary 
        ? eta.distanceToDestFormatted 
        : eta.etaToDestFormatted;

    Color bgColor;
    if (eta.status == 'Arrived!') {
      bgColor = Colors.green;
    } else if (eta.isStationary) {
      bgColor = Colors.orange;
    } else {
      bgColor = Theme.of(context).colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bgColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            eta.isStationary ? Icons.straighten : Icons.schedule,
            size: 14,
            color: bgColor,
          ),
          const SizedBox(width: 4),
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: bgColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Large ETA display for prominent placement
class ETAHeroDisplay extends ConsumerWidget {
  const ETAHeroDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eta = ref.watch(etaResultProvider);

    if (eta.destination == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            eta.isStationary ? 'DISTANCE' : 'ARRIVING IN',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            eta.isStationary ? eta.distanceToDestFormatted : eta.etaToDestFormatted,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'to ${eta.destination!.name}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          if (!eta.isStationary && eta.arrivalTimeToDest != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'ETA ${_formatTime(eta.arrivalTimeToDest!)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
