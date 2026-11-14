import 'package:flutter/material.dart';

import '../core/navigation.dart';
import '../core/theme.dart';
import '../data/account_api.dart';
import '../data/app_store.dart';
import '../data/models.dart';
import 'common.dart';

/// Runs a create / rename call and explains a refusal (duplicate name, limit) in the user's language.
Future<void> collectionAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on ApiFailure catch (failure) {
    if (context.mounted) {
      toast(context, failure.errors['name'] ?? failure.detail);
    }
  } catch (_) {
    if (context.mounted) toast(context, 'Bir sorun oluştu. Tekrar dene.');
  }
}

/// Asks for a collection name (max 40 characters). Returns the trimmed name, or null when dismissed.
Future<String?> askCollectionName(
  BuildContext context, {
  String title = 'Yeni koleksiyon',
  String action = 'Oluştur',
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        key: const Key('collection-name-field'),
        controller: controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Örn. Alanya'),
        onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const Key('collection-name-save'),
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: Text(action),
        ),
      ],
    ),
  );
  // Disposed after the dialog's exit animation, never while it is still on screen.
  WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  return result == null || result.isEmpty ? null : result;
}

/// "Koleksiyona Ekle": lists the user's collections with the ones holding this post ticked, plus "Yeni koleksiyon".
/// The post must already be saved; leaving a collection never un-saves it.
Future<void> showAddToCollectionSheet(
  BuildContext context,
  AppStore store,
  Post post,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => _CollectionSheet(store: store, post: post),
  );
}

class _CollectionSheet extends StatefulWidget {
  const _CollectionSheet({required this.store, required this.post});
  final AppStore store;
  final Post post;

  @override
  State<_CollectionSheet> createState() => _CollectionSheetState();
}

class _CollectionSheetState extends State<_CollectionSheet> {
  List<SavedCollection>? items;
  String? error;
  final busy = <int>{};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final result = await widget.store.loadCollections(postId: widget.post.id);
      if (mounted) setState(() => items = result);
    } on ApiFailure catch (failure) {
      if (mounted) setState(() => error = failure.detail);
    } catch (_) {
      if (mounted) setState(() => error = 'Koleksiyonlar yüklenemedi.');
    }
  }

  Future<void> toggle(SavedCollection collection) async {
    if (!busy.add(collection.id)) return;
    setState(() {});
    try {
      await widget.store.setCollectionMembership(
        collection,
        widget.post,
        collection.containsPost != true,
      );
    } on ApiFailure catch (failure) {
      if (mounted) toast(context, failure.detail);
    } finally {
      busy.remove(collection.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> create() async {
    final name = await askCollectionName(context);
    if (name == null || !mounted) return;
    try {
      final created = await widget.store.createCollection(name);
      await widget.store.setCollectionMembership(created, widget.post, true);
      await load();
    } on ApiFailure catch (failure) {
      if (mounted) toast(context, failure.errors['name'] ?? failure.detail);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = items;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
          children: [
            Text('Koleksiyona Ekle', style: AppTypography.section),
            const SizedBox(height: 2),
            const Text(
              'Koleksiyonlar yalnızca sana görünür. Gönderi Kaydedilenler’de kalır.',
              style: AppTypography.metadata,
            ),
            const SizedBox(height: Space.sm),
            if (error != null)
              InlineState(
                icon: Icons.wifi_off_outlined,
                title: 'Koleksiyonlar yüklenemedi',
                description: error,
                actionLabel: 'Tekrar Dene',
                onAction: () {
                  setState(() => error = null);
                  load();
                },
              )
            else if (list == null)
              const LoadingState(compact: true)
            else ...[
              for (final collection in list)
                CheckboxListTile(
                  key: ValueKey('sheet-collection-${collection.id}'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: collection.containsPost == true,
                  onChanged: busy.contains(collection.id)
                      ? null
                      : (_) => toggle(collection),
                  title: Text(
                    collection.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  secondary: Text(
                    '${collection.postsCount}',
                    style: AppTypography.metadata,
                  ),
                ),
              ListTile(
                key: const Key('sheet-new-collection'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_rounded, color: AppColors.action),
                title: const Text(
                  'Yeni koleksiyon oluştur',
                  style: TextStyle(
                    color: AppColors.action,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: create,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The chip row above Kaydedilenler: Tümü | collections… | +. Scrolls sideways, never overflows.
class CollectionChips extends StatelessWidget {
  const CollectionChips({
    super.key,
    required this.collections,
    required this.selected,
    required this.onSelect,
    required this.onCreate,
  });
  final List<SavedCollection> collections;
  final int? selected;
  final ValueChanged<int?> onSelect;
  final VoidCallback onCreate;

  Widget chip({
    required Key key,
    required String label,
    required bool on,
    required VoidCallback onTap,
    IconData? icon,
  }) => Padding(
    padding: const EdgeInsets.only(right: Space.sm),
    child: ChoiceChip(
      key: key,
      label: icon == null
          ? ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            )
          : Icon(icon, size: 18, color: AppColors.action),
      selectedColor: AppColors.action,
      backgroundColor: AppColors.surface,
      side: BorderSide(color: on ? AppColors.action : AppColors.line),
      selected: on,
      showCheckmark: false,
      tooltip: icon == null ? null : 'Yeni koleksiyon',
      labelStyle: TextStyle(
        fontFamily: 'NunitoSans',
        fontSize: 12.5,
        fontWeight: on ? FontWeight.w700 : FontWeight.w600,
        color: on ? Colors.white : AppColors.navy,
      ),
      onSelected: (_) => onTap(),
    ),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    width: double.infinity,
    child: SingleChildScrollView(
      key: const Key('collection-chips'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      child: Row(
        children: [
          chip(
            key: const Key('collection-all'),
            label: 'Tümü',
            on: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final collection in collections)
            chip(
              key: ValueKey('collection-${collection.id}'),
              label: collection.name,
              on: selected == collection.id,
              onTap: () => onSelect(collection.id),
            ),
          chip(
            key: const Key('collection-new'),
            label: '+',
            icon: Icons.add_rounded,
            on: false,
            onTap: onCreate,
          ),
        ],
      ),
    ),
  );
}
