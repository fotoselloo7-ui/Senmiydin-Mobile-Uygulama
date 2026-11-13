import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/navigation.dart';
import '../data/account_api.dart';

mixin AccountAction<T extends StatefulWidget> on State<T> {
  bool busy = false;

  Future<void> runAccountAction(Future<void> Function() action) async {
    if (busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => busy = true);
    try {
      await action();
    } on ApiFailure catch (error) {
      if (mounted) toast(context, error.detail);
    } catch (error) {
      assert(() {
        debugPrint('Account action failed: ${error.runtimeType}');
        return true;
      }());
      if (mounted) toast(context, 'Bir sorun oluştu. Tekrar dene.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

String? newPasswordError(String? value) {
  final password = value ?? '';
  if (utf8.encode(password).length > 72) {
    return 'Şifren en fazla 72 bayt olabilir.';
  }
  if (password.contains('\u0000')) {
    return 'Şifren geçersiz bir karakter içeriyor.';
  }
  if (password.runes.length < 10 ||
      !RegExp(r'\p{L}', unicode: true).hasMatch(password) ||
      !RegExp(r'\p{N}', unicode: true).hasMatch(password)) {
    return 'En az 10 karakter, bir harf ve bir rakam kullan.';
  }
  return null;
}

bool validEmail(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
