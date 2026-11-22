# TransformerPageView 开发文档

`TransformerPageView` 基于 Flutter 的 `PageView.builder` 提供循环分页、程序化翻页和页面转场。Manhattan 通过本地路径依赖使用这个 Git 子模块，当前包版本为 `0.1.6`。历史发布记录见 [CHANGELOG.md](CHANGELOG.md)。

## 组件职责

| 组件 | 职责 |
| --- | --- |
| `TransformerPageView` | 接收配置，管理滚动控制器的接入和生命周期，构建页面并派发 `onPageChanged`。 |
| `TransformerPageController` | 继承 `PageController`，保存 `loop`、`reverse`、`itemCount` 和 `viewportFraction`，转换逻辑索引与实际页码。 |
| `IndexController` | 提供 `move`、`next`、`previous` 命令，管理命令完成和被覆盖时的 `Future<void>`。 |
| `PageTransformer`、`PageTransformerBuilder` | 接收页面内容和 `TransformInfo`，生成转场效果。`parallax.dart` 提供颜色、图片和容器的视差组件。 |

分页、控制器和转场接口位于 [transformer_page_view.dart](lib/transformer_page_view.dart)，命令与视差实现分别位于 [index_controller.dart](lib/index_controller.dart) 和 [parallax.dart](lib/parallax.dart)。

## 索引约定

| 值 | 用途 |
| --- | --- |
| 逻辑索引 `index` | 素材位置，范围为 `0` 到 `itemCount - 1`。用于 `itemBuilder` 的第二个参数，以及 `TransformInfo.index`、`activeIndex` 和 `fromIndex`。 |
| 实际页码 `realIndex` | `PageView` 的位置。用于 `itemBuilder` 的第三个参数，以及直接调用 `jumpToPage` 或 `animateToPage`。 |
| `onPageChanged` | 依次返回 `[逻辑索引, 实际页码]`。 |
| `realPage` 与 `page` | `realPage` 读取 Flutter 的实际滚动页位置。循环模式下 `page` 返回映射到素材范围的逻辑页位置，非循环模式下保留 Flutter 的实际页位置。两者都可能带小数。 |

`getRenderIndexFromRealIndex` 将实际页码映射到素材索引，`getRealIndexFromRenderIndex` 将逻辑索引映射到初始循环附近的实际页码。循环模式从 `kMiddleValue` 附近开始，向前和向后都留有滚动空间。例如，三个素材正向循环时，实际页 `kMiddleValue - 1` 对应最后一个素材。反向模式按相反的顺序映射。素材为空时构建零页，非循环模式使用有限页数。非空循环模式向 `PageView.builder` 传入 `null` 页数，避免巨大有限页数在非整页视口下产生滚动范围精度问题。

## 控制器生命周期

- 内部控制器由组件创建和释放。普通父级重建会复用它。素材数、循环模式、视口比例或反向配置变化时会替换控制器，并根据显式 `index` 或当前逻辑页选取有效的目标页。旧控制器在 `PageView` 脱离后释放。
- 外部 `pageController` 由调用方创建和释放。它的配置决定实际页数、循环、反向和视口比例。显式 `index` 在本帧布局后应用，执行前会检查组件、控制器和目标索引是否仍然有效。把 `onPageChanged` 返回的当前逻辑页回传给 `index` 时，已有动画可以继续完成。
- `IndexController` 由调用方持有。组件负责订阅、换绑和解绑。`move` 将目标索引映射到实际页码，`next` 和 `previous` 从当前页按逻辑顺序定位相邻页。非循环模式下，`next` 和 `previous` 在首尾之间回绕，手势滚动仍受原生页数约束。
- 较新的命令会让上一条命令的 `Future` 结束，旧动画的完成回调只会结算对应命令。没有订阅者、页面尚未挂载或组件解绑时，相关 `Future` 也会结束。实际展示页从 `onPageChanged` 获取。

## 转场与画布集成

`LayoutBuilder` 提供当前视口尺寸。没有转场时直接使用 `itemBuilder` 的内容。有转场时，`AnimatedBuilder` 将页面内容作为 `child` 复用，并在滚动时重新计算 `TransformInfo`。滚动范围就绪前，以待构建页作为当前位置，使转场能从首帧渲染。滚动范围就绪后，当前位置和起始页都从实际滚动位置计算，再转换为逻辑索引。组件只用当前 `PageView` 的滚动通知记录起始位置。`position` 按控制器的视口比例换算并限制在 `[-1, 1]`，`forward` 反映逻辑翻页方向。

Manhattan 编辑器的 `ScreenItemWidget` 使用子屏 `eid` 和素材数量作为轮播容器的 Key。拖动或缩放只改变几何属性时，`PowerBannerPage` 和画面内容可以保持挂载。子屏或素材数量变化时会重新挂载。`PowerBannerPage` 用 `useMemoized` 在挂载时创建两个控制器，避免在 `build()` 中反复求值构造参数，由 `useEffect` 在卸载时释放。编辑器替换 `MHScreen` 实例后，轮播会在新实例上注册切页和按键回调。对应代码位于主工程的 `manhattan_cast/lib/ui/page_cast.dart` 和 `manhattan_cast/lib/ui/page_power_banner.dart`。

## 回归测试

在本库目录运行组件测试。

```sh
flutter pub get
flutter test
```

- [transformer_page_view_test.dart](test/transformer_page_view_test.dart) 覆盖首帧和重新挂载、空列表、控制器更换与释放、连续命令、循环正反向、视口调整和 `children` 构造入口。
- [loop_layout_test.dart](test/loop_layout_test.dart) 覆盖横竖方向、不同视口比例、空列表和单素材，以及非循环模式的滚动边界。

在 Manhattan 工程根目录运行编辑器和播放器集成回归。

```sh
flutter test test/page_cast_load_state_test.dart test/sub_screen_editor_test.dart manhattan_cast/test/random_banner_test.dart
```

淡入淡出子屏的拖动用例逐帧检查轮播实例、图片实例和转场透明度。播放器用例验证了替换子屏对象后仍可按逻辑索引选中素材。

## 变更记录

### 未发布 · 2026-11-22

- 使用当前布局约束渲染首帧，移除延迟测量和重复滚动状态。读取实际页码前检查滚动范围，兼容 Flutter 3.19.6 的布局时序。
- 修复内部控制器在父级重建时重置页码、外部控制器尚未挂载时发起翻页，以及连续命令导致的 `Future` 悬挂。
- 统一循环和反向模式的转场索引与方向，修复 `ParallaxColor` 接收到实际页码后访问颜色数组越界的问题。修复 `viewportFraction` 和 `children` 入口参数传递。
- 保留节目编辑器拖动期间的轮播和素材实例，补充组件和集成回归测试。

验证记录为 Flutter 3.50.1 专项测试 95 项通过、Flutter 3.19.6 组件测试 20 项通过，Flutter 测试引擎热重载成功。应用全量与相关组件回归共 496 项通过、5 项跳过，1 项既有失败来自局域网历史记录条数断言。

### 本地分支历史

| 日期 | 提交 | 变更 |
| --- | --- | --- |
| 2026-09-18 | `8f7d1c8` | 非空循环模式使用无上界的 `PageView.builder`，补充视口比例和滚动边界测试。 |
| 2026-02-14 | `f6cd3ad` | 增加 `allowImplicitScrolling` 配置。 |
| 2025-12-17 | `85c222e` | 调整循环页码的 `kMiddleValue` 和 `kMaxValue` 常量。 |
| 2025-11-13 | `1035ff4` | 为 `IndexController` 构造函数加入初始索引。 |
| 2024-04-27 至 2024-04-28 | `ad3913c`、`c63caa0` | 更新 Dart SDK 约束并适配 Flutter 3。 |
