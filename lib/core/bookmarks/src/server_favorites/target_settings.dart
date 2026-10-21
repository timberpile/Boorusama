import 'package:equatable/equatable.dart';

/// Local behavior, deliberately separate from bookmark and profile exports.
enum ServerFavoriteTargetMode { inherit, none, group }

class ServerFavoriteTarget extends Equatable {
  const ServerFavoriteTarget.inherit()
    : mode = ServerFavoriteTargetMode.inherit,
      groupId = null;

  const ServerFavoriteTarget.none()
    : mode = ServerFavoriteTargetMode.none,
      groupId = null;

  const ServerFavoriteTarget.group(String id)
    : assert(id != ''),
      mode = ServerFavoriteTargetMode.group,
      groupId = id;

  factory ServerFavoriteTarget.fromJson(Object? json) => switch (json) {
    {'mode': 'inherit'} => const ServerFavoriteTarget.inherit(),
    {'mode': 'none'} => const ServerFavoriteTarget.none(),
    {'mode': 'group', 'groupId': final String id} when id.isNotEmpty =>
      ServerFavoriteTarget.group(id),
    _ => throw const FormatException('Invalid server favorite target'),
  };

  final ServerFavoriteTargetMode mode;
  final String? groupId;

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    if (groupId != null) 'groupId': groupId,
  };

  @override
  List<Object?> get props => [mode, groupId];
}

class ServerFavoriteSettings extends Equatable {
  ServerFavoriteSettings({
    this.globalGroupId,
    Map<String, ServerFavoriteTarget> profiles = const {},
  }) : profiles = Map.unmodifiable(profiles);

  factory ServerFavoriteSettings.fromJson(Object? json) {
    if (json case {
      'version': 1,
      'globalGroupId': final Object? global,
      'profiles': final Map profiles,
    }) {
      if (global != null && (global is! String || global.isEmpty)) {
        throw const FormatException('Invalid server favorite global target');
      }
      final targets = <String, ServerFavoriteTarget>{};
      for (final entry in profiles.entries) {
        final key = entry.key;
        if (key is! String || key.isEmpty) {
          throw const FormatException('Invalid server favorite profile');
        }
        targets[key] = ServerFavoriteTarget.fromJson(entry.value);
      }
      return ServerFavoriteSettings(
        globalGroupId: global as String?,
        profiles: targets,
      );
    }
    // Never silently turn an invalid opt-out into global inheritance.
    throw const FormatException('Invalid server favorite settings');
  }

  final String? globalGroupId;
  final Map<String, ServerFavoriteTarget> profiles;

  ServerFavoriteTarget targetFor(String profileId) =>
      profiles[profileId] ?? const ServerFavoriteTarget.inherit();

  String? resolve(String profileId) => switch (targetFor(profileId).mode) {
    ServerFavoriteTargetMode.inherit => globalGroupId,
    ServerFavoriteTargetMode.none => null,
    ServerFavoriteTargetMode.group => targetFor(profileId).groupId,
  };

  Set<String> get assignedGroupIds => {
    ?globalGroupId,
    for (final target in profiles.values) ?target.groupId,
  };

  ServerFavoriteSettings withGlobal(String? groupId) =>
      ServerFavoriteSettings(globalGroupId: groupId, profiles: profiles);

  ServerFavoriteSettings withProfile(
    String profileId,
    ServerFavoriteTarget target,
  ) {
    if (profileId.isEmpty) throw ArgumentError.value(profileId, 'profileId');
    final updated = Map<String, ServerFavoriteTarget>.of(profiles);
    if (target.mode == ServerFavoriteTargetMode.inherit) {
      updated.remove(profileId);
    } else {
      updated[profileId] = target;
    }
    return ServerFavoriteSettings(
      globalGroupId: globalGroupId,
      profiles: updated,
    );
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'globalGroupId': globalGroupId,
    'profiles': {
      for (final entry in profiles.entries) entry.key: entry.value.toJson(),
    },
  };

  @override
  List<Object?> get props => [globalGroupId, profiles];
}

enum ServerFavoriteProblem {
  unsupported,
  signedOut,
  ambiguousAccount,
  noTarget,
  targetMissing,
  confirmationRequired,
  targetChanged,
  accountChanged,
  missingPostIdentity,
  paginationStalled,
  remoteFailure,
  localFailure,
  timedOut,
}

class ServerFavoriteException implements Exception {
  const ServerFavoriteException(this.problem);

  final ServerFavoriteProblem problem;

  @override
  String toString() => 'ServerFavoriteException(${problem.name})';
}

/// Call inside the same mutation transaction that persists the assignment.
void validateServerFavoriteBinding({
  required String? groupId,
  required Set<String> groupIds,
}) {
  if (groupId == null) return;
  if (!groupIds.contains(groupId)) {
    throw const ServerFavoriteException(ServerFavoriteProblem.targetMissing);
  }
}
