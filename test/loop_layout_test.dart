import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transformer_page_view/transformer_page_view.dart';

Widget _banner({
  required TransformerPageController pageController,
  required IndexController controller,
  Axis direction = Axis.horizontal,
  double width = 320.2,
  double height = 80.05,
  PageTransformer? transformer,
  ValueChanged<List<int>>? onPageChanged,
}) {
  return MaterialApp(
    home: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        height: height,
        child: TransformerPageView(
          itemCount: pageController.itemCount!,
          loop: pageController.loop,
          pageController: pageController,
          controller: controller,
          scrollDirection: direction,
          allowImplicitScrolling: true,
          transformer: transformer,
          onPageChanged: onPageChanged,
          itemBuilder: (_, index, realIndex) => Center(child: Text('$index')),
        ),
      ),
    ),
  );
}

void main() {
  for (final direction in Axis.values) {
    for (final transformed in [false, true]) {
      testWidgets(
          'loop lays out fractional $direction banner, transform=$transformed',
          (tester) async {
        final pages = TransformerPageController(
            itemCount: 3, loop: true, keepPage: false);
        final controller = IndexController(0);
        addTearDown(pages.dispose);
        addTearDown(controller.dispose);
        final changed = <List<int>>[];
        final transformer = transformed
            ? PageTransformerBuilder(builder: (child, info) => child)
            : null;

        await tester.pumpWidget(_banner(
          pageController: pages,
          controller: controller,
          direction: direction,
          transformer: transformer,
          onPageChanged: changed.add,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(pages.page, closeTo(0, 0.001));

        // Advancing beyond the last media and going back must retain both the
        // rendered index and the real index used by playback synchronization.
        for (var step = 1; step <= 4; step++) {
          await controller.next(animation: false);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(changed.last, [step % 3, kMiddleValue + step]);
        }
        await controller.previous(animation: false);
        await tester.pumpAndSettle();
        expect(changed.last, [0, kMiddleValue + 3]);

        final animation = controller.move(2);
        await tester.pumpAndSettle();
        await animation;
        expect(tester.takeException(), isNull);
        expect(changed.last, [2, kMiddleValue + 2]);

        await tester.pumpWidget(_banner(
          pageController: pages,
          controller: controller,
          direction: direction,
          width: 391.42857142857144,
          height: 97.85714285714286,
          transformer: transformer,
          onPageChanged: changed.add,
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  for (final count in [0, 1]) {
    testWidgets('loop handles $count media', (tester) async {
      final pages = TransformerPageController(
          itemCount: count, loop: true, keepPage: false);
      final controller = IndexController(0);
      addTearDown(pages.dispose);
      addTearDown(controller.dispose);
      await tester
          .pumpWidget(_banner(pageController: pages, controller: controller));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('0'), count == 0 ? findsNothing : findsOneWidget);
      if (count == 1) {
        await controller.next(animation: false);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(pages.page, closeTo(0, 0.001));
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('non-looping pages retain their finite scroll extent',
      (tester) async {
    final pages = TransformerPageController(itemCount: 3, keepPage: false);
    final controller = IndexController(0);
    addTearDown(pages.dispose);
    addTearDown(controller.dispose);
    await tester
        .pumpWidget(_banner(pageController: pages, controller: controller));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(pages.position.maxScrollExtent, closeTo(320.2 * 2, 0.001));
    await controller.move(2, animation: false);
    await tester.pumpAndSettle();
    expect(pages.page, closeTo(2, 0.001));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
