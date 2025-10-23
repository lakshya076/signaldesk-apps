import 'package:flutter/material.dart';
import 'dart:collection'; // For UnmodifiableSetView

class AdvisorFilterProvider extends ChangeNotifier {
  // Private state
  final Set<String> _selectedAdvisorIds = {};

  // Public getter that returns an unmodifiable view
  UnmodifiableSetView<String> get selectedAdvisorIds =>
      UnmodifiableSetView(_selectedAdvisorIds);

  // Method to add/remove an advisor
  void toggleAdvisor(String advisorId) {
    if (_selectedAdvisorIds.contains(advisorId)) {
      _selectedAdvisorIds.remove(advisorId);
    } else {
      _selectedAdvisorIds.add(advisorId);
    }
    notifyListeners();
  }

  // Method to clear all filters
  void clearFilter() {
    _selectedAdvisorIds.clear();
    notifyListeners();
  }
}
