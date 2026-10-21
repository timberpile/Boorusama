import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:boorusama/core/bookmarks/src/server_favorites/target_settings.dart';

void main() {
  group('server favorite targets', () {
    test('inheritance is disabled when the global target is unset', () {
      final settings = ServerFavoriteSettings();
      expect(
        settings.targetFor('profile'),
        const ServerFavoriteTarget.inherit(),
      );
      expect(settings.resolve('profile'), isNull);
    });

    test('global, opt-out and explicit override are independent', () {
      final settings = ServerFavoriteSettings(globalGroupId: 'global')
          .withProfile('disabled', const ServerFavoriteTarget.none())
          .withProfile(
            'custom',
            const ServerFavoriteTarget.group('custom-group'),
          );
      expect(settings.resolve('inherited'), 'global');
      expect(settings.resolve('disabled'), isNull);
      expect(settings.resolve('custom'), 'custom-group');
      expect(settings.withGlobal(null).resolve('custom'), 'custom-group');
      expect(
        settings
            .withProfile('custom', const ServerFavoriteTarget.inherit())
            .resolve('custom'),
        'global',
      );
    });

    test('local preferences round-trip without account credentials', () {
      final settings = ServerFavoriteSettings(globalGroupId: 'group-id')
          .withProfile('profile-id', const ServerFavoriteTarget.none());
      final json = jsonEncode(settings.toJson());
      expect(ServerFavoriteSettings.fromJson(jsonDecode(json)), settings);
      expect(json, isNot(contains('apiKey')));
      expect(json, isNot(contains('login')));
      expect(json, isNot(contains('cursor')));
    });

    test('invalid persisted opt-out never silently becomes inheritance', () {
      expect(
        () => ServerFavoriteSettings.fromJson({
          'version': 1,
          'globalGroupId': 'global',
          'profiles': {
            'profile': {'mode': 'unknown'},
          },
        }),
        throwsFormatException,
      );
      expect(
        () => ServerFavoriteSettings.fromJson({'version': 2}),
        throwsFormatException,
      );
    });

    test('existing groups can be assigned and deleted groups are rejected', () {
      void bind(String? id) => validateServerFavoriteBinding(
        groupId: id,
        groupIds: {'empty', 'populated'},
      );
      expect(() => bind(null), returnsNormally);
      expect(() => bind('empty'), returnsNormally);
      expect(() => bind('populated'), returnsNormally);
      expect(
        () => bind('deleted'),
        throwsA(
          isA<ServerFavoriteException>().having(
            (error) => error.problem,
            'problem',
            ServerFavoriteProblem.targetMissing,
          ),
        ),
      );
    });

    test('an already assigned populated group can be shared', () {
      for (final settings in [
        ServerFavoriteSettings(globalGroupId: 'shared'),
        ServerFavoriteSettings().withProfile(
          'first',
          const ServerFavoriteTarget.group('shared'),
        ),
      ]) {
        expect(
          () => validateServerFavoriteBinding(
            groupId: 'shared',
            groupIds: {'shared'},
          ),
          returnsNormally,
        );
        expect(
          settings
              .withProfile(
                'second',
                const ServerFavoriteTarget.group('shared'),
              )
              .resolve('second'),
          'shared',
        );
      }
    });

    test('target identity does not contain a group name or folder path', () {
      final settings = ServerFavoriteSettings(globalGroupId: 'stable-uuid');
      expect(settings.resolve('profile'), 'stable-uuid');
      expect(
        settings.toJson().keys,
        unorderedEquals([
          'version',
          'globalGroupId',
          'profiles',
        ]),
      );
    });

    test('preference collections cannot be mutated after construction', () {
      final input = <String, ServerFavoriteTarget>{
        'profile': const ServerFavoriteTarget.none(),
      };
      final settings = ServerFavoriteSettings(profiles: input);
      input.clear();
      expect(settings.targetFor('profile'), const ServerFavoriteTarget.none());
      expect(() => settings.profiles.clear(), throwsUnsupportedError);
    });
  });
}
