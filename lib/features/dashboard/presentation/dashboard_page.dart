import 'package:flutter/material.dart';

/// Temporary entry screen. The real "What should I do today?" dashboard is
/// built in a later step; this exists only so the router has a destination.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Folo', style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}
