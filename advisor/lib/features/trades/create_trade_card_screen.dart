import 'dart:async';
import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:signaldesk_advisor/features/dashboard/advisor_main_screen.dart';
import 'package:signaldesk_advisor/features/watchlist/search_screen.dart';
import 'package:signaldesk_advisor/models/stock.dart';
import 'package:signaldesk_advisor/services/api_service.dart';


class CreateTradeCardScreen extends StatefulWidget {
  final Stock? preselectedStock;

  const CreateTradeCardScreen({super.key, this.preselectedStock});

  @override
  _CreateTradeCardScreenState createState() => _CreateTradeCardScreenState();
}

class _CreateTradeCardScreenState extends State<CreateTradeCardScreen> {
  final _slideActionKey = GlobalKey<SlideActionState>();
  final _formKey = GlobalKey<FormState>();
  final _stockSymbolController = TextEditingController();
  final _livePriceController = TextEditingController();
  final _lastPriceController = TextEditingController();
  final _stopLossController = TextEditingController();
  final _targetController = TextEditingController();
  final _entryZoneController = TextEditingController();
  final _exitZoneController = TextEditingController();

  String _tradeDirection = 'Buy';
  Stock? _selectedStock;
  bool _isLoading = false;
  bool _isLoadingPrice = false;
  Timer? _priceTimer;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    if (widget.preselectedStock != null) {
      _setSelectedStock(widget.preselectedStock!);
    }
    _targetController.addListener(_updateExitZone);
  }

  // NEW: Method to fetch both live price AND prev_close from Redis
  Future<void> _fetchLivePrice() async {
    if (_selectedStock == null || !mounted) return;

    try {
      // Fetch complete stock data including ltp and prev_close
      final stockData = await _apiService.getStockData(_selectedStock!.symbol);

      if (mounted && stockData != null) {
        setState(() {
          // Update live price (LTP)
          if (stockData['ltp'] != null) {
            final livePrice = (stockData['ltp'] as num).toDouble();
            _livePriceController.text = livePrice.toStringAsFixed(2);

            // Update entry zone based on new live price
            final entryZoneStart = (livePrice * 0.99).toStringAsFixed(2);
            final entryZoneEnd = (livePrice * 1.01).toStringAsFixed(2);
            _entryZoneController.text = '$entryZoneStart - $entryZoneEnd';
          }

          // NEW: Update prev_close (Last Close) from Redis data
          if (stockData['prev_close'] != null) {
            final prevClose = (stockData['prev_close'] as num).toDouble();
            _lastPriceController.text = prevClose.toStringAsFixed(2);
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching live price: $e");
    }
  }

  void _startPriceTimer() {
    _priceTimer?.cancel();
    _priceTimer = Timer.periodic(
      const Duration(seconds: 5),
          (_) => _fetchLivePrice(),
    );
    // Fetch immediately
    _fetchLivePrice();
  }

  Future<void> _setSelectedStock(Stock stock) async {
    setState(() {
      _isLoadingPrice = true;
      _selectedStock = stock;
      _stockSymbolController.text = stock.symbol;

      // Initial values from the Stock object
      final livePrice = stock.entryPrice;
      _livePriceController.text = livePrice.toStringAsFixed(2);
      _lastPriceController.text = stock.lastPrice.toStringAsFixed(2);

      final entryZoneStart = (livePrice * 0.99).toStringAsFixed(2);
      final entryZoneEnd = (livePrice * 1.01).toStringAsFixed(2);
      _entryZoneController.text = '$entryZoneStart - $entryZoneEnd';

      _targetController.clear();
      _exitZoneController.clear();
    });

    try {
      await _apiService.subscribeToInstrument(stock.symbol);
      debugPrint('✓ Subscribed to ${stock.symbol} for live updates');

      // Wait a bit for subscription to be processed
      await Future.delayed(const Duration(milliseconds: 1500));

      // Start fetching live prices (which now includes prev_close)
      _startPriceTimer();
    } catch (e) {
      debugPrint('Error subscribing to ${stock.symbol}: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingPrice = false);
      }
    }
  }

  void _updateExitZone() {
    final targetPrice = double.tryParse(_targetController.text);
    if (targetPrice != null) {
      final exitZoneStart = (targetPrice * 0.99).toStringAsFixed(2);
      final exitZoneEnd = (targetPrice * 1.01).toStringAsFixed(2);
      _exitZoneController.text = '$exitZoneStart - $exitZoneEnd';
    }
  }

  Future<void> _searchAndSelectStock() async {
    final selectedStock = await showModalBottomSheet<Stock>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      routeSettings: const RouteSettings(name: 'create_trade_search'),
      builder: (context) => const SearchScreen(),
    );
    if (selectedStock != null) _setSelectedStock(selectedStock);
  }

  Future<void> _createTrade() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final tradeData = {
        "stock_symbol": _selectedStock!.symbol,
        "stop_loss": double.parse(_stopLossController.text),
        "target": double.parse(_targetController.text),
        "trade_direction": _tradeDirection,
        "trade_category": "Swing",
        "trade_segment": "Equity",
        "entry_zone": _entryZoneController.text,
        "exit_zone": _exitZoneController.text,
      };

      await _apiService.createTrade(tradeData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trade card created successfully with live prices!'),
          ),
        );
        context
            .findAncestorStateOfType<AdvisorMainScreenState>()
            ?.onItemTapped(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _priceTimer?.cancel();
    _targetController.removeListener(_updateExitZone);
    _stockSymbolController.dispose();
    _livePriceController.dispose();
    _lastPriceController.dispose();
    _stopLossController.dispose();
    _targetController.dispose();
    _entryZoneController.dispose();
    _exitZoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildLabel('Stock Name'),
            InkWell(
              onTap: _searchAndSelectStock,
              child: AbsorbPointer(
                child: TextFormField(
                  controller: _stockSymbolController,
                  decoration: InputDecoration(
                    hintText: 'Search Stock',
                    suffixIcon:
                    _isLoadingPrice
                        ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    )
                        : const Icon(Icons.search),
                  ),
                  validator:
                      (value) =>
                  (value == null || value.isEmpty)
                      ? 'Please select a stock'
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _livePriceController,
                    decoration: InputDecoration(
                      labelText: 'Live Price',
                      prefixIcon:
                      _isLoadingPrice
                          ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      )
                          : null,
                    ),
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _lastPriceController,
                    decoration: const InputDecoration(labelText: 'Last Close'),
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildLabel('Trade Direction'),
            Row(
              children: [
                Expanded(child: _buildDirectionButton('Buy')),
                Expanded(child: _buildDirectionButton('Sell')),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildLabel(
                    'Stop Loss (${_tradeDirection == 'Buy' ? 'Sell' : 'Buy'})',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildLabel(
                    'Target (${_tradeDirection == 'Buy' ? 'Sell' : 'Buy'})',
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stopLossController,
                    decoration: const InputDecoration(
                      hintText: 'Enter Stop Loss',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      final sl = double.tryParse(value);
                      final livePrice = double.tryParse(
                        _livePriceController.text,
                      );
                      if (sl == null || livePrice == null) {
                        return 'Invalid number';
                      }
                      if (_tradeDirection == 'Buy' && sl >= livePrice) {
                        return 'SL must be below price';
                      }
                      if (_tradeDirection == 'Sell' && sl <= livePrice) {
                        return 'SL must be above price';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _targetController,
                    decoration: const InputDecoration(hintText: 'Enter Target'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      final target = double.tryParse(value);
                      final livePrice = double.tryParse(
                        _livePriceController.text,
                      );
                      if (target == null || livePrice == null) {
                        return 'Invalid number';
                      }
                      if (_tradeDirection == 'Buy' && target <= livePrice) {
                        return 'Target must be above price';
                      }
                      if (_tradeDirection == 'Sell' && target >= livePrice) {
                        return 'Target must be below price';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildLabel('Trade Category')),
                const SizedBox(width: 16),
                Expanded(child: _buildLabel('Trade Segment')),
              ],
            ),
            Row(
              children: [
                Expanded(child: _buildDropdownPlaceholder('Swing')),
                const SizedBox(width: 16),
                Expanded(child: _buildDropdownPlaceholder('Equity')),
              ],
            ),
            const SizedBox(height: 24),
            _buildLabel('Zones (Optional)'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _entryZoneController,
                    decoration: const InputDecoration(labelText: 'Entry Zone'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _exitZoneController,
                    decoration: const InputDecoration(labelText: 'Exit Zone'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SlideAction(
              key: _slideActionKey,
              text: 'Swipe to Create Trade Idea',
              textStyle: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontSize: 16,
              ),
              outerColor: Theme.of(context).colorScheme.primary,
              innerColor: Theme.of(context).colorScheme.onPrimary,
              sliderButtonIcon: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.blue,
              ),
              onSubmit: () {
                if (_formKey.currentState!.validate()) {
                  _createTrade();
                } else {
                  _slideActionKey.currentState?.reset();
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(color: Theme.of(context).hintColor, fontSize: 14),
      ),
    );
  }

  Widget _buildDirectionButton(String direction) {
    final theme = Theme.of(context);
    final isSelected = _tradeDirection == direction;
    return ElevatedButton(
      onPressed: () => setState(() => _tradeDirection = direction),
      style: ElevatedButton.styleFrom(
        backgroundColor:
        isSelected
            ? theme.colorScheme.primary
            : theme.inputDecorationTheme.fillColor,
        foregroundColor:
        isSelected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(direction),
    );
  }

  Widget _buildDropdownPlaceholder(String hint) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: theme.inputDecorationTheme.fillColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            hint,
            style: TextStyle(color: theme.textTheme.bodyMedium?.color),
          ),
          Icon(Icons.arrow_drop_down, color: theme.hintColor),
        ],
      ),
    );
  }
}
