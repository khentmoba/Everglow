// TEMP-PREVIEW-ONLY: reverted before the PR ships.
//
// Exercises the REAL persistence code (RouteMemory redirect, draft
// autosave, scroll restoration) with FAKE demo data so reload behavior
// is verifiable logged-out. Nothing here touches couple data.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/route_memory.dart';
import '../../shared/utils/draft_text_controller.dart';
import '../../shared/utils/scroll_memory.dart';

final tempPreviewRoutes = [
  GoRoute(path: '/temp-persist-a', builder: (_, _) => const TempPersistA()),
  GoRoute(path: '/temp-persist-b', builder: (_, _) => const TempPersistB()),
];

class TempPersistA extends StatefulWidget {
  const TempPersistA({super.key});

  @override
  State<TempPersistA> createState() => _TempPersistAState();
}

class _TempPersistAState extends State<TempPersistA> {
  final DraftTextController _draft = DraftTextController('temp:demo');
  final _scroll = RememberedScrollController('temp:list');

  @override
  void initState() {
    super.initState();
    _draft.loadDraft();
  }

  @override
  void dispose() {
    _draft.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a0f1e),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'TEMP demo (fake data only)',
                      style: TextStyle(color: Colors.white),
                    ),
                    Text(
                      'boot=${RouteMemory.bootLocation ?? 'none'}',
                      style: const TextStyle(color: Colors.amber),
                    ),
                    TextField(
                      controller: _draft,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: 'type a fake draft, then reload',
                        hintStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => context.go('/temp-persist-b'),
                      child: const Text('go to PAGE B'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  itemCount: 100,
                  itemBuilder: (_, i) => ListTile(
                    title: Text(
                      'fake row $i',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TempPersistB extends StatelessWidget {
  const TempPersistB({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a0f1e),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PAGE B (fake)',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            Text(
              'boot=${RouteMemory.bootLocation ?? 'none'}',
              style: const TextStyle(color: Colors.amber),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('back to gate'),
            ),
          ],
        ),
      ),
    );
  }
}
