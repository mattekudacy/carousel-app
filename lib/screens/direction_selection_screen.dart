import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/station.dart';
import '../services/station_provider.dart';
import '../widgets/theme_toggle.dart';
import 'destination_selection_screen.dart';

class DirectionSelectionScreen extends ConsumerWidget {
  const DirectionSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDirection = ref.watch(selectedDirectionProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('EDSA Carousel'),
        centerTitle: true,
        actions: const [
          ThemeToggleButton(),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Header
              Icon(
                Icons.directions_bus,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Select Your Direction',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose which way you\'re traveling',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // Northbound Button
              _DirectionButton(
                direction: RouteDirection.northbound,
                icon: Icons.north,
                isSelected: selectedDirection == RouteDirection.northbound,
                onTap: () {
                  ref.read(selectedDirectionProvider.notifier).state =
                      RouteDirection.northbound;
                },
              ),
              const SizedBox(height: 16),
              
              // Southbound Button
              _DirectionButton(
                direction: RouteDirection.southbound,
                icon: Icons.south,
                isSelected: selectedDirection == RouteDirection.southbound,
                onTap: () {
                  ref.read(selectedDirectionProvider.notifier).state =
                      RouteDirection.southbound;
                },
              ),
              
              const Spacer(),
              
              // Continue Button
              FilledButton(
                onPressed: selectedDirection != null
                    ? () {
                        // Clear any previous destination selection
                        ref.read(selectedDestinationProvider.notifier).state = null;
                        // Navigate to destination selection
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const DestinationSelectionScreen(),
                          ),
                        );
                      }
                    : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionButton extends StatelessWidget {
  final RouteDirection direction;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DirectionButton({
    required this.direction,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      direction.displayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      direction.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
