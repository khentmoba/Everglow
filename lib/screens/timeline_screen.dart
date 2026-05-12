import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/memory.dart';
import '../widgets/polaroid_card.dart';
import '../theme.dart';
import 'add_memory_form.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final userId = authService.user!.uid;

    return ChangeNotifierProvider(
      create: (_) => DatabaseService(userId: userId),
      child: Scaffold(
        drawer: const AppDrawer(),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 200.0,
                  floating: false,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'Everglow',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        letterSpacing: 4,
                      ),
                    ),
                    background: Container(color: AppTheme.cream),
                    centerTitle: true,
                  ),
                  actions: [
                    IconButton(
                      onPressed: () => _showAddMemoryForm(context, userId),
                      icon: const Icon(Icons.add, color: AppTheme.charcoal),
                    ),
                  ],
                ),
                const MemoryTimeline(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddMemoryForm(BuildContext context, String userId) {
    showDialog(
      context: context,
      builder: (context) => AddMemoryForm(userId: userId),
    );
  }
}

class MemoryTimeline extends StatelessWidget {
  const MemoryTimeline({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = Provider.of<DatabaseService>(context);

    return StreamBuilder<List<Memory>>(
      stream: dbService.memories,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return SliverFillRemaining(child: Center(child: Text('Error: ${snapshot.error}')));
        }

        final memories = snapshot.data ?? [];

        if (memories.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite_border, size: 64, color: AppTheme.blush),
                  const SizedBox(height: 16),
                  Text('Start your journey...', style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          );
        }

        // Grouping by year
        Map<int, List<Memory>> groupMemories = {};
        for (var memory in memories) {
          groupMemories.putIfAbsent(memory.date.year, () => []).add(memory);
        }

        List<int> sortedYears = groupMemories.keys.toList()..sort((a, b) => b.compareTo(a));

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final year = sortedYears[index];
              final yearMemories = groupMemories[year]!;

              return Column(
                children: [
                  YearHeader(year: year),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Central vertical line
                      Positioned(
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 2,
                          color: AppTheme.taupe.withOpacity(0.3),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: List.generate(yearMemories.length, (i) {
                            final bool isLeft = i % 2 == 0;
                            return Padding(
                              padding: EdgeInsets.only(
                                left: isLeft ? 20 : MediaQuery.of(context).size.width * 0.2,
                                right: isLeft ? MediaQuery.of(context).size.width * 0.2 : 20,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 450),
                                child: PolaroidCard(
                                  memory: yearMemories[i],
                                  isLeft: isLeft,
                                  onDelete: () => dbService.deleteMemory(yearMemories[i].id),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
            childCount: sortedYears.length,
          ),
        );
      },
    );
  }
}

class YearHeader extends StatelessWidget {
  final int year;
  const YearHeader({super.key, required this.year});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 40, height: 1, color: AppTheme.taupe),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              year.toString(),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    letterSpacing: 8,
                  ),
            ),
          ),
          Container(width: 40, height: 1, color: AppTheme.taupe),
        ],
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return Drawer(
      backgroundColor: AppTheme.cream,
      child: Column(
        children: [
          DrawerHeader(
            child: Center(
              child: Text('Settings', style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () => authService.logout(),
          ),
        ],
      ),
    );
  }
}
