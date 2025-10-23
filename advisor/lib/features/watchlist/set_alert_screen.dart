import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signaldesk_advisor/models/stock.dart';

class SetAlertScreen extends StatefulWidget {
  final Stock stock;
  final bool isPositive;

  const SetAlertScreen({
    super.key,
    required this.isPositive,
    required this.stock,
  });

  @override
  State<SetAlertScreen> createState() => _SetAlertScreenState();
}

class _SetAlertScreenState extends State<SetAlertScreen> {
  final _formKey = GlobalKey<FormState>();
  final _targetPriceController = TextEditingController();
  String _notifyMeOption = 'Every time';
  bool _isSaving = false;

  Future<void> _setAlert() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final advisorId = Supabase.instance.client.auth.currentUser!.id;
      final targetPrice = double.parse(_targetPriceController.text);

      final alertData = {
        'advisor_id': advisorId,
        'stock_symbol': widget.stock.symbol,
        'target_price': targetPrice,
        'notify_frequency': _notifyMeOption,
      };

      await Supabase.instance.client.from('alerts').insert(alertData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert has been created successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set alert: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _targetPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
    widget.isPositive
        ? theme.colorScheme.secondary
        : theme.colorScheme.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Set Alert')),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.stock.symbol,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.stock.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.hintColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '₹${widget.stock.lastPrice.toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildRow(
                'Target Price',
                SizedBox(
                  width: 150,
                  child: TextFormField(
                    controller: _targetPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.end,
                    // Align text to the right for prices
                    decoration: const InputDecoration(hintText: 'Enter price'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildRow(
                'Notify Me',
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(child: _buildNotifyButton('Every time')),
                    const SizedBox(width: 8),
                    Expanded(child: _buildNotifyButton('Once')),
                  ],
                ),
              ),
              const Spacer(),
              // Spacer works fine here because the parent Column fills the Scaffold body
              ElevatedButton(
                onPressed: _setAlert,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child:
                _isSaving
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text('Set Alert'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // THIS IS THE CORRECTED METHOD
  Widget _buildRow(String label, Widget control) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 16),
        // This Expanded widget solves the layout error
        Expanded(child: control),
      ],
    );
  }

  Widget _buildNotifyButton(String option) {
    final theme = Theme.of(context);
    final isSelected = _notifyMeOption == option;
    return ElevatedButton(
      onPressed: () => setState(() => _notifyMeOption = option),
      style: ElevatedButton.styleFrom(
        backgroundColor:
        isSelected
            ? theme.colorScheme.primary
            : theme.inputDecorationTheme.fillColor,
        foregroundColor:
        isSelected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Text(option),
    );
  }
}

