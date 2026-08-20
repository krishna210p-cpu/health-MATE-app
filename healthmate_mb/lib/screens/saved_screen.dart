import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/article.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<Article> _saved = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final box = await Hive.openBox('saved_articles');
    final list = box.get('items', defaultValue: []) as List;
    setState(() {
      _saved = list.map((e) => Article.fromMap(Map<String, dynamic>.from(e))).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: _saved.isEmpty ? const Center(child: Text('No saved articles')) : ListView.builder(
        itemCount: _saved.length,
        itemBuilder: (context, i) {
          final a = _saved[i];
          return ListTile(title: Text(a.title), subtitle: Text(a.source));
        },
      ),
    );
  }
}
