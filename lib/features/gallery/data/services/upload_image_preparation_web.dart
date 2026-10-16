import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import '../../../../core/utils/logger.dart';

Future<({Uint8List full, Uint8List? thumb})> prepareImages(
  Uint8List bytes,
) async {
  final url = web.URL.createObjectURL(web.Blob([bytes.toJS].toJS));
  final image = web.HTMLImageElement()..src = url;
  try {
    await image.decode().toDart;
    Future<Uint8List> resize(int longestEdge) async {
      final scale = math.min(
        1.0,
        longestEdge / math.max(image.naturalWidth, image.naturalHeight),
      );
      final canvas = web.HTMLCanvasElement()
        ..width = math.max(1, (image.naturalWidth * scale).round())
        ..height = math.max(1, (image.naturalHeight * scale).round());
      try {
        final context =
            canvas.getContext('2d')! as web.CanvasRenderingContext2D;
        context.drawImage(image, 0, 0, canvas.width, canvas.height);
        final encoded = Completer<web.Blob>();
        canvas.toBlob(
          ((web.Blob? blob) {
            if (blob == null) {
              encoded.completeError(StateError('JPEG encoding failed'));
            } else {
              encoded.complete(blob);
            }
          }).toJS,
          'image/jpeg',
          0.85.toJS,
        );
        return (await (await encoded.future).arrayBuffer().toDart).toDart
            .asUint8List();
      } finally {
        canvas.width = canvas.height = 0;
      }
    }

    return (full: await resize(1600), thumb: await resize(400));
  } catch (error) {
    Logger.e(
      'Browser image preparation failed, using original bytes',
      error: error,
    );
    return (full: bytes, thumb: null);
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
