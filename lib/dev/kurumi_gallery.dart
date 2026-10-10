// Package imports:
import 'package:coreutils/coreutils.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';

// Project imports:
import '../core/widgets/booru_version_chip.dart';
import '../core/widgets/center_play_button.dart';
import '../core/widgets/multi_select_button.dart';

void main() => runApp(const _KurumiGallery());

class _KurumiGallery extends StatelessWidget {
  const _KurumiGallery();

  @override
  Widget build(BuildContext context) {
    final theme = Kurumi.themeFrom(
      KurumiThemeMode.dark,
      colorScheme: KurumiColorSchemes.dark,
      systemDarkMode: true,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, navigator) => KurumiTheme(
        data: KurumiThemeData.fromMaterial(theme),
        child: navigator!,
      ),
      home: const _GalleryPage(),
    );
  }
}

class _GalleryPage extends StatelessWidget {
  const _GalleryPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const KurumiAppBar(title: Text('Kurumi migration gallery')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ComponentColumn(
                  title: 'Existing',
                  useKurumi: false,
                ),
              ),
              SizedBox(width: 24),
              Expanded(
                child: _ComponentColumn(
                  title: 'Kurumi',
                  useKurumi: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComponentColumn extends StatelessWidget {
  const _ComponentColumn({
    required this.title,
    required this.useKurumi,
  });

  final String title;
  final bool useKurumi;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Kurumi.themeOf(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        if (useKurumi)
          KurumiButton(
            onPressed: () {},
            child: const Text('Primary action'),
          )
        else
          KurumiButton(
            onPressed: () {},
            child: const Text('Primary action'),
          ),
        const SizedBox(height: 16),
        if (useKurumi)
          KurumiCompactChip(
            label: 'artist',
            backgroundColor: Kurumi.themeOf(
              context,
            ).colorScheme.surfaceContainerHigh,
            onTap: () {},
          )
        else
          KurumiCompactChip(
            label: 'artist',
            backgroundColor: Kurumi.themeOf(
              context,
            ).colorScheme.surfaceContainerHigh,
            onTap: () {},
          ),
        const SizedBox(height: 16),
        if (useKurumi)
          const KurumiSettingsCard(
            title: 'Appearance',
            child: ListTile(title: Text('Theme')),
          )
        else
          const KurumiSettingsCard(
            title: 'Appearance',
            child: ListTile(title: Text('Theme')),
          ),
        const SizedBox(height: 16),
        if (useKurumi)
          const KurumiTextField(
            decoration: InputDecoration(
              labelText: 'Search',
              hintText: 'Enter tags',
            ),
          )
        else
          const KurumiTextField(
            decoration: InputDecoration(
              labelText: 'Search',
              hintText: 'Enter tags',
            ),
          ),
        const SizedBox(height: 16),
        if (useKurumi)
          KurumiSwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Automatic downloads'),
          )
        else
          KurumiSwitchListTile(
            value: true,
            onChanged: (_) {},
            title: const Text('Automatic downloads'),
          ),
        const SizedBox(height: 16),
        if (useKurumi)
          KurumiBottomSheetHeader(
            title: 'Edit favorite tags',
            closeTooltip: 'Close',
            confirmTooltip: 'Save',
            onClose: () {},
            onConfirm: () {},
          )
        else
          KurumiBottomSheetHeader(
            title: 'Edit favorite tags',
            closeTooltip: 'Close',
            confirmTooltip: 'Save',
            onClose: () {},
            onConfirm: () {},
          ),
        const SizedBox(height: 16),
        if (useKurumi)
          KurumiBottomSheetActionButtons(
            secondaryChild: const Text('Cancel'),
            primaryChild: const Text('Create'),
            onSecondaryPressed: () {},
            onPrimaryPressed: () {},
          )
        else
          KurumiBottomSheetActionButtons(
            secondaryChild: const Text('Cancel'),
            primaryChild: const Text('Create'),
            onSecondaryPressed: () {},
            onPrimaryPressed: () {},
          ),
        const SizedBox(height: 16),
        if (useKurumi)
          KurumiWarningContainer(
            title: 'Warning',
            contentBuilder: (context) => const Text(
              'This setting affects all configured sites.',
            ),
          )
        else
          KurumiWarningContainer(
            title: 'Warning',
            contentBuilder: (context) => const Text(
              'This setting affects all configured sites.',
            ),
          ),
        const SizedBox(height: 16),
        if (useKurumi)
          KurumiSlider(value: 0.6, divisions: 5, onChanged: (_) {})
        else
          KurumiSlider(value: 0.6, divisions: 5, onChanged: (_) {}),
        const SizedBox(height: 16),
        if (useKurumi)
          const KurumiAnimatedCrossFade(
            firstChild: SizedBox(
              height: 56,
              child: ColoredBox(
                color: Color(0xFF303030),
                child: Center(child: Text('First state')),
              ),
            ),
            secondChild: SizedBox(
              height: 56,
              child: ColoredBox(
                color: Color(0xFF404040),
                child: Center(child: Text('Second state')),
              ),
            ),
            crossFadeState: CrossFadeState.showFirst,
          )
        else
          const KurumiAnimatedCrossFade(
            firstChild: SizedBox(
              height: 56,
              child: ColoredBox(
                color: Color(0xFF303030),
                child: Center(child: Text('First state')),
              ),
            ),
            secondChild: SizedBox(
              height: 56,
              child: ColoredBox(
                color: Color(0xFF404040),
                child: Center(child: Text('Second state')),
              ),
            ),
            crossFadeState: CrossFadeState.showFirst,
          ),
        const SizedBox(height: 16),
        Center(
          child: useKurumi
              ? KurumiCircularIconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {},
                )
              : KurumiCircularIconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {},
                ),
        ),
        const SizedBox(height: 16),
        if (useKurumi)
          const KurumiGrayedOut(
            child: Card(
              child: ListTile(title: Text('Advanced settings')),
            ),
          )
        else
          const KurumiGrayedOut(
            child: Card(
              child: ListTile(title: Text('Advanced settings')),
            ),
          ),
        const SizedBox(height: 16),
        if (useKurumi)
          const SizedBox(
            height: 80,
            child: KurumiGenericNoDataBox(text: 'No saved searches'),
          )
        else
          const SizedBox(
            height: 80,
            child: KurumiGenericNoDataBox(text: 'No saved searches'),
          ),
        const SizedBox(height: 16),
        Center(
          child: CenterPlayButton(
            backgroundColor: Colors.black54,
            show: true,
            isPlaying: false,
            isFinished: false,
            onPressed: () {},
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 72,
          child: MultiSelectButton(
            icon: const Icon(Icons.download),
            name: 'Download',
            onPressed: () {},
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: useKurumi
              ? KurumiScrollToTopButton(onPressed: () {})
              : KurumiScrollToTopButton(onPressed: () {}),
        ),
        const SizedBox(height: 16),
        Center(
          child: useKurumi
              ? KurumiSegmentedButton<String>(
                  initialValue: 'posts',
                  segments: const {
                    'posts': 'Posts',
                    'tags': 'Tags',
                    'artists': 'Artists',
                  },
                  onChanged: (_) {},
                )
              : KurumiSegmentedButton<String>(
                  initialValue: 'posts',
                  segments: const {
                    'posts': 'Posts',
                    'tags': 'Tags',
                    'artists': 'Artists',
                  },
                  onChanged: (_) {},
                ),
        ),
        const SizedBox(height: 16),
        if (useKurumi)
          KurumiDottedBorderButton(
            title: 'Add source',
            onTap: () {},
          )
        else
          KurumiDottedBorderButton(
            title: 'Add source',
            onTap: () {},
          ),
        const SizedBox(height: 16),
        Center(
          child: BooruVersionChip(version: Version(3, 4, 1)),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => useKurumi
                ? const KurumiDialog(child: Text('Dialog content'))
                : const KurumiDialog(child: Text('Dialog content')),
          ),
          child: const Text('Open dialog'),
        ),
        TextButton(
          onPressed: () => useKurumi
              ? Kurumi.showAppModalBottomSheet<void>(
                  context: context,
                  builder: (context) => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sheet content'),
                  ),
                )
              : Kurumi.showModalBottomSheet<void>(
                  context: context,
                  builder: (context) => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Sheet content'),
                  ),
                ),
          child: const Text('Open bottom sheet'),
        ),
      ],
    );
  }
}
