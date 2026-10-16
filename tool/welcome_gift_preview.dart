// Synthetic-only harness: flutter run -d chrome -t tool/welcome_gift_preview.dart
import 'package:flutter/material.dart';

import 'package:everglow/core/theme/app_theme.dart';
import 'package:everglow/features/entry/data/welcome_gift_service.dart';
import 'package:everglow/features/entry/presentation/widgets/welcome_gift_gate.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.gamifiedTheme,
    home: const _Preview(),
  ),
);

class _DemoService extends WelcomeGiftService {
  bool completed = false;
  @override
  Future<String?> pendingHtml(String uid) async => completed ? null : _html;
  @override
  Future<void> complete(String uid) async => completed = true;
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final service = _DemoService();
  int visit = 0;
  @override
  Widget build(BuildContext context) => WelcomeGiftGate(
    key: ValueKey(visit),
    recipientUid: 'demo-recipient',
    service: service,
    child: Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Everglow — synthetic preview home'),
            TextButton(
              onPressed: () => setState(() => visit++),
              child: const Text('Simulate next visit'),
            ),
            TextButton(
              onPressed: () => setState(() {
                service.completed = false;
                visit++;
              }),
              child: const Text('Reset demo'),
            ),
          ],
        ),
      ),
    ),
  );
}

const _html =
    '''<!doctype html><html lang="en"><meta name="viewport" content="width=device-width,initial-scale=1"><title>A little letter</title>
<style>*{box-sizing:border-box}body{margin:0;background:#faf5ed;color:#633b43;font-family:Georgia,serif;text-align:center;padding:42px 24px}h1{font-weight:400;font-size:clamp(36px,6vw,52px);line-height:1.18;margin:40px auto 24px;max-width:520px}p{font-size:18px;line-height:1.8;max-width:420px;margin:24px auto}button{border:0;background:transparent;cursor:pointer;padding:16px;color:inherit;font:inherit}button:focus-visible{outline:3px solid #934c60;outline-offset:6px}svg{width:250px;max-width:100%;margin:24px auto}small{font:12px/1.7 sans-serif}section[hidden]{display:none}</style>
<small>Fictional content for preview only</small><section id="opening"><h1>Some things deserve<br>a little love letter.</h1><p>A few happy moments, saved for you.</p>
<button id="open" aria-label="Open the sample letter"><svg viewBox="0 0 280 198" aria-hidden="true"><rect y="18" width="280" height="180" rx="5" fill="#edc8c4"/><path d="M0 198 140 96 280 198" fill="#f1d2cb"/><path d="M0 18 127 116q13 11 26 0L280 18" fill="#e6b5b7"/><circle cx="140" cy="101" r="22" fill="#9b5364"/><path d="M140 110s-12-7-12-14c0-7 10-8 12-2 2-6 12-5 12 2 0 7-12 14-12 14Z" fill="#f9d9d3"/></svg></button><p><small>Tap the envelope. Take your time.</small></p></section>
<section id="letter" hidden><h1>A little note for you.</h1><p>Thank you for an afternoon full of laughter by the lake. Here's to more little adventures together.</p><p><small>This is a synthetic note. No real journal data is included.</small></p><button id="finish">One more thing</button></section>
<section id="closing" hidden><h1>Here's to our next adventure.</h1><button id="restart">Start again</button></section>
<script>document.getElementById('open').onclick=()=>{document.getElementById('opening').hidden=true;document.getElementById('letter').hidden=false;};document.getElementById('finish').onclick=()=>{document.getElementById('letter').hidden=true;document.getElementById('closing').hidden=false;parent.postMessage('everglow:content-finished','*');};document.getElementById('restart').onclick=()=>{document.getElementById('closing').hidden=true;document.getElementById('opening').hidden=false;parent.postMessage('everglow:content-reading','*');};</script></html>''';
