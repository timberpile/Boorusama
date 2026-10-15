// Package imports:
import 'package:i18n/i18n.dart';
import 'package:kurumi/kurumi.dart';
import 'package:kurumi/material.dart';
import 'package:material_symbols_icons/symbols.dart';

// Project imports:
import '../types/metatag.dart';

class MetatagListPage extends StatelessWidget {
  const MetatagListPage({
    required this.metatags,
    required this.onSelected,
    super.key,
  });

  final List<Metatag> metatags;
  final void Function(Metatag tag) onSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: KurumiAppBar(
        title: Text('Metatags'.hc),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: Navigator.of(context).pop,
            icon: const Icon(Symbols.close),
          ),
        ],
      ),
      body: Column(
        children: [
          KurumiInfoContainer(
            title: 'Free tags'.hc,
            contentBuilder: (context) => Text(context.t.search.metatags_notice),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: metatags.length,
              itemBuilder: (context, index) {
                final tag = metatags[index];

                return ListTile(
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelected(tag);
                  },
                  title: Text(tag.name),
                  trailing: tag.isFree
                      ? KurumiMaterialChip(
                          backgroundColor: Kurumi.themeOf(
                            context,
                          ).colorScheme.primary,
                          label: Text(
                            'Free'.hc,
                            style: TextStyle(
                              color: Kurumi.themeOf(
                                context,
                              ).colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
