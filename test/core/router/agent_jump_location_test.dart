import 'package:everglow/core/router/route_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screen-test destination keeps demo parameters through reload', () {
    final result = Uri.parse(
      agentJumpLocation(
        Uri.parse('/?agent=dashboard&screencheck=1'),
        '/dashboard',
      ),
    );
    expect(result.path, '/dashboard');
    expect(result.queryParameters['agent'], 'dashboard');
    expect(result.queryParameters['screencheck'], '1');
    expect(agentJumpLocation(result, '/dashboard'), result.toString());
  });

  test('ordinary demo jumps keep their existing clean destination', () {
    expect(
      agentJumpLocation(Uri.parse('/?agent=cinema'), '/cinema'),
      '/cinema',
    );
    expect(
      agentJumpLocation(Uri.parse('/?screencheck=0'), '/dashboard'),
      '/dashboard',
    );
  });
}
