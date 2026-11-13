import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/app_store.dart';

/// Resolves a post/encounter/message photo path to an [ImageProvider].
///
/// Remote photos carry the authenticated media headers, bundled demo photos use
/// assets and locally picked photos use their file path.
ImageProvider mediaImageProvider(AppStore store, String path) {
  final uri = Uri.tryParse(path);
  if (uri?.scheme == 'https' || uri?.scheme == 'http') {
    return NetworkImage(path, headers: store.mediaHeaders(path));
  }
  if (path.startsWith('assets/')) return AssetImage(path);
  return FileImage(File(path));
}

/// Opens the shared photo viewer above a darkened backdrop.
///
/// Returns the index of the photo the user last looked at, so the caller can
/// keep its inline gallery in sync. Photos are never downloaded or shared from
/// here; the viewer only shows them.
Future<int?> showMediaViewer(
  BuildContext context,
  List<String> images, {
  int initialIndex = 0,
}) async {
  if (images.isEmpty) return null;
  final store = StoreScope.of(context);
  var last = initialIndex.clamp(0, images.length - 1);
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Kapat',
    barrierColor: Colors.black.withValues(alpha: .76),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (_, _, _) => MediaViewer(
      store: store,
      images: images,
      initialIndex: last,
      onIndexChanged: (i) => last = i,
    ),
    transitionBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: .96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
  return last;
}

/// Light, rounded photo viewer: horizontal pager, pinch/double-tap zoom,
/// counter, dots and a thumbnail strip. Navigation is swipe based on mobile, so
/// there are intentionally no previous/next arrows.
class MediaViewer extends StatefulWidget {
  const MediaViewer({
    super.key,
    required this.store,
    required this.images,
    this.initialIndex = 0,
    this.onIndexChanged,
  });
  final AppStore store;
  final List<String> images;
  final int initialIndex;
  final ValueChanged<int>? onIndexChanged;

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  static const _headerHeight = 52.0;
  static const _thumbWidth = 76.0;
  static const _thumbHeight = 54.0;
  static const _thumbGap = 8.0;
  static const _thumbPadding = 12.0;
  static const _minPhotoHeight = 260.0;

  late final PageController pager;
  final thumbs = ScrollController();
  final aspects = <int, double>{};
  late int index;
  bool zoomed = false;
  int pointers = 0;

  int get count => widget.images.length;
  bool get paging => !zoomed && pointers < 2;

  @override
  void initState() {
    super.initState();
    index = widget.initialIndex.clamp(0, count - 1);
    pager = PageController(initialPage: index, keepPage: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealThumb(false));
  }

  @override
  void dispose() {
    pager.dispose();
    thumbs.dispose();
    super.dispose();
  }

  void _pointer(int delta) {
    final before = paging;
    pointers = math.max(0, pointers + delta);
    if (before != paging && mounted) setState(() {});
  }

  void _goTo(int target) {
    if (target == index || !pager.hasClients) return;
    if ((target - index).abs() > 1) {
      pager.jumpToPage(target);
    } else {
      pager.animateToPage(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _revealThumb([bool animate = true]) {
    if (!thumbs.hasClients || thumbs.position.maxScrollExtent <= 0) return;
    final center =
        _thumbPadding + index * (_thumbWidth + _thumbGap) + _thumbWidth / 2;
    final target = (center - thumbs.position.viewportDimension / 2).clamp(
      0.0,
      thumbs.position.maxScrollExtent,
    );
    if (animate) {
      thumbs.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      thumbs.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final multi = count > 1;
    final showDots = multi && count <= 5;
    return Semantics(
      scopesRoute: true,
      explicitChildNodes: true,
      label: 'Fotoğraf görüntüleyici',
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Space.sm),
            child: Center(
              child: LayoutBuilder(
                builder: (context, box) {
                  const dotsHeight = 22.0;
                  const thumbsBlock = _thumbHeight + 20;
                  const bottomPadding = 12.0;
                  final photoWidth = box.maxWidth - 2 * Space.sm;
                  final maxPhoto =
                      box.maxHeight -
                      _headerHeight -
                      (showDots ? dotsHeight : 0) -
                      (multi ? thumbsBlock : 0) -
                      bottomPadding;
                  final aspect = aspects[index] ?? 4 / 3;
                  final photoHeight = (photoWidth / aspect).clamp(
                    _minPhotoHeight,
                    math.max(_minPhotoHeight, maxPhoto),
                  ).toDouble();
                  return Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .25),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: _headerHeight,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: Space.sm),
                              child: _CloseButton(
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: Space.sm,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            height: photoHeight,
                            child: _photoArea(),
                          ),
                        ),
                        if (showDots) _dots(),
                        if (multi) _thumbStrip(),
                        const SizedBox(height: bottomPadding),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoArea() => Stack(
    children: [
      Positioned.fill(
        child: ClipRRect(
          borderRadius: AppShape.rounded,
          child: ColoredBox(
            color: AppColors.surfaceSecondary,
            child: Listener(
              onPointerDown: (_) => _pointer(1),
              onPointerUp: (_) => _pointer(-1),
              onPointerCancel: (_) => _pointer(-1),
              child: PageView.builder(
                controller: pager,
                physics: paging
                    ? const PageScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: count,
                onPageChanged: (i) {
                  setState(() {
                    index = i;
                    zoomed = false;
                  });
                  widget.onIndexChanged?.call(i);
                  _revealThumb();
                },
                itemBuilder: (_, i) => _ViewerPage(
                  key: ValueKey('$i:${widget.images[i]}'),
                  store: widget.store,
                  path: widget.images[i],
                  active: i == index,
                  multi: count > 1,
                  pointers: pointers,
                  semanticLabel: count > 1
                      ? 'Fotoğraf ${i + 1} / $count'
                      : 'Fotoğraf',
                  onAspect: (a) {
                    if (mounted && aspects[i] != a) {
                      setState(() => aspects[i] = a);
                    }
                  },
                  onZoom: (z) {
                    if (mounted && i == index && zoomed != z) {
                      setState(() => zoomed = z);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      if (count > 1)
        Positioned(
          right: 10,
          top: 10,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: .72),
                borderRadius: BorderRadius.circular(AppShape.large),
              ),
              child: Text(
                '${index + 1}/$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _dots() => Padding(
    padding: const EdgeInsets.only(top: Space.md),
    child: SizedBox(
      height: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: i == index ? 14 : 5,
            height: 5,
            decoration: BoxDecoration(
              color: i == index ? AppColors.primary : AppColors.borderStrong,
              borderRadius: BorderRadius.circular(AppShape.pill),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _thumbStrip() => Padding(
    padding: const EdgeInsets.only(top: Space.md),
    child: SizedBox(
      height: _thumbHeight,
      child: Center(
        child: SingleChildScrollView(
          controller: thumbs,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: _thumbPadding),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: _thumbGap),
                _Thumb(
                  store: widget.store,
                  path: widget.images[i],
                  active: i == index,
                  label: '${i + 1}. görsel',
                  width: _thumbWidth,
                  height: _thumbHeight,
                  onTap: () => _goTo(i),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Kapat',
    onPressed: onPressed,
    padding: const EdgeInsets.all(6),
    constraints: const BoxConstraints.tightFor(
      width: AppDimensions.touch,
      height: AppDimensions.touch,
    ),
    icon: const DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(Icons.close_rounded, size: 22, color: AppColors.navy),
      ),
    ),
  );
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.store,
    required this.path,
    required this.active,
    required this.label,
    required this.width,
    required this.height,
    required this.onTap,
  });
  final AppStore store;
  final String path;
  final bool active;
  final String label;
  final double width, height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: active,
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: width,
        height: height,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppShape.small),
          border: Border.all(
            color: active ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppShape.small - 4),
          child: Image(
            image: mediaImageProvider(store, path),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: AppColors.surfaceSecondary),
          ),
        ),
      ),
    ),
  );
}

class _ViewerPage extends StatefulWidget {
  const _ViewerPage({
    super.key,
    required this.store,
    required this.path,
    required this.active,
    required this.multi,
    required this.pointers,
    required this.semanticLabel,
    required this.onAspect,
    required this.onZoom,
  });
  final AppStore store;
  final String path;
  final bool active;
  final bool multi;
  final int pointers;
  final String semanticLabel;
  final ValueChanged<double> onAspect;
  final ValueChanged<bool> onZoom;

  @override
  State<_ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<_ViewerPage>
    with SingleTickerProviderStateMixin {
  static const _doubleTapScale = 2.5;

  final controller = TransformationController();
  late final AnimationController animation;
  late final ImageProvider provider;
  Matrix4Tween? zoomTween;
  ImageStream? stream;
  ImageStreamListener? listener;
  Offset? doubleTapAt;
  bool zoomed = false;
  bool failed = false;
  int attempt = 0;

  @override
  void initState() {
    super.initState();
    provider = mediaImageProvider(widget.store, widget.path);
    animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(_animateZoom);
    controller.addListener(_zoomChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (stream == null) _listen();
  }

  @override
  void didUpdateWidget(_ViewerPage old) {
    super.didUpdateWidget(old);
    if (old.active && !widget.active && zoomed) {
      // Reset after the frame: the pager may still be building this page.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.active) controller.value = Matrix4.identity();
      });
    }
  }

  @override
  void dispose() {
    _unlisten();
    animation.dispose();
    controller
      ..removeListener(_zoomChanged)
      ..dispose();
    super.dispose();
  }

  void _listen() {
    _unlisten();
    final next = provider.resolve(createLocalImageConfiguration(context));
    final l = ImageStreamListener(
      (info, _) {
        final aspect = info.image.width / math.max(1, info.image.height);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onAspect(aspect);
        });
      },
      onError: (_, _) {
        if (mounted) setState(() => failed = true);
      },
    );
    next.addListener(l);
    stream = next;
    listener = l;
  }

  void _unlisten() {
    final l = listener;
    if (l != null) stream?.removeListener(l);
    stream = null;
    listener = null;
  }

  void _retry() {
    provider.evict();
    setState(() {
      failed = false;
      attempt++;
    });
    _listen();
  }

  void _zoomChanged() {
    final now = controller.value.getMaxScaleOnAxis() > 1.02;
    if (now == zoomed) return;
    setState(() => zoomed = now);
    widget.onZoom(now);
  }

  void _animateZoom() {
    final tween = zoomTween;
    if (tween == null) return;
    controller.value = tween.transform(
      Curves.easeOutCubic.transform(animation.value),
    );
  }

  void _toggleZoom() {
    final Matrix4 end;
    if (zoomed) {
      end = Matrix4.identity();
    } else {
      final p = doubleTapAt ?? Offset.zero;
      end = Matrix4.identity()
        ..translateByDouble(
          -p.dx * (_doubleTapScale - 1),
          -p.dy * (_doubleTapScale - 1),
          0,
          1,
        )
        ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
    }
    zoomTween = Matrix4Tween(begin: controller.value, end: end);
    animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (failed) return _error();
    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: GestureDetector(
        onDoubleTapDown: (d) => doubleTapAt = d.localPosition,
        onDoubleTap: _toggleZoom,
        child: InteractiveViewer(
          transformationController: controller,
          minScale: 1,
          maxScale: 4,
          panEnabled: zoomed,
          scaleEnabled: !widget.multi || zoomed || widget.pointers >= 2,
          child: SizedBox.expand(
            child: Image(
              key: ValueKey(attempt),
              image: provider,
              fit: BoxFit.contain,
              frameBuilder: (_, child, frame, sync) => AnimatedOpacity(
                opacity: frame == null && !sync ? 0 : 1,
                duration: const Duration(milliseconds: 140),
                child: child,
              ),
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                final total = progress.expectedTotalBytes;
                return Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.primary,
                      value: total == null
                          ? null
                          : progress.cumulativeBytesLoaded / total,
                    ),
                  ),
                );
              },
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _error() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Görsel yüklenemedi',
          style: TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: Space.sm),
        TextButton(
          onPressed: _retry,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            minimumSize: const Size(AppDimensions.touch, AppDimensions.touch),
          ),
          child: const Text('Tekrar Dene'),
        ),
      ],
    ),
  );
}

