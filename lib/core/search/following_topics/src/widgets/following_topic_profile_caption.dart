import 'package:kurumi/material.dart';

import '../../../../config_widgets/website_logo.dart';
import '../../../../configs/config/types.dart';

String followingTopicProfileCaption(
  BooruConfig profile,
  Iterable<BooruConfig> profiles,
) {
  if (profile.name.isEmpty) return profile.url;
  if (profiles.where((candidate) => candidate.name == profile.name).length ==
      1) {
    return profile.name;
  }
  return '${profile.name} · ${profile.url}';
}

/// Displays the profile icon without duplicating the server address in the UI.
class FollowingTopicProfileOption extends StatelessWidget {
  const FollowingTopicProfileOption({required this.profile, super.key});

  final BooruConfig profile;

  @override
  Widget build(BuildContext context) {
    final name = profile.name.isEmpty ? profile.url : profile.name;
    return Tooltip(
      message: profile.name.isEmpty ? profile.url : '$name · ${profile.url}',
      child: Semantics(
        label: profile.name.isEmpty ? profile.url : '$name, ${profile.url}',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: ConfigAwareWebsiteLogo.fromConfig(
                profile.auth,
                width: 20,
                height: 20,
                customIconUrl: profile.profileIcon?.url,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
