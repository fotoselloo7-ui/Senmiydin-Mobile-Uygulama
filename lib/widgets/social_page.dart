import 'package:flutter/material.dart';

import '../core/navigation.dart';
import '../core/theme.dart';
import 'common.dart';
import '../data/account_api.dart';
import '../data/social_api.dart';

class PagedContent<T> extends StatefulWidget {
  const PagedContent({
    super.key,
    required this.fetch,
    required this.builder,
    this.id,
    this.visible,
  });

  final Future<SocialPage<T>> Function(int) fetch;
  final Widget Function(BuildContext, List<T>, Widget?, Future<void> Function())
  builder;
  final Object Function(T)? id;
  final bool Function(T)? visible;

  @override
  State<PagedContent<T>> createState() => _PagedContentState<T>();
}

class _PagedContentState<T> extends State<PagedContent<T>> {
  final _items = <T>[];
  bool _loading = true;
  String? _error;
  int? _next = 1;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load(1, _generation);
  }

  Future<void> _load(int page, int generation) async {
    try {
      final result = await widget.fetch(page);
      if (!mounted || generation != _generation) return;
      setState(() {
        final identify = widget.id;
        if (identify == null) {
          _items.addAll(result.items);
        } else {
          final seen = _items.map(identify).toSet();
          _items.addAll(result.items.where((item) => seen.add(identify(item))));
        }
        _next = result.nextPage;
        _loading = false;
        _error = null;
      });
    } on ApiFailure catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error.detail;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = 'Bir sorun oluştu. Tekrar dene.';
        _loading = false;
      });
    }
  }

  Future<void> _refresh() {
    setState(() {
      _items.clear();
      _error = null;
      _loading = true;
      _next = 1;
      _generation++;
    });
    return _load(1, _generation);
  }

  void _loadMore() {
    if (_loading || _next == null) return;
    setState(() => _loading = true);
    _load(_next!, _generation);
  }

  @override
  Widget build(BuildContext context) {
    final predicate = widget.visible;
    final items = predicate == null ? _items : _items.where(predicate).toList();
    final Widget? footer = _loading
        ? LoadingState(compact: _items.isNotEmpty)
        : _error != null
        ? Padding(
            padding: Space.page,
            child: InlineState(
              icon: Icons.wifi_off_outlined,
              title: 'İçerik yüklenemedi',
              description: _error!,
              actionLabel: 'Tekrar Dene',
              onAction: _loadMore,
            ),
          )
        : _next != null
        ? Center(
            child: TextButton(
              onPressed: _loadMore,
              child: const Text('Daha Fazla Göster'),
            ),
          )
        : null;
    return widget.builder(context, items, footer, _refresh);
  }
}

Future<void> socialAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on ApiFailure catch (error) {
    if (context.mounted) toast(context, error.detail);
  } catch (_) {
    if (context.mounted) toast(context, 'Bir sorun oluştu. Tekrar dene.');
  }
}
