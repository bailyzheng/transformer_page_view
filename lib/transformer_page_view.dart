library transformer_page_view;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:transformer_page_view/index_controller.dart';
export 'package:transformer_page_view/index_controller.dart';
export 'package:transformer_page_view/parallax.dart';

///
/// NOTICE::
///
/// In order to make package smaller,currently we're not supporting any build-in page transformers
/// You can find build in transforms here:
///
///
///

const int kMaxValue = 2000000000000;
const int kMiddleValue = 1000000000000;

///  Default auto play transition duration (in millisecond)
const int kDefaultTransactionDuration = 300;

typedef TransformerPageViewWidgetBuilder = Widget Function(
    BuildContext context, int index, int realIndex);

class TransformInfo {
  /// The `width` of the `TransformerPageView`
  final double? width;

  /// The `height` of the `TransformerPageView`
  final double? height;

  /// The `position` of the widget pass to [PageTransformer.transform]
  ///  A `position` describes how visible the widget is.
  ///  The widget in the center of the screen' which is  full visible, position is 0.0.
  ///  The widge in the left ,may be hidden, of the screen's position is less than 0.0, -1.0 when out of the screen.
  ///  The widge in the right ,may be hidden, of the screen's position is greater than 0.0,  1.0 when out of the screen
  ///
  ///
  final double? position;

  /// The `index` of the widget pass to [PageTransformer.transform]
  final int? index;

  /// The `activeIndex` of the PageView
  final int? activeIndex;

  /// The logical index at the start of the current scroll.
  final int? fromIndex;

  /// Whether the scroll is moving toward the next logical page.
  final bool? forward;

  /// User drag is done.
  final bool? done;

  /// The effective viewport fraction of the page controller.
  final double? viewportFraction;

  /// Copy from [TransformerPageView.scrollDirection]
  final Axis? scrollDirection;

  TransformInfo(
      {this.index,
      this.position,
      this.width,
      this.height,
      this.activeIndex,
      this.fromIndex,
      this.forward,
      this.done,
      this.viewportFraction,
      this.scrollDirection});
}

abstract class PageTransformer {
  ///
  final bool reverse;

  PageTransformer({this.reverse = false});

  /// Return a transformed widget, based on child and TransformInfo
  Widget transform(Widget child, TransformInfo info);
}

typedef PageTransformerBuilderCallback = Widget Function(
    Widget child, TransformInfo info);

class PageTransformerBuilder extends PageTransformer {
  final PageTransformerBuilderCallback builder;

  PageTransformerBuilder({super.reverse, required this.builder});

  @override
  Widget transform(Widget child, TransformInfo info) {
    return builder(child, info);
  }
}

class TransformerPageController extends PageController {
  final bool loop;
  final int? itemCount;
  final bool reverse;

  TransformerPageController({
    int? initialPage = 0,
    super.keepPage,
    super.viewportFraction,
    this.loop = false,
    this.itemCount,
    this.reverse = false,
  })  : assert(itemCount == null || itemCount >= 0),
        assert((!loop && !reverse) || itemCount != null),
        super(
          initialPage: _realIndex(initialPage ?? 0, loop, itemCount, reverse),
        );

  int getRenderIndexFromRealIndex(num index) {
    return _logicalPage(index).toInt();
  }

  int? getRealItemCount() {
    if (itemCount == 0) return 0;
    // PageView supports an unbounded builder when itemCount is null. A huge
    // finite count loses precision in scroll-extent estimation at fractional
    // viewport sizes and can fail Flutter's fixed-extent layout assertion.
    return loop ? null : itemCount;
  }

  num _logicalPage(num index) {
    if (itemCount == 0) return 0;
    final offset = loop ? index - kMiddleValue : index;
    final logical = reverse ? itemCount! - 1 - offset : offset;
    return loop ? logical % itemCount! : logical;
  }

  double? get realPage => super.page;

  @override
  double? get page {
    final real = realPage;
    return loop && real != null ? _logicalPage(real).toDouble() : real;
  }

  int getRealIndexFromRenderIndex(num index) =>
      _realIndex(index.toInt(), loop, itemCount, reverse);

  static int _realIndex(int index, bool loop, int? itemCount, bool reverse) {
    if (itemCount == 0) return 0;
    final offset = reverse ? itemCount! - index - 1 : index;
    return loop ? kMiddleValue + offset : offset;
  }
}

class TransformerPageView extends StatefulWidget {
  /// Create a `transformed` widget base on the widget that has been passed to  the [PageTransformer.transform].
  /// See [TransformInfo]
  ///
  final PageTransformer? transformer;

  /// Same as [PageView.scrollDirection]
  ///
  /// Defaults to [Axis.horizontal].
  final Axis scrollDirection;

  /// Same as [PageView.physics]
  final ScrollPhysics? physics;

  /// Set to false to disable page snapping, useful for custom scroll behavior.
  /// Same as [PageView.pageSnapping]
  final bool pageSnapping;

  /// Called whenever the page in the center of the viewport changes.
  /// Same as [PageView.onPageChanged]
  final ValueChanged<List<int>>? onPageChanged;

  final TransformerPageViewWidgetBuilder? itemBuilder;

  // See [IndexController.mode],[IndexController.next],[IndexController.previous]
  final IndexController? controller;

  /// Animation duration
  final Duration duration;

  /// Animation curve
  final Curve curve;

  final TransformerPageController? pageController;

  /// Set true to open infinity loop mode.
  final bool loop;

  /// This value is only valid when `pageController` is not set,
  final int itemCount;

  /// This value is only valid when `pageController` is not set,
  final double viewportFraction;

  final bool allowImplicitScrolling;

  /// If not set, it is controlled by this widget.
  final int? index;

  /// Creates a scrollable list that works page by page using widgets that are
  /// created on demand.
  ///
  /// This constructor is appropriate for page views with a large (or infinite)
  /// number of children because the builder is called only for those children
  /// that are actually visible.
  ///
  /// Providing a non-null [itemCount] lets the [PageView] compute the maximum
  /// scroll extent.
  ///
  /// [itemBuilder] will be called only with indices greater than or equal to
  /// zero and less than [itemCount].
  TransformerPageView({
    super.key,
    this.index,
    Duration? duration,
    this.curve = Curves.ease,
    this.viewportFraction = 1.0,
    this.allowImplicitScrolling = false,
    this.loop = false,
    this.scrollDirection = Axis.horizontal,
    this.physics,
    this.pageSnapping = true,
    this.onPageChanged,
    this.controller,
    this.transformer,
    this.itemBuilder,
    this.pageController,
    required this.itemCount,
  })  : assert(itemCount >= 0),
        assert(itemCount == 0 || itemBuilder != null || transformer != null),
        duration =
            duration ?? Duration(milliseconds: kDefaultTransactionDuration);

  factory TransformerPageView.children(
      {Key? key,
      int? index,
      Duration? duration,
      Curve curve = Curves.ease,
      double viewportFraction = 1.0,
      bool loop = false,
      bool allowImplicitScrolling = false,
      Axis scrollDirection = Axis.horizontal,
      ScrollPhysics? physics,
      bool pageSnapping = true,
      ValueChanged<List<int>>? onPageChanged,
      IndexController? controller,
      PageTransformer? transformer,
      required List<Widget> children,
      TransformerPageController? pageController}) {
    return TransformerPageView(
      itemCount: children.length,
      itemBuilder: (context, index, realIndex) => children[index],
      pageController: pageController,
      transformer: transformer,
      pageSnapping: pageSnapping,
      key: key,
      index: index,
      duration: duration,
      curve: curve,
      viewportFraction: viewportFraction,
      loop: loop,
      allowImplicitScrolling: allowImplicitScrolling,
      scrollDirection: scrollDirection,
      physics: physics,
      onPageChanged: onPageChanged,
      controller: controller,
    );
  }

  @override
  State<StatefulWidget> createState() {
    return _TransformerPageViewState();
  }

  static int? getRealIndexFromRenderIndex(
      {required bool reverse, int? index, int? itemCount, required bool loop}) {
    return TransformerPageController._realIndex(
        index ?? 0, loop, itemCount, reverse);
  }

  static PageController createPageController(
      {required bool reverse,
      int? index,
      int? itemCount,
      required bool loop,
      required double viewportFraction}) {
    return PageController(
        initialPage: getRealIndexFromRenderIndex(
            reverse: reverse, index: index, itemCount: itemCount, loop: loop)!,
        viewportFraction: viewportFraction);
  }
}

class _TransformerPageViewState extends State<TransformerPageView> {
  late TransformerPageController _pages;
  double? _scrollStartPage;

  @override
  void initState() {
    super.initState();
    _pages = widget.pageController ?? _createController(widget.index ?? 0);
    widget.controller?.addListener(_onIndexCommand);
    if (widget.pageController != null && widget.index != null) {
      _applyIndexAfterLayout(widget.index!, animate: false);
    }
  }

  TransformerPageController _createController(int index) =>
      TransformerPageController(
        initialPage: _normalizeIndex(index, widget.itemCount),
        itemCount: widget.itemCount,
        loop: widget.loop,
        reverse: widget.transformer?.reverse ?? false,
        viewportFraction: widget.viewportFraction,
      );

  int _normalizeIndex(int index, int? count) {
    if (count == null) return index < 0 ? 0 : index;
    return count == 0 ? 0 : index.clamp(0, count - 1).toInt();
  }

  double? _readPage(TransformerPageController controller) {
    if (controller.positions.length != 1 ||
        !controller.position.hasContentDimensions) {
      return null;
    }
    return controller.realPage;
  }

  @override
  void didUpdateWidget(TransformerPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onIndexCommand);
      oldWidget.controller?.complete();
      widget.controller?.addListener(_onIndexCommand);
    }

    final externalChanged = oldWidget.pageController != widget.pageController;
    final internalConfigChanged = widget.pageController == null &&
        (oldWidget.itemCount != widget.itemCount ||
            oldWidget.loop != widget.loop ||
            oldWidget.viewportFraction != widget.viewportFraction ||
            (oldWidget.transformer?.reverse ?? false) !=
                (widget.transformer?.reverse ?? false));
    final replaceController = externalChanged || internalConfigChanged;
    if (replaceController) {
      final previous = _pages;
      final previousPage = _readPage(previous)?.round() ?? previous.initialPage;
      final index =
          widget.index ?? previous.getRenderIndexFromRealIndex(previousPage);
      _pages = widget.pageController ?? _createController(index);
      _scrollStartPage = null;
      widget.controller?.complete();
      if (oldWidget.pageController == null) {
        // The previous PageView detaches its controller later in this frame.
        WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      }
      if (widget.pageController == null || widget.index != null) {
        _applyIndexAfterLayout(index, animate: false);
      }
    } else if (widget.index != null && widget.index != oldWidget.index) {
      _applyIndexAfterLayout(widget.index!, animate: true);
    }
  }

  void _applyIndexAfterLayout(int index, {required bool animate}) {
    final controller = _pages;
    final requestedIndex = widget.index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !identical(_pages, controller) ||
          widget.index != requestedIndex ||
          controller.positions.length != 1 ||
          controller.itemCount == 0) {
        return;
      }
      final target = _normalizeIndex(index, controller.itemCount);
      final page = _readPage(controller);
      if (page != null &&
          controller.getRenderIndexFromRealIndex(page.round()) == target) {
        return;
      }
      unawaited(_goToPage(controller.getRealIndexFromRenderIndex(target),
          animate: animate));
    });
  }

  Future<void> _goToPage(int realIndex, {required bool animate}) async {
    if (animate && widget.duration > Duration.zero) {
      await _pages.animateToPage(
        realIndex,
        duration: widget.duration,
        curve: widget.curve,
      );
    } else {
      _pages.jumpToPage(realIndex);
    }
  }

  int _adjacentPage(bool next) {
    final current = _readPage(_pages)?.round() ?? _pages.initialPage;
    final step = _pages.reverse == next ? -1 : 1;
    final target = current + step;
    final count = _pages.itemCount;
    if (!_pages.loop && count != null && count > 0) {
      return target % count;
    }
    return target < 0 ? 0 : target;
  }

  void _onIndexCommand() {
    final controller = widget.controller!;
    final complete = controller.completionForCurrentCommand();
    if (_pages.positions.length != 1 || _pages.itemCount == 0) {
      complete();
      return;
    }

    final index = switch (controller.event) {
      IndexController.MOVE => _pages.getRealIndexFromRenderIndex(_pages.loop
          ? controller.index
          : _normalizeIndex(controller.index, _pages.itemCount)),
      IndexController.NEXT => _adjacentPage(true),
      IndexController.PREVIOUS => _adjacentPage(false),
      _ => null,
    };
    if (index == null) {
      complete();
      return;
    }
    unawaited(
        _goToPage(index, animate: controller.animation).whenComplete(complete));
  }

  bool _trackScroll(ScrollNotification notification) {
    if (notification.depth == 0 && notification.metrics is PageMetrics) {
      if (notification is ScrollStartNotification) {
        _scrollStartPage = _readPage(_pages);
      } else if (notification is ScrollEndNotification) {
        _scrollStartPage = null;
      }
    }
    return false;
  }

  Widget _buildPage(BuildContext context, int realIndex, Size viewport) {
    final index = _pages.getRenderIndexFromRealIndex(realIndex);
    final child =
        widget.itemBuilder?.call(context, index, realIndex) ?? const SizedBox();
    final transformer = widget.transformer;
    if (transformer == null) return child;

    final controller = _pages;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        if (viewport.isEmpty) return child!;
        // PageView may build a child before its scroll position has dimensions.
        final page = _readPage(controller) ?? realIndex.toDouble();
        final fromPage = _scrollStartPage ?? page;
        final direction = controller.reverse ? -1 : 1;
        final fraction = controller.viewportFraction;
        return transformer.transform(
          child!,
          TransformInfo(
            index: index,
            width: viewport.width,
            height: viewport.height,
            position:
                ((realIndex - page) * direction * fraction).clamp(-1.0, 1.0),
            activeIndex: controller.getRenderIndexFromRealIndex(page.round()),
            fromIndex: controller.getRenderIndexFromRealIndex(fromPage.round()),
            forward: (page - fromPage) * direction >= 0,
            done: _scrollStartPage == null,
            scrollDirection: widget.scrollDirection,
            viewportFraction: fraction,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.biggest;
          return NotificationListener<ScrollNotification>(
            onNotification: _trackScroll,
            child: PageView.builder(
              key: ObjectKey(_pages),
              itemBuilder: (context, index) =>
                  _buildPage(context, index, viewport),
              itemCount: _pages.getRealItemCount(),
              onPageChanged: (index) => widget.onPageChanged
                  ?.call([_pages.getRenderIndexFromRealIndex(index), index]),
              controller: _pages,
              scrollDirection: widget.scrollDirection,
              physics: widget.physics,
              pageSnapping: widget.pageSnapping,
              allowImplicitScrolling: widget.allowImplicitScrolling,
              reverse: _pages.reverse,
            ),
          );
        },
      );

  @override
  void dispose() {
    widget.controller?.removeListener(_onIndexCommand);
    widget.controller?.complete();
    if (widget.pageController == null) _pages.dispose();
    super.dispose();
  }
}
