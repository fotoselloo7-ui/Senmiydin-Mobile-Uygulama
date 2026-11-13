import 'package:flutter/material.dart';

Future<T?> openPage<T>(
  BuildContext context,
  String route, [
  Object? arguments,
]) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final result = await Navigator.of(context)
      .pushNamed(route, arguments: arguments);
  return result as T?;
}

void home(BuildContext context) =>
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
void toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Onayla',
  bool scrollable = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: scrollable,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
