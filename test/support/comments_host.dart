import 'package:flutter/material.dart';
import 'package:senmiydin/data/app_store.dart';
import 'package:senmiydin/data/models.dart';
import 'package:senmiydin/widgets/comments_sheet.dart';

/// Test page: loads post [id] and raises the comments sheet over it, exactly like the post card's comment action does.
class OpenComments extends StatefulWidget {
  const OpenComments(this.id, {super.key});
  final String id;
  @override
  State<OpenComments> createState() => _OpenCommentsState();
}

class _OpenCommentsState extends State<OpenComments> {
  Post? post;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final loaded = await StoreScope.of(context).loadPost(widget.id);
      if (!mounted) return;
      setState(() => post = loaded);
      showCommentsSheet(context, loaded);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text(post == null ? 'loading' : 'underlying page')),
  );
}
