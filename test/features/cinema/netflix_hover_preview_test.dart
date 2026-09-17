import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/presentation/widgets/netflix/netflix_hover_preview.dart';

void main() {
  const screen = Size(1440, 900);
  const preview = Size(340, 423);

  test('centers the preview over the anchored card', () {
    const anchor = Rect.fromLTWH(500, 400, 172, 258);
    final offset = positionHoverPreview(
      anchor: anchor,
      previewSize: preview,
      screen: screen,
    );
    expect(offset.dx, anchor.center.dx - preview.width / 2);
    expect(offset.dy, anchor.center.dy - preview.height / 2);
  });

  test('clamps inside the left and top edges', () {
    const anchor = Rect.fromLTWH(0, 80, 172, 258);
    final offset = positionHoverPreview(
      anchor: anchor,
      previewSize: preview,
      screen: screen,
    );
    expect(offset.dx, 12.0);
    expect(offset.dy, 12.0);
  });

  test('clamps inside the right and bottom edges', () {
    const anchor = Rect.fromLTWH(1300, 700, 172, 258);
    final offset = positionHoverPreview(
      anchor: anchor,
      previewSize: preview,
      screen: screen,
    );
    expect(offset.dx, screen.width - preview.width - 12);
    expect(offset.dy, screen.height - preview.height - 12);
  });

  test('pins to the top margin when the preview is taller than the screen', () {
    const tiny = Size(800, 300);
    const anchor = Rect.fromLTWH(300, 40, 172, 258);
    final offset = positionHoverPreview(
      anchor: anchor,
      previewSize: preview,
      screen: tiny,
    );
    expect(offset.dy, 12.0);
  });
}
