import 'package:boorusama/core/posts/listing/src/widgets/timeline_header_sliver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final keepVisible in [false, true]) {
    testWidgets(
      'bookmark cards and timeline header cross their section boundary '
      'with keepVisible=$keepVisible',
      (tester) async {
        const scrollKey = ValueKey('bookmark-scroll');
        const cardsKey = ValueKey('bookmark-child-cards');
        const timelineHeaderKey = ValueKey('bookmark-timeline-header');
        const controlsKey = ValueKey('bookmark-search-and-controls');
        const hitKey = ValueKey('bookmark-search-field');
        final controller = ScrollController();
        addTearDown(controller.dispose);

        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: Scaffold(
                  appBar: AppBar(title: const Text('Group')),
                  body: CustomScrollView(
                    key: scrollKey,
                    controller: controller,
                    slivers: [
                      SliverGrid(
                        key: cardsKey,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: 96,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Card(
                            child: Center(child: Text('Child group $index')),
                          ),
                          childCount: 24,
                        ),
                      ),
                      TimelineHeaderSliver(
                        key: timelineHeaderKey,
                        keepVisible: keepVisible,
                        child: Container(
                          key: controlsKey,
                          padding: const EdgeInsets.all(8),
                          child: const Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: TextField(
                                  key: hitKey,
                                  decoration: InputDecoration(
                                    hintText: 'Search bookmarks',
                                  ),
                                ),
                              ),
                              Chip(label: Text('Selected tag')),
                              Chip(label: Text('Newest')),
                              Chip(label: Text('Grid')),
                            ],
                          ),
                        ),
                      ),
                      SliverList.builder(
                        itemCount: 100,
                        itemBuilder: (_, index) => SizedBox(
                          height: 100,
                          child: Center(child: Text('Bookmark $index')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final cardsSliver = tester.renderObject<RenderSliver>(
          find.byKey(cardsKey),
        );
        final sectionBoundary = cardsSliver.geometry!.scrollExtent;
        expect(sectionBoundary, greaterThan(800));
        expect(
          find.byKey(controlsKey, skipOffstage: false).evaluate().length,
          lessThanOrEqualTo(1),
        );

        // The group cards fill most of the initial viewport before the
        // timeline controls, which remain a single downstream section.
        expect(controller.offset, 0);
        expect(find.byKey(hitKey).hitTestable(), findsNothing);

        await tester.drag(find.byKey(scrollKey), const Offset(0, -2600));
        await tester.pumpAndSettle();
        expect(controller.offset, greaterThan(sectionBoundary));
        final headerSliver = tester.renderObject<RenderSliver>(
          find.byKey(timelineHeaderKey, skipOffstage: false),
        );
        expect(headerSliver.geometry!.scrollExtent, greaterThan(0));
        expect(find.byKey(controlsKey, skipOffstage: false), findsOneWidget);
        expect(
          find.byKey(hitKey).hitTestable(),
          keepVisible ? findsOneWidget : findsNothing,
        );

        // A short upward reversal reveals floating controls deep in the
        // timeline. Pinned controls remain visible throughout.
        await tester.drag(find.byKey(scrollKey), const Offset(0, 32));
        await tester.pumpAndSettle();
        expect(find.byKey(hitKey).hitTestable(), findsOneWidget);
        expect(controller.offset, greaterThan(sectionBoundary));

        // Continue upward to just before the measured end of the card sliver.
        // At this point controls must occupy their natural position after the
        // cards, rather than staying attached to the navigation header.
        final beforeBoundary = sectionBoundary - 80;
        final toBoundary = controller.animateTo(
          beforeBoundary,
          duration: const Duration(milliseconds: 900),
          curve: Curves.linear,
        );
        await tester.pumpAndSettle();
        await toBoundary;
        final scrollTop = tester.getTopLeft(find.byKey(scrollKey)).dy;
        final controlsTop = tester.getTopLeft(find.byKey(controlsKey)).dy;
        expect(
          controlsTop,
          closeTo(scrollTop + sectionBoundary - controller.offset, 2),
        );
        expect(find.byKey(hitKey).hitTestable(), findsOneWidget);

        final toTop = controller.animateTo(
          0,
          duration: const Duration(milliseconds: 700),
          curve: Curves.linear,
        );
        await tester.pumpAndSettle();
        await toTop;
        expect(controller.offset, 0);
        expect(
          find.byKey(controlsKey, skipOffstage: false).evaluate().length,
          lessThanOrEqualTo(1),
        );
        expect(find.byKey(hitKey).hitTestable(), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
