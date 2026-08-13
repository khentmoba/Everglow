import 'package:everglow/features/jellyfin/data/services/jellyfin_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = JellyfinApiService();

  test('streamUrlFor includes MediaSourceId and AudioCodec copy', () {
    final url = service.streamUrlFor('movie-1');
    expect(url, contains('/Videos/movie-1/master.m3u8?'));
    expect(url, contains('api_key='));
    expect(url, contains('MediaSourceId=movie-1'));
    expect(url, contains('AudioCodec=copy'));
  });

  test('subtitleUrlFor builds the WebVTT subtitle endpoint', () {
    final url = service.subtitleUrlFor('movie-1', 0);
    expect(url, contains('/Videos/movie-1/movie-1/Subtitles/0/0/stream.vtt?'));
    expect(url, contains('api_key='));
  });
}
