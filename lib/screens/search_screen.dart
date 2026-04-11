import 'package:flutter/material.dart';
import 'package:sweptie/models/screenshot_item.dart';
import 'package:sweptie/screens/detail_screen.dart';
import 'package:sweptie/services/database_service.dart';
import 'package:sweptie/widgets/screenshot_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<ScreenshotItem> _results = [];
  bool _hasSearched = false;
  bool _isSearching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _results = []; _hasSearched = false; });
      return;
    }
    setState(() => _isSearching = true);
    final results = await DatabaseService.instance.searchScreenshots(query);
    if (mounted) {
      setState(() {
        _results = results;
        _hasSearched = true;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              controller: _controller,
              hintText: 'Search by keyword in screenshot text…',
              leading: const Icon(Icons.search),
              trailing: [
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      _search('');
                    },
                  ),
              ],
              onChanged: _search,
            ),
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (!_hasSearched)
            Expanded(child: _SearchHint())
          else if (_results.isEmpty)
            Expanded(child: _NoResults(query: _controller.text))
          else
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.75,
                ),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final item = _results[index];
                  return ScreenshotCard(
                    item: item,
                    onTap: () async {
                      final updated = await Navigator.push<ScreenshotItem>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => DetailScreen(item: item)),
                      );
                      if (updated != null && mounted) {
                        setState(() {
                          final idx =
                              _results.indexWhere((e) => e.id == updated.id);
                          if (idx != -1) _results[idx] = updated;
                        });
                      }
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.manage_search, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Type a keyword to search',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            'Searches extracted text from all screenshots',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No results for "$query"',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different keyword',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }
}
