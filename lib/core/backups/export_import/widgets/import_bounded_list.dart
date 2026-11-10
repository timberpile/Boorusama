import 'package:kurumi/material.dart';

/// Small reviews keep their natural layout. Large categories virtualize within
/// a finite viewport instead of measuring every row in the outer review list.
class ImportBoundedList extends StatelessWidget {
  const ImportBoundedList({
    required this.itemCount,
    required this.itemBuilder,
    required this.storageKey,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Object storageKey;

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 24) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < itemCount; index++)
            itemBuilder(context, index),
        ],
      );
    }
    return SizedBox(
      height: (MediaQuery.sizeOf(context).height * .55).clamp(160, 560),
      child: ListView.builder(
        key: PageStorageKey(storageKey),
        primary: false,
        padding: EdgeInsets.zero,
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
    );
  }
}
