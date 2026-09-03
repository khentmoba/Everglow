import 'package:flutter_test/flutter_test.dart';

import 'package:everglow/features/cinema/data/services/tmdb_service.dart';

void main() {
  group('TMDBService.resolveStatusOwner', () {
    test('routes clair statuses to clairjassen', () {
      expect(
        TMDBService.resolveStatusOwner('watched-clair', 'khentsgdz'),
        'clairjassen',
      );
      expect(
        TMDBService.resolveStatusOwner('watching-clair', 'clairjassen'),
        'clairjassen',
      );
    });

    test('routes khent statuses to khentsgdz', () {
      expect(
        TMDBService.resolveStatusOwner('watched-khent', 'clairjassen'),
        'khentsgdz',
      );
      expect(
        TMDBService.resolveStatusOwner('watching-khent', 'khentsgdz'),
        'khentsgdz',
      );
    });

    test('both and generic statuses stay on the current user', () {
      expect(
        TMDBService.resolveStatusOwner('watched-both', 'khentsgdz'),
        isNull,
      );
      expect(
        TMDBService.resolveStatusOwner('watching-both', 'clairjassen'),
        isNull,
      );
      expect(
        TMDBService.resolveStatusOwner('to-watch', 'khentsgdz'),
        isNull,
      );
      expect(
        TMDBService.resolveStatusOwner('watching-self', 'breyan'),
        isNull,
      );
    });
  });
}
