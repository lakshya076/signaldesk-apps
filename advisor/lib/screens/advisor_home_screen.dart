import 'dart:async';
import 'package:flutter/material.dart';
import 'package:signaldesk_advisor/models/advisor_stats.dart';
import 'package:signaldesk_advisor/models/stock.dart';
import 'package:signaldesk_advisor/models/trade_card_model.dart';
import 'package:signaldesk_advisor/services/api_service.dart';
import 'package:signaldesk_advisor/view_models/active_trade_card_view_model.dart';
import 'package:signaldesk_advisor/view_models/closed_trade_card_view_model.dart';
import 'package:signaldesk_advisor/widgets/active_trade_card.dart';
import 'package:signaldesk_advisor/widgets/closed_trade_card.dart';
import 'package:signaldesk_advisor/widgets/stat_card.dart';
import 'package:signaldesk_advisor/widgets/trade_card_header.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdvisorHomeScreen extends StatefulWidget {
  final VoidCallback onViewActive;
  final VoidCallback onViewClosed;
  final Stream<Map<String, dynamic>>? priceStream;
  final Function(List<String> symbols) onSubscribe;

  const AdvisorHomeScreen({
    super.key,
    required this.onViewActive,
    required this.onViewClosed,
    this.priceStream,
    required this.onSubscribe,
  });

  @override
  State<AdvisorHomeScreen> createState() => _AdvisorHomeScreenState();
}

class _AdvisorHomeScreenState extends State<AdvisorHomeScreen> {
  AdvisorStats? _advisorStats;
  List<TradeCardModel> _activeTrades = [];
  List<TradeCardModel> _closedTrades = [];
  Map<String, double> _livePrices = {};
  Map<String, Stock> _stockDataMap = {};
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription? _priceSubscription;
  final _apiService = ApiService();
  RealtimeChannel? _tradesChannel;
  String? _advisorId;

  @override
  void initState() {
    super.initState();
    _initializeAdvisorData();
    _listenToPriceStream();
  }

  @override
  void didUpdateWidget(covariant AdvisorHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.priceStream != oldWidget.priceStream) {
      _listenToPriceStream();
    }
  }

  void _listenToPriceStream() {
    _priceSubscription?.cancel();
    _priceSubscription = widget.priceStream?.listen((priceData) {
      final symbol = priceData['symbol'] as String?;
      final ltp = (priceData['ltp'] as num?)?.toDouble();

      if (symbol != null && ltp != null && mounted) {
        if (_livePrices[symbol] != ltp) {
          setState(() {
            _livePrices[symbol] = ltp;
          });
        }
      }
    });
  }

  Future<void> _initializeAdvisorData() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      _handleError('User not authenticated');
      return;
    }

    _advisorId = currentUser.id;
    await _fetchAdvisorData();
    _setupRealtimeSubscription();
  }

  // Function to fetch both stats and trades
  Future<void> _fetchAdvisorData() async {
    if (_advisorId == null) return;

    try {
      setState(() {
        _errorMessage = null;
        if (_advisorStats == null) {
          _isLoading = true;
        }
      });

      // Fetch stats and trades concurrently
      final responses = await Future.wait([
        Supabase.instance.client
            .from('advisor_statistics')
            .select()
            .eq('advisor_id', _advisorId!)
            .maybeSingle(),
        Supabase.instance.client
            .from('trade_cards')
            .select()
            .eq('advisor_id', _advisorId!)
            .order('created_at', ascending: false),
      ]);

      if (!mounted) return;

      // Process statistics response
      final statsResponse = responses[0] as Map<String, dynamic>?;
      final fetchedStats =
          statsResponse != null
              ? AdvisorStats.fromJson(statsResponse)
              : AdvisorStats.empty();

      // Process trades response
      final tradesResponse = responses[1] as List<dynamic>;
      final allCards =
          tradesResponse
              .map((e) => TradeCardModel.fromJson(e as Map<String, dynamic>))
              .toList();

      final activeTrades_ = allCards.where((c) => c.status == 'open').toList();

      final Map<String, Stock> fetchedStockData = {};
      final Set<String> symbols =
          activeTrades_.map((c) => c.stockSymbol).toSet();

      final List<Future<void>> stockFutures = [];
      for (var symbol in symbols) {
        stockFutures.add(
          _apiService
              .getStockData(symbol)
              .then((stockJson) {
                if (stockJson != null && mounted) {
                  fetchedStockData[symbol] = Stock.fromJson(symbol, stockJson);
                }
              })
              .catchError((e) {
                debugPrint("Failed to fetch stock data for $symbol: $e");
              }),
        );
      }
      await Future.wait(stockFutures);

      setState(() {
        _advisorStats = fetchedStats;
        _activeTrades = activeTrades_;
        _closedTrades = allCards.where((c) => c.status != 'open').toList();
        _stockDataMap = fetchedStockData;
        _isLoading = false;
        _errorMessage = null;
      });

      final Set<String> activeSymbols =
          activeTrades_.map((c) => c.stockSymbol).toSet();
      if (activeSymbols.isNotEmpty) {
        debugPrint(
          "[Home] Subscribing to ${activeSymbols.length} active symbols...",
        );
        widget.onSubscribe(activeSymbols.toList());

        // Might be obsolete idk
        for (var symbol in activeSymbols) {
          _apiService.subscribeToInstrument(symbol).catchError((e) {
            debugPrint("[Home] Error subscribing to $symbol: $e");
          });
        }
      }
    } catch (e) {
      _handleError('Error fetching advisor data: $e');
    }
  }

  void _setupRealtimeSubscription() {
    if (_advisorId == null) return;

    try {
      _tradesChannel =
          Supabase.instance.client
              .channel('public:trade_cards:advisor=$_advisorId:home')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'trade_cards',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'advisor_id',
                  value: _advisorId,
                ),
                callback: (payload) {
                  debugPrint('Realtime change received: ${payload.toString()}');
                  if (mounted) {
                    _fetchAdvisorData();
                  }
                },
              )
              .subscribe();
    } catch (e) {
      debugPrint('Error setting up realtime subscription: $e');
    }
  }

  @override
  void dispose() {
    _priceSubscription?.cancel();
    _cleanupRealtimeSubscription();
    super.dispose();
  }

  void _cleanupRealtimeSubscription() {
    if (_tradesChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_tradesChannel!);
      } catch (e) {
        debugPrint('Error removing realtime channel: $e');
      }
    }
  }

  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _refresh() async {
    await _fetchAdvisorData();
  }

  Future<void> _handleManualClose(
    String tradeId,
    String newStatus,
    double closingPrice,
  ) async {
    try {
      // Show a loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await Supabase.instance.client
          .from('trade_cards')
          .update({
            'status': newStatus,
            'closed_at': 'now()',
            'last_price': closingPrice,
            'manual_exit_price': closingPrice,
          })
          .eq('id', tradeId);

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trade manually closed successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      _fetchAdvisorData();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to close trade: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  //The handler function to update SL/TGT in Supabase
  Future<void> _handleModifyTrade(
    String tradeId,
    double newStopLoss,
    double newTarget,
  ) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      await Supabase.instance.client
          .from('trade_cards')
          .update({'stop_loss': newStopLoss, 'target': newTarget})
          .eq('id', tradeId);

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trade modified successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      _fetchAdvisorData();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to modify trade: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(onRefresh: _refresh, child: _buildContent());
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _advisorStats == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAdvisorData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildStatsGrid(),
        const SizedBox(height: 24),
        _buildSectionHeader('Active Trades', widget.onViewActive),
        _buildTradeList(_activeTrades, true),
        const SizedBox(height: 24),
        _buildSectionHeader('Closed Trades', widget.onViewClosed),
        _buildTradeList(_closedTrades, false),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final theme = Theme.of(context);
    final stats = _advisorStats!;
    return GridView.extent(
      maxCrossAxisExtent: 180.0,
      // Each item will have a maximum width of 180 pixels.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        StatCard(
          icon: Icons.people_outline,
          label: 'Followers',
          value: stats.followerCount.toString(),
          color: theme.colorScheme.primary, // Use AppThemes.primary
        ),
        StatCard(
          icon: Icons.check_circle_outline,
          label: 'Hit Rate',
          value: '${stats.hitRate.toStringAsFixed(1)}%',
          color: theme.colorScheme.secondary, // Use AppThemes.secondary (green)
        ),
        StatCard(
          icon: Icons.bar_chart,
          label: 'Profitable Trades',
          value: stats.profitableTrades.toString(),
          color: theme.colorScheme.tertiary, // Use AppThemes.tertiary (amber)
        ),
        StatCard(
          icon: Icons.history,
          label: 'Total Closed',
          value: stats.totalClosedTrades.toString(),
          color: theme.hintColor, // Use a neutral theme color
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onViewMore) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        TextButton(onPressed: onViewMore, child: const Text('View More')),
      ],
    );
  }

  Widget _buildTradeList(List<TradeCardModel> trades, bool isActive) {
    if (trades.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Center(
          child: Column(
            children: [
              Icon(
                isActive ? Icons.trending_up : Icons.history,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 8),
              Text(
                'No ${isActive ? 'active' : 'closed'} trades found.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final displayTrades = trades.take(3).toList();
    return Column(
      children:
          displayTrades.asMap().entries.map((entry) {
            final trade = entry.value;

            Widget tradeCard;
            if (isActive) {
              final prevClose = trade.lastPrice;
              final stockData = _stockDataMap[trade.stockSymbol];

              final livePrice =
                  _livePrices[trade.stockSymbol] ??
                  stockData?.ltp ??
                  prevClose; // Fallback

              final viewModel = ActiveTradeCardViewModel(
                trade: trade,
                currentPrice: livePrice,
              );
              tradeCard = ActiveTradeCardWidget(
                trade: viewModel,
                onManualClose: _handleManualClose,
                onModifyTrade: _handleModifyTrade,
                apiService: _apiService,
              );
            } else {
              final viewModel = ClosedTradeCardViewModel(trade: trade);
              tradeCard = ClosedTradeCardWidget(trade: viewModel);
            }

            return Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TradeCardHeader(
                    direction: trade.tradeDirection,
                    category: trade.tradeCategory,
                    segment: trade.tradeSegment,
                  ),
                  const SizedBox(height: 8),
                  tradeCard,
                ],
              ),
            );
          }).toList(),
    );
  }
}
