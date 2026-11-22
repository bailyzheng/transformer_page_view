import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transformer_page_view/transformer_page_view.dart';

Widget _page(BuildContext context, int index, int realIndex) =>
    Center(child: Text('Page $index'));

TransformerPageController _controller(WidgetTester tester) =>
    tester.widget<PageView>(find.byType(PageView)).controller
        as TransformerPageController;

class _RecordingController extends TransformerPageController {
  _RecordingController() : super(itemCount: 3, keepPage: false);

  int animations = 0;

  @override
  Future<void> animateToPage(int page,
      {required Duration duration, required Curve curve}) {
    animations++;
    return super.animateToPage(page, duration: duration, curve: curve);
  }
}

void main() {
  for (final transformed in [false, true]) {
    testWidgets(
        'page content stays visible on mount and remount ($transformed)',
        (tester) async {
      final transformer = transformed
          ? PageTransformerBuilder(
              builder: (child, info) => Opacity(opacity: 1, child: child))
          : null;
      Widget host(int revision) => MaterialApp(
            home: ClipRRect(
              key: ValueKey(revision),
              child: TransformerPageView(
                itemCount: 1,
                transformer: transformer,
                itemBuilder: _page,
              ),
            ),
          );

      await tester.pumpWidget(host(1));
      expect(find.text('Page 0'), findsOneWidget);
      await tester.pumpWidget(host(2));
      expect(find.text('Page 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('an empty transformed view does not call the page builder',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TransformerPageView(
        itemCount: 0,
        loop: true,
        transformer: PageTransformerBuilder(
            builder: (child, info) => const Text('Unexpected page')),
        itemBuilder: (_, __, ___) => throw StateError('Empty page builder'),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Unexpected page'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a transformer can supply the page itself', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: TransformerPageView(
        itemCount: 1,
        transformer: PageTransformerBuilder(
            builder: (child, info) => Text('Page ${info.index}')),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Page 0'), findsOneWidget);
  });

  testWidgets('uncontrolled navigation survives parent rebuilds',
      (tester) async {
    final commands = IndexController();
    addTearDown(commands.dispose);
    Widget host() => MaterialApp(
          home: TransformerPageView(
            itemCount: 3,
            controller: commands,
            itemBuilder: _page,
          ),
        );
    await tester.pumpWidget(host());
    final pages = _controller(tester);
    await commands.move(1, animation: false);
    await tester.pumpAndSettle();
    expect(pages.page, 1);

    await tester.pumpWidget(host());
    expect(_controller(tester), same(pages));
    await commands.next(animation: false);
    await tester.pumpAndSettle();
    expect(find.text('Page 2'), findsOneWidget);
    await commands.next(animation: false);
    await tester.pumpAndSettle();
    expect(find.text('Page 0'), findsOneWidget);
    await commands.previous(animation: false);
    await tester.pumpAndSettle();
    expect(find.text('Page 2'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    expect(() => pages.addListener(() {}), throwsFlutterError);
  });

  testWidgets('controller reconfiguration preserves a valid logical page',
      (tester) async {
    final commands = IndexController();
    addTearDown(commands.dispose);
    Widget host(int count, double fraction, {bool loop = false}) => MaterialApp(
          home: TransformerPageView(
            itemCount: count,
            loop: loop,
            controller: commands,
            viewportFraction: fraction,
            itemBuilder: _page,
          ),
        );
    await tester.pumpWidget(host(3, .75));
    final first = _controller(tester);
    expect(first.viewportFraction, .75);
    await commands.move(2, animation: false);
    await tester.pumpAndSettle();

    await tester.pumpWidget(host(2, .5, loop: true));
    await tester.pumpAndSettle();
    final second = _controller(tester);
    expect(second, isNot(same(first)));
    expect(second.viewportFraction, .5);
    expect(second.page, closeTo(1, .001));
    expect(() => first.addListener(() {}), throwsFlutterError);
    await commands.next(animation: false);
    await tester.pumpAndSettle();
    expect(second.page, closeTo(0, .001));

    await tester.pumpWidget(host(0, .5, loop: true));
    await tester.pumpAndSettle();
    await commands.next();
    expect(find.textContaining('Page '), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing the external controller applies index after attach',
      (tester) async {
    final first = TransformerPageController(itemCount: 3, keepPage: false);
    final second = TransformerPageController(
        initialPage: 1, itemCount: 3, keepPage: false);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    Widget host(TransformerPageController controller, int? index) =>
        MaterialApp(
          home: TransformerPageView(
            index: index,
            itemCount: 3,
            pageController: controller,
            itemBuilder: _page,
          ),
        );
    await tester.pumpWidget(host(first, 1));
    await tester.pumpAndSettle();
    expect(first.page, 1);

    await tester.pumpWidget(host(second, 2));
    await tester.pumpAndSettle();
    expect(second.page, 2);
    expect(first.hasClients, isFalse);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(host(second, 0));
    await tester.pumpAndSettle();
    expect(second.page, 0);
    await tester.pumpWidget(const SizedBox());
    void listener() {}
    first.addListener(listener);
    second.addListener(listener);
    first.removeListener(listener);
    second.removeListener(listener);
  });

  testWidgets('new commands settle older futures without completing early',
      (tester) async {
    final commands = IndexController();
    addTearDown(commands.dispose);
    await commands.next();
    await tester.pumpWidget(MaterialApp(
      home: TransformerPageView(
        itemCount: 3,
        controller: commands,
        duration: const Duration(seconds: 1),
        itemBuilder: _page,
      ),
    ));

    final first = commands.move(1);
    await tester.pump(const Duration(milliseconds: 100));
    var finished = false;
    final second = commands.move(2).then((_) => finished = true);
    await tester.pump();
    await first;
    expect(finished, isFalse);
    await tester.pumpAndSettle();
    await second;
    expect(_controller(tester).page, 2);

    final interrupted = commands.previous();
    await tester.pumpWidget(const SizedBox());
    await interrupted;
    await commands.next();
    expect(tester.takeException(), isNull);
  });

  testWidgets('echoing onPageChanged does not restart the active animation',
      (tester) async {
    final pages = _RecordingController();
    final commands = IndexController();
    final selected = ValueNotifier(0);
    addTearDown(pages.dispose);
    addTearDown(commands.dispose);
    addTearDown(selected.dispose);
    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<int>(
        valueListenable: selected,
        builder: (_, index, __) => TransformerPageView(
          itemCount: 3,
          index: index,
          pageController: pages,
          controller: commands,
          duration: const Duration(seconds: 1),
          curve: Curves.linear,
          onPageChanged: (indices) => selected.value = indices.first,
          itemBuilder: _page,
        ),
      ),
    ));
    final command = commands.next();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(selected.value, 1);
    expect(pages.realPage, closeTo(.6, .03));
    expect(pages.animations, 1);
    await tester.pumpAndSettle();
    await command;
    expect(pages.page, 1);
  });

  for (final reverse in [false, true]) {
    testWidgets('loop reports logical direction and indices ($reverse)',
        (tester) async {
      final commands = IndexController();
      final pages = TransformerPageController(
        itemCount: 3,
        loop: true,
        reverse: reverse,
        viewportFraction: reverse ? 1.25 : .8,
        keepPage: false,
      );
      addTearDown(commands.dispose);
      addTearDown(pages.dispose);
      final frames = <TransformInfo>[];
      await tester.pumpWidget(MaterialApp(
        home: TransformerPageView(
          itemCount: 3,
          pageController: pages,
          controller: commands,
          itemBuilder: _page,
          transformer: PageTransformerBuilder(
            reverse: reverse,
            builder: (child, info) {
              frames.add(info);
              return ParallaxColor(
                colors: const [Colors.red, Colors.green, Colors.blue],
                info: info,
                child: child,
              );
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final initialPage = frames.lastWhere((info) => info.index == 0);
      expect(initialPage.fromIndex, 0);
      expect(initialPage.position, 0);

      for (final forward in [false, true]) {
        final motion = forward ? commands.next() : commands.previous();
        await tester.pump();
        frames.clear();
        await tester.pump(const Duration(milliseconds: 30));
        await tester.pump(const Duration(milliseconds: 100));
        final moving = frames.where((info) => info.done == false).toList();
        expect(moving, isNotEmpty);
        expect(moving.map((info) => info.forward), everyElement(forward));
        expect(moving.map((info) => info.fromIndex),
            everyElement(forward ? 2 : 0));
        await tester.pumpAndSettle();
        await motion;
        expect(pages.page, closeTo(forward ? 0 : 2, .001));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('transform dimensions track layout and the external fraction',
      (tester) async {
    final width = ValueNotifier(300.0);
    final pages = TransformerPageController(
        itemCount: 2, viewportFraction: .8, keepPage: false);
    addTearDown(width.dispose);
    addTearDown(pages.dispose);
    TransformInfo? frame;
    final view = TransformerPageView(
      itemCount: 2,
      pageController: pages,
      itemBuilder: _page,
      transformer: PageTransformerBuilder(
        builder: (child, info) {
          frame = info;
          return child;
        },
      ),
    );
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: ValueListenableBuilder<double>(
          valueListenable: width,
          child: view,
          builder: (_, width, child) =>
              SizedBox(width: width, height: 100, child: child),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(frame?.width, 300);
    expect(frame?.height, 100);
    expect(frame?.viewportFraction, .8);
    width.value = 500;
    await tester.pumpAndSettle();
    expect(frame?.width, 500);
    expect(frame?.viewportFraction, .8);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the children factory forwards scrolling configuration',
      (tester) async {
    final commands = IndexController();
    addTearDown(commands.dispose);
    await tester.pumpWidget(MaterialApp(
      home: TransformerPageView.children(
        loop: true,
        controller: commands,
        viewportFraction: .75,
        allowImplicitScrolling: true,
        children: const [Text('Page 0'), Text('Page 1')],
      ),
    ));
    final view = tester.widget<PageView>(find.byType(PageView));
    expect(view.allowImplicitScrolling, isTrue);
    final pages = _controller(tester);
    expect(pages.loop, isTrue);
    expect(pages.viewportFraction, .75);
    await commands.previous(animation: false);
    await tester.pumpAndSettle();
    expect(pages.realPage, closeTo(kMiddleValue - 1, .001));
    expect(pages.page, closeTo(1, .001));
    await commands.move(3, animation: false);
    await tester.pumpAndSettle();
    expect(pages.realPage, closeTo(kMiddleValue + 3, .001));
    expect(pages.page, closeTo(1, .001));
  });
}
