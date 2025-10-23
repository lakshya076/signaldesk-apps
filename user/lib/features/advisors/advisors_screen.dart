import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signaldesk_user/models/advisor_profile.dart';
import 'package:signaldesk_user/features/advisors/search_advisors_screen.dart';
import 'package:signaldesk_user/widgets/advisor_list.dart';

class AdvisorsScreen extends StatefulWidget {
  const AdvisorsScreen({super.key});

  @override
  State<AdvisorsScreen> createState() => _AdvisorsScreenState();
}

class _AdvisorsScreenState extends State<AdvisorsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _showFab = false;
  List<AdvisorProfile> _subscribedAdvisors = [];
  List<AdvisorProfile> _discoverAdvisors = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() => _showFab = _tabController.index == 1);
    });
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // This query now joins profiles with advisor_statistics
      final responses = await Future.wait([
        Supabase.instance.client
            .from('profiles')
            .select('id, first_name, last_name, advisor_statistics(*)')
            .eq('role', 'advisor'),
        Supabase.instance.client
            .from('subscriptions')
            .select('advisor_id')
            .eq('user_id', userId),
      ]);

      final allAdvisorsJson = responses[0] as List;
      final allAdvisors =
          allAdvisorsJson.map((json) => AdvisorProfile.fromJson(json)).toList();

      final subscriptions = responses[1] as List;
      final subscribedIds =
          subscriptions.map((sub) => sub['advisor_id'] as String).toSet();

      if (mounted) {
        setState(() {
          _subscribedAdvisors =
              allAdvisors
                  .where((advisor) => subscribedIds.contains(advisor.id))
                  .toList();
          _discoverAdvisors =
              allAdvisors
                  .where((advisor) => !subscribedIds.contains(advisor.id))
                  .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching advisors: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSubscriptionChange(
    String advisorId,
    bool isSubscribing,
  ) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      if (isSubscribing) {
        await Supabase.instance.client.from('subscriptions').insert({
          'user_id': userId,
          'advisor_id': advisorId,
        });
      } else {
        await Supabase.instance.client.from('subscriptions').delete().match({
          'user_id': userId,
          'advisor_id': advisorId,
        });
      }
      _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating subscription: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Subscribed'), Tab(text: 'Discover')],
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                controller: _tabController,
                children: [
                  AdvisorList(
                    advisors: _subscribedAdvisors,
                    isSubscribedList: true,
                    onSubscriptionChange:
                        (advisorId) =>
                            _handleSubscriptionChange(advisorId, false),
                  ),
                  AdvisorList(
                    advisors: _discoverAdvisors,
                    isSubscribedList: false,
                    onSubscriptionChange:
                        (advisorId) =>
                            _handleSubscriptionChange(advisorId, true),
                  ),
                ],
              ),
      floatingActionButton:
          _showFab
              ? FloatingActionButton(
                onPressed: () async {
                  await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder:
                        (context) => SearchAdvisorsScreen(
                          discoverAdvisors: _discoverAdvisors,
                          onSubscribe:
                              (advisorId) =>
                                  _handleSubscriptionChange(advisorId, true),
                        ),
                  );
                },
                child: const Icon(Icons.search),
              )
              : null,
    );
  }
}
