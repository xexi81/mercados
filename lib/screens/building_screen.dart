import 'package:flutter/material.dart';

class BuildingScreen extends StatelessWidget {
  final String buildingName;
  final IconData buildingIcon;
  final Color buildingColor;

  const BuildingScreen({
    super.key,
    required this.buildingName,
    required this.buildingIcon,
    required this.buildingColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(buildingName),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: buildingColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                buildingIcon,
                size: 80,
                color: buildingColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              buildingName,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Próximamente...',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
