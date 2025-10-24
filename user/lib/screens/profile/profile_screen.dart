import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signaldesk_user/core/advisor_filter_provider.dart';
import 'package:signaldesk_user/core/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String _fullName = 'User';
  String _email = '';
  String _initial = '?';
  List<dynamic> _subscribedAdvisors = [];

  @override
  void initState() {
    super.initState();
    // Fetch both profile data and subscribed advisors at the same time
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Fetch profile data (name, email)
      final profileResponse =
          await Supabase.instance.client
              .from('profiles')
              .select('first_name, last_name, email')
              .eq('id', user.id)
              .single();

      final firstName = profileResponse['first_name'] ?? '';
      final lastName = profileResponse['last_name'] ?? '';

      // Fetch subscribed advisor IDs
      final subscriptionsResponse = await Supabase.instance.client
          .from('subscriptions')
          .select('advisor_id')
          .eq('user_id', user.id);

      final advisorIds =
          (subscriptionsResponse as List)
              .map((sub) => sub['advisor_id'] as String)
              .toList();

      List<dynamic> advisors = [];
      if (advisorIds.isNotEmpty) {
        // Fetch full profiles for the subscribed advisors using OR conditions
        final orConditions = advisorIds.map((id) => 'id.eq.$id').join(',');
        final advisorsResponse = await Supabase.instance.client
            .from('profiles')
            .select('id, first_name, last_name')
            .or(orConditions);
        advisors = advisorsResponse as List;
      }

      if (mounted) {
        setState(() {
          _fullName = '$firstName $lastName'.trim();
          _email = profileResponse['email'] ?? user.email ?? '';
          _initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';
          _subscribedAdvisors = advisors;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching profile data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Filters'),
        actions: [
          // Clear filter button appears when a filter is active
          Consumer<AdvisorFilterProvider>(
            builder: (context, filterProvider, child) {
              final selectedIds = filterProvider.selectedAdvisorIds;
              if (selectedIds.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.filter_alt_off_outlined),
                onPressed:
                    () =>
                        Provider.of<AdvisorFilterProvider>(
                          context,
                          listen: false,
                        ).clearFilter(),
                tooltip: 'Clear Filters',
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _fetchData,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // User Info Section
                    Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: .1,
                          ),
                          foregroundColor: theme.colorScheme.primary,
                          child: Text(
                            _initial,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _fullName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // NEW: Filter by Advisor section is now directly on this screen
                    _buildAdvisorFilterSection(context),

                    const SizedBox(height: 24),

                    // Settings Card
                    Card(
                      child: Column(
                        children: [
                          Consumer<ThemeProvider>(
                            builder: (context, themeProvider, child) {
                              return SwitchListTile(
                                title: const Text('Dark Mode'),
                                value:
                                    themeProvider.themeMode == ThemeMode.dark,
                                onChanged: (isDark) {
                                  themeProvider.toggleTheme();
                                },
                                secondary: const Icon(
                                  Icons.brightness_6_outlined,
                                ),
                              );
                            },
                          ),
                          // ... (Other settings can go here)
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Logout Button
                    ElevatedButton.icon(
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.error.withValues(
                          alpha: 0.1,
                        ),
                        foregroundColor: theme.colorScheme.error,
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  // Helper widget to build the filter section UI
  Widget _buildAdvisorFilterSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter Trades by Advisor',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap one or more advisors to see only their trades.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).hintColor),
        ),
        const SizedBox(height: 16),
        _subscribedAdvisors.isEmpty
            ? Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'You are not subscribed to any advisors. Go to the Advisors tab to subscribe.',
                      ),
                    ),
                  ],
                ),
              ),
            )
            : Consumer<AdvisorFilterProvider>(
              builder: (context, filterProvider, child) {
                final selectedIds = filterProvider.selectedAdvisorIds;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 3 / 2.5,
                  ),
                  itemCount: _subscribedAdvisors.length,
                  itemBuilder: (context, index) {
                    final advisor = _subscribedAdvisors[index];
                    final advisorId = advisor['id'] as String;
                    final fullName =
                        '${advisor['first_name'] ?? ''} ${advisor['last_name'] ?? ''}'
                            .trim();
                    final initial =
                        (advisor['first_name'] ?? '?').isNotEmpty
                            ? advisor['first_name'][0].toUpperCase()
                            : '?';
                    final isSelected = selectedIds.contains(advisorId);

                    return GestureDetector(
                      onTap: () {
                        filterProvider.toggleAdvisor(advisorId);
                      },
                      child: Card(
                        elevation: isSelected ? 4 : 1,
                        color:
                            isSelected
                                ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: .3)
                                : Theme.of(context).cardTheme.color,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color:
                                isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(radius: 24, child: Text(initial)),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4.0,
                              ),
                              child: Text(
                                fullName,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      ],
    );
  }
}
