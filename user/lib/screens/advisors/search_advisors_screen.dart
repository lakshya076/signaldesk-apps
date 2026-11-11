import 'package:flutter/material.dart';

class SearchAdvisorsScreen extends StatefulWidget {
  final List<dynamic> discoverAdvisors;
  final Function(String) onSubscribe;

  const SearchAdvisorsScreen({
    super.key,
    required this.discoverAdvisors,
    required this.onSubscribe,
  });

  @override
  State<SearchAdvisorsScreen> createState() => _SearchAdvisorsScreenState();
}

class _SearchAdvisorsScreenState extends State<SearchAdvisorsScreen> {
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchResults = widget.discoverAdvisors;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toUpperCase();
    setState(() {
      _searchResults =
          query.isEmpty
              ? widget.discoverAdvisors
              : widget.discoverAdvisors.where((advisor) {
                final fullName =
                    '${advisor['first_name'] ?? ''} ${advisor['last_name'] ?? ''}'
                        .toUpperCase();
                return fullName.contains(query);
              }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search for advisors...',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child:
                    _searchResults.isEmpty
                        ? const Center(child: Text("No advisors found"))
                        : ListView.builder(
                          controller: controller,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final advisor = _searchResults[index];
                            final fullName =
                                '${advisor['first_name'] ?? ''} ${advisor['last_name'] ?? ''}'
                                    .trim();
                            final initial =
                                (advisor['first_name'] ?? '?').isNotEmpty
                                    ? advisor['first_name'][0].toUpperCase()
                                    : '?';

                            return SizedBox(
                              height: 72.0,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: theme.colorScheme.primary
                                          .withValues(alpha: .1),
                                      foregroundColor:
                                          theme.colorScheme.primary,
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        widget.onSubscribe(advisor['id']);
                                        Navigator.pop(context, true);
                                      },
                                      child: const Text('Subscribe'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        );
      },
    );
  }
}
