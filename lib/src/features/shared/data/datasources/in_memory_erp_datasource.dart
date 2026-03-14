class InMemoryErpDataSource {
  final Map<String, Map<String, dynamic>> products = {};
  final Map<String, Map<String, dynamic>> orders = {};
  final Set<String> brands = <String>{};

  /// maps origin name → optional icon URL
  final Map<String, String?> origins = <String, String?>{};
}
