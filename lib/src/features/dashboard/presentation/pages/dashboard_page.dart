import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

import '../../../order/domain/entities/order.dart';
import '../../../order/domain/entities/order_item.dart';
import '../../../order/domain/entities/order_origin.dart';
import '../../../order/presentation/controllers/order_controller.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/domain/entities/product_cost.dart';
import '../../../product/presentation/controllers/product_controller.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.productController,
    required this.orderController,
    required this.usingFirebase,
  });

  final ProductController productController;
  final OrderController orderController;
  final bool usingFirebase;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const String _allBrandsLabel = 'Todas as marcas';
  static const String _allOriginsLabel = 'Todas as origens';
  static const int _productsPageSize = 60;
  static const int _ordersPageSize = 60;

  int _selectedIndex = 1;
  List<Product> _products = const [];
  List<Order> _orders = const [];
  bool _loadingProducts = true;
  bool _loadingOrders = true;
  bool _loadingMoreProducts = false;
  bool _loadingMoreOrders = false;
  String? _nextProductCursor;
  String? _nextOrderCursor;
  bool _hasMoreProducts = true;
  bool _hasMoreOrders = true;
  bool _editModeEnabled = false;
  bool _showAdvancedProductFilters = false;
  bool _showAdvancedOrderFilters = false;
  String _searchQuery = '';
  String _selectedBrandFilter = _allBrandsLabel;
  _ExpirationFilter _expirationFilter = _ExpirationFilter.all;
  _ProductSortOrder _sortOrder = _ProductSortOrder.expiration;
  bool _sortAscending = true;
  bool _showOutOfStockProducts = false;
  String _orderSearchQuery = '';
  String _selectedOriginFilter = _allOriginsLabel;

  @override
  void initState() {
    super.initState();
    _reloadData();
  }

  Future<void> _reloadData() async {
    await Future.wait([_loadProducts(), _loadOrders()]);
  }

  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);
    final page = await widget.productController.listPage(
      limit: _productsPageSize,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _products = page.items;
      _nextProductCursor = page.nextCursor;
      _hasMoreProducts = page.nextCursor != null;
      _loadingProducts = false;
      _loadingMoreProducts = false;
      final brands = _availableBrands;
      if (_selectedBrandFilter != _allBrandsLabel &&
          !brands.contains(_selectedBrandFilter)) {
        _selectedBrandFilter = _allBrandsLabel;
      }
    });
  }

  Future<void> _loadOrders() async {
    setState(() => _loadingOrders = true);
    final page = await widget.orderController.listPage(limit: _ordersPageSize);
    if (!mounted) {
      return;
    }
    setState(() {
      _orders = page.items;
      _nextOrderCursor = page.nextCursor;
      _hasMoreOrders = page.nextCursor != null;
      _loadingOrders = false;
      _loadingMoreOrders = false;
      final origins = _availableOrigins;
      if (_selectedOriginFilter != _allOriginsLabel &&
          !origins.contains(_selectedOriginFilter)) {
        _selectedOriginFilter = _allOriginsLabel;
      }
    });
  }

  Future<void> _loadMoreProducts() async {
    if (_loadingMoreProducts ||
        !_hasMoreProducts ||
        _nextProductCursor == null) {
      return;
    }

    setState(() => _loadingMoreProducts = true);
    try {
      final page = await widget.productController.listPage(
        limit: _productsPageSize,
        afterSku: _nextProductCursor,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final existingSkus = _products.map((p) => p.sku).toSet();
        final newItems = page.items
            .where((product) => !existingSkus.contains(product.sku))
            .toList(growable: false);
        _products = [..._products, ...newItems];
        _nextProductCursor = page.nextCursor;
        _hasMoreProducts = page.nextCursor != null;

        final brands = _availableBrands;
        if (_selectedBrandFilter != _allBrandsLabel &&
            !brands.contains(_selectedBrandFilter)) {
          _selectedBrandFilter = _allBrandsLabel;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _loadingMoreProducts = false);
      }
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_loadingMoreOrders || !_hasMoreOrders || _nextOrderCursor == null) {
      return;
    }

    setState(() => _loadingMoreOrders = true);
    try {
      final page = await widget.orderController.listPage(
        limit: _ordersPageSize,
        afterCursor: _nextOrderCursor,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final existingIds = _orders.map((o) => o.id).toSet();
        final newItems = page.items
            .where((order) => !existingIds.contains(order.id))
            .toList(growable: false);
        _orders = [..._orders, ...newItems]
          ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
        _nextOrderCursor = page.nextCursor;
        _hasMoreOrders = page.nextCursor != null;

        final origins = _availableOrigins;
        if (_selectedOriginFilter != _allOriginsLabel &&
            !origins.contains(_selectedOriginFilter)) {
          _selectedOriginFilter = _allOriginsLabel;
        }
      });
    } finally {
      if (mounted) {
        setState(() => _loadingMoreOrders = false);
      }
    }
  }

  Future<void> _onAddActionPressed() async {
    if (_selectedIndex == 0) {
      await _showCreateProductDialog();
      return;
    }
    await _showCreateOrderDialog();
  }

  void _upsertProductInState(Product product) {
    final existingIndex = _products.indexWhere((p) => p.sku == product.sku);
    if (existingIndex < 0) {
      setState(() {
        _products = [..._products, product];
      });
      return;
    }

    final updated = [..._products];
    updated[existingIndex] = product;
    setState(() {
      _products = updated;
    });
  }

  Future<Product?> _showCreateProductDialog() async {
    final brands = await widget.productController.listBrands();
    if (!mounted) {
      return null;
    }
    final formData = await showDialog<_ProductFormData>(
      context: context,
      builder: (context) => _CreateProductDialog(brands: brands),
    );

    if (formData == null) {
      return null;
    }

    final sku = await _generateUniqueSku(formData.description);

    final product = Product(
      sku: sku,
      description: formData.description,
      imageUrl: formData.imageUrl,
      stock: formData.stock,
      brand: formData.brand,
      costHistory: const [],
      expirationDate: formData.stock <= 0 ? null : formData.expirationDate,
    );

    await widget.productController.create(product);
    if (!mounted) {
      return product;
    }
    _upsertProductInState(product);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Produto adicionado com sucesso.')),
    );
    return product;
  }

  Future<void> _showManualStockUpdateDialog(Product product) async {
    final newStock = await showDialog<int>(
      context: context,
      builder: (context) => _UpdateStockDialog(product: product),
    );

    if (newStock == null) {
      return;
    }

    final shouldClearExpiration =
        newStock <= 0 && product.expirationDate != null;
    if (shouldClearExpiration) {
      final updated = product.copyWith(stock: newStock, expirationDate: null);
      await widget.productController.create(updated);
      if (!mounted) {
        return;
      }
      _upsertProductInState(updated);
    } else {
      await widget.productController.updateStock(
        sku: product.sku,
        newStock: newStock,
      );
      if (!mounted) {
        return;
      }
      _upsertProductInState(product.copyWith(stock: newStock));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Estoque atualizado com sucesso.')),
    );
  }

  Future<void> _showManualExpirationUpdateDialog(Product product) async {
    final newDate = await showDialog<DateTime>(
      context: context,
      builder: (context) => _UpdateExpirationDialog(product: product),
    );

    if (newDate == null) {
      return;
    }

    await widget.productController.updateExpirationDate(
      sku: product.sku,
      newExpirationDate: newDate,
    );

    if (!mounted) {
      return;
    }
    _upsertProductInState(product.copyWith(expirationDate: newDate));

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Validade atualizada com sucesso.')),
    );
  }

  Future<void> _showEditProductDialog(Product product) async {
    final brands = await widget.productController.listBrands();
    if (!mounted) {
      return;
    }

    final formData = await showDialog<_ProductFormData>(
      context: context,
      builder: (context) => _CreateProductDialog(
        brands: brands,
        initialProduct: product,
        isEditing: true,
      ),
    );

    if (formData == null) {
      return;
    }

    final updated = product.copyWith(
      description: formData.description,
      imageUrl: formData.imageUrl,
      stock: formData.stock,
      brand: formData.brand,
      expirationDate: formData.stock <= 0 ? null : formData.expirationDate,
    );

    await widget.productController.create(updated);

    if (!mounted) {
      return;
    }
    _upsertProductInState(updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Produto atualizado com sucesso.')),
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: _dialogInsetPadding(context),
        title: const Text('Excluir produto'),
        content: Text('Deseja excluir o produto ${product.description}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await widget.productController.delete(product.sku);

    if (!mounted) {
      return;
    }
    setState(() {
      _products = _products
          .where((p) => p.sku != product.sku)
          .toList(growable: false);

      final brands = _availableBrands;
      if (_selectedBrandFilter != _allBrandsLabel &&
          !brands.contains(_selectedBrandFilter)) {
        _selectedBrandFilter = _allBrandsLabel;
      }
    });

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Produto excluido com sucesso.')),
    );
  }

  Future<void> _showEditOrderDialog(Order order) async {
    final origins = await widget.orderController.listOrigins();
    if (!mounted) {
      return;
    }

    final formData = await showDialog<_OrderFormData>(
      context: context,
      builder: (context) => _CreateOrderDialog(
        products: _products,
        origins: origins,
        initialOrder: order,
        isEditing: true,
        onAddProductRequested: _showCreateProductDialog,
      ),
    );

    if (formData == null) {
      return;
    }

    final updatedOrder = Order(
      id: order.id,
      origin: formData.origin,
      originIconUrl: formData.originIconUrl,
      registeredAt: order.registeredAt,
      items: formData.items
          .map(
            (item) => OrderItem(
              productSku: item.productSku,
              quantity: item.quantity,
              costPerItem: item.costPerItem,
              expirationDate: item.expirationDate,
            ),
          )
          .toList(growable: false),
    );

    await widget.orderController.create(updatedOrder);

    if (!mounted) {
      return;
    }
    setState(() {
      final index = _orders.indexWhere((o) => o.id == updatedOrder.id);
      if (index < 0) {
        _orders = [..._orders, updatedOrder]
          ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
      } else {
        final updated = [..._orders];
        updated[index] = updatedOrder;
        updated.sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
        _orders = updated;
      }
    });

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pedido atualizado com sucesso.')),
    );
  }

  Future<void> _deleteOrder(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: _dialogInsetPadding(context),
        title: const Text('Excluir pedido'),
        content: Text('Deseja excluir o pedido ${order.id}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await widget.orderController.delete(order.id);

    if (!mounted) {
      return;
    }
    setState(() {
      _orders = _orders.where((o) => o.id != order.id).toList(growable: false);

      final origins = _availableOrigins;
      if (_selectedOriginFilter != _allOriginsLabel &&
          !origins.contains(_selectedOriginFilter)) {
        _selectedOriginFilter = _allOriginsLabel;
      }
    });

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pedido excluido com sucesso.')),
    );
  }

  Future<void> _showCreateOrderDialog() async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cadastre um produto antes de criar pedido.'),
        ),
      );
      return;
    }

    final origins = await widget.orderController.listOrigins();
    if (!mounted) {
      return;
    }

    final formData = await showDialog<_OrderFormData>(
      context: context,
      builder: (context) => _CreateOrderDialog(
        products: _products,
        origins: origins,
        onAddProductRequested: _showCreateProductDialog,
      ),
    );

    if (formData == null) {
      return;
    }

    final orderId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();
    final order = Order(
      id: orderId,
      origin: formData.origin,
      originIconUrl: formData.originIconUrl,
      registeredAt: now,
      items: formData.items
          .map(
            (item) => OrderItem(
              productSku: item.productSku,
              quantity: item.quantity,
              costPerItem: item.costPerItem,
              expirationDate: item.expirationDate,
            ),
          )
          .toList(growable: false),
    );

    await widget.orderController.create(order);

    final productsBySku = <String, Product>{
      for (final product in _products) product.sku: product,
    };
    final quantityBySku = <String, int>{};
    final minExpirationBySku = <String, DateTime>{};
    final costsBySku = <String, List<ProductCost>>{};
    for (final item in formData.items) {
      quantityBySku[item.productSku] =
          (quantityBySku[item.productSku] ?? 0) + item.quantity;

      final currentMin = minExpirationBySku[item.productSku];
      if (currentMin == null || item.expirationDate.isBefore(currentMin)) {
        minExpirationBySku[item.productSku] = item.expirationDate;
      }

      costsBySku
          .putIfAbsent(item.productSku, () => <ProductCost>[])
          .add(
            ProductCost(
              orderId: orderId,
              value: item.costPerItem,
              registeredAt: now,
              origin: formData.origin,
            ),
          );
    }

    final productUpdateFutures = <Future<void>>[];
    final updatedProductsBySku = <String, Product>{};
    for (final entry in quantityBySku.entries) {
      final currentProduct = productsBySku[entry.key];
      if (currentProduct == null) {
        continue;
      }

      final nearestExpiration = minExpirationBySku[currentProduct.sku];
      final currentExpiration = currentProduct.expirationDate;
      final wasOutOfStock = currentProduct.stock <= 0;
      final newExpirationDate = switch ((
        currentExpiration,
        nearestExpiration,
      )) {
        (_, final DateTime nearest) when wasOutOfStock => nearest,
        (null, final DateTime nearest) => nearest,
        (final DateTime current, final DateTime nearest) =>
          nearest.isBefore(current) ? nearest : current,
        _ => currentExpiration,
      };

      final updatedProduct = currentProduct.copyWith(
        stock: currentProduct.stock + entry.value,
        expirationDate: newExpirationDate,
        costHistory: [
          ...currentProduct.costHistory,
          ...?costsBySku[currentProduct.sku],
        ],
      );
      updatedProductsBySku[currentProduct.sku] = updatedProduct;

      productUpdateFutures.add(widget.productController.create(updatedProduct));
    }

    await Future.wait(productUpdateFutures);

    if (!mounted) {
      return;
    }

    setState(() {
      _orders = [..._orders, order]
        ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
      _products = [
        for (final product in _products)
          updatedProductsBySku[product.sku] ?? product,
      ];

      final brands = _availableBrands;
      if (_selectedBrandFilter != _allBrandsLabel &&
          !brands.contains(_selectedBrandFilter)) {
        _selectedBrandFilter = _allBrandsLabel;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pedido adicionado com sucesso.')),
    );
  }

  Future<String> _generateUniqueSku(String description) async {
    final normalized = description.toUpperCase().replaceAll(
      RegExp(r'[^A-Z]'),
      '',
    );
    final prefix = (normalized.isEmpty ? 'PRODUT' : normalized)
        .padRight(6, 'X')
        .substring(0, 6);

    final random = Random();
    final existingSkus = _products.map((product) => product.sku).toSet();

    for (var attempt = 0; attempt < 10000; attempt++) {
      final timeSalt = DateTime.now().microsecondsSinceEpoch % 1000000;
      final randomSalt = random.nextInt(1000);
      final suffix = ((timeSalt + randomSalt) % 1000000).toString().padLeft(
        6,
        '0',
      );
      final candidate = '$prefix$suffix';
      if (!existingSkus.contains(candidate)) {
        return candidate;
      }
    }

    throw StateError('Nao foi possivel gerar SKU unico para $prefix.');
  }

  List<String> get _availableBrands {
    final brands =
        _products
            .map((product) => product.brand.trim())
            .where((brand) => brand.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return brands;
  }

  List<Product> get _filteredProducts {
    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final now = DateTime.now();
    final warningDate = now.add(const Duration(days: 30));

    final filtered =
        _products
            .where((product) {
              final matchesBrand =
                  _selectedBrandFilter == _allBrandsLabel ||
                  product.brand == _selectedBrandFilter;

              final matchesQuery =
                  normalizedQuery.isEmpty ||
                  product.description.toLowerCase().contains(normalizedQuery) ||
                  product.sku.toLowerCase().contains(normalizedQuery);

              final matchesStockVisibility =
                  _showOutOfStockProducts || product.stock > 0;

              final expirationDate = product.expirationDate;
              final date = expirationDate == null
                  ? null
                  : DateTime(
                      expirationDate.year,
                      expirationDate.month,
                      expirationDate.day,
                    );
              final today = DateTime(now.year, now.month, now.day);
              final maxWarning = DateTime(
                warningDate.year,
                warningDate.month,
                warningDate.day,
              );

              final matchesExpiration = switch (_expirationFilter) {
                _ExpirationFilter.all => true,
                _ExpirationFilter.warning =>
                  date != null &&
                      (date.isAtSameMomentAs(today) ||
                          (date.isAfter(today) &&
                              (date.isAtSameMomentAs(maxWarning) ||
                                  date.isBefore(maxWarning)))),
                _ExpirationFilter.expired =>
                  date != null && date.isBefore(today),
              };

              return matchesBrand &&
                  matchesQuery &&
                  matchesStockVisibility &&
                  matchesExpiration;
            })
            .toList(growable: false)
          ..sort((a, b) {
            final aOutOfStock = a.stock <= 0;
            final bOutOfStock = b.stock <= 0;
            if (aOutOfStock != bOutOfStock) {
              return aOutOfStock ? 1 : -1;
            }

            final int cmp;
            switch (_sortOrder) {
              case _ProductSortOrder.alphabetical:
                cmp = a.description.toLowerCase().compareTo(
                  b.description.toLowerCase(),
                );
              case _ProductSortOrder.expiration:
                final aDate = a.expirationDate;
                final bDate = b.expirationDate;
                if (aDate == null && bDate == null) {
                  cmp = 0;
                } else if (aDate == null) {
                  cmp = 1;
                } else if (bDate == null) {
                  cmp = -1;
                } else {
                  cmp = aDate.compareTo(bDate);
                }
              case _ProductSortOrder.stock:
                cmp = a.stock.compareTo(b.stock);
            }
            return _sortAscending ? cmp : -cmp;
          });

    return filtered;
  }

  List<String> get _availableOrigins {
    final origins =
        _orders
            .map((order) => order.origin.trim())
            .where((origin) => origin.isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return origins;
  }

  bool get _hasActiveAdvancedProductFilters {
    return _selectedBrandFilter != _allBrandsLabel ||
        _expirationFilter != _ExpirationFilter.all ||
        _sortOrder != _ProductSortOrder.expiration ||
        !_sortAscending ||
        _showOutOfStockProducts;
  }

  int get _activeAdvancedProductFilterCount {
    var count = 0;
    if (_selectedBrandFilter != _allBrandsLabel) {
      count++;
    }
    if (_expirationFilter != _ExpirationFilter.all) {
      count++;
    }
    if (_sortOrder != _ProductSortOrder.expiration || !_sortAscending) {
      count++;
    }
    if (_showOutOfStockProducts) {
      count++;
    }
    return count;
  }

  void _clearAdvancedProductFilters() {
    setState(() {
      _selectedBrandFilter = _allBrandsLabel;
      _expirationFilter = _ExpirationFilter.all;
      _sortOrder = _ProductSortOrder.expiration;
      _sortAscending = true;
      _showOutOfStockProducts = false;
    });
  }

  bool get _hasActiveAdvancedOrderFilters {
    return _selectedOriginFilter != _allOriginsLabel;
  }

  int get _activeAdvancedOrderFilterCount {
    return _selectedOriginFilter != _allOriginsLabel ? 1 : 0;
  }

  void _clearAdvancedOrderFilters() {
    setState(() {
      _selectedOriginFilter = _allOriginsLabel;
    });
  }

  List<Order> get _filteredOrders {
    final normalizedQuery = _orderSearchQuery.trim().toLowerCase();

    final filtered =
        _orders
            .where((order) {
              final matchesOrigin =
                  _selectedOriginFilter == _allOriginsLabel ||
                  order.origin == _selectedOriginFilter;

              if (!matchesOrigin) {
                return false;
              }

              if (normalizedQuery.isEmpty) {
                return true;
              }

              for (final item in order.items) {
                Product? matchedProduct;
                for (final product in _products) {
                  if (product.sku == item.productSku) {
                    matchedProduct = product;
                    break;
                  }
                }

                final skuMatch = item.productSku.toLowerCase().contains(
                  normalizedQuery,
                );
                final descriptionMatch =
                    matchedProduct?.description.toLowerCase().contains(
                      normalizedQuery,
                    ) ??
                    false;

                if (skuMatch || descriptionMatch) {
                  return true;
                }
              }

              return false;
            })
            .toList(growable: false)
          ..sort((a, b) => b.registeredAt.compareTo(a.registeredAt));

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isProductsTab = _selectedIndex == 0;
    final isOrdersTab = _selectedIndex == 2;
    final canToggleEditMode = isProductsTab || isOrdersTab;
    final editWarningColor = Colors.amber.shade700;
    final isEditHighlightVisible = _editModeEnabled && canToggleEditMode;
    final scheme = Theme.of(context).colorScheme;
    final appBackgroundColor = isEditHighlightVisible
        ? Color.alphaBlend(
            editWarningColor.withValues(alpha: 0.08),
            scheme.surface,
          )
        : null;
    final appBarBackgroundColor = isEditHighlightVisible
        ? Color.alphaBlend(
            editWarningColor.withValues(alpha: 0.14),
            scheme.surface,
          )
        : null;

    return Scaffold(
      backgroundColor: appBackgroundColor,
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor ?? Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              child: Image(
                image: AssetImage('assets/app_icon/simple-erp-icon.png'),
                width: 20,
                height: 20,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(width: 8),
            Text('Simple ERP'),
          ],
        ),
        actions: [
          if (canToggleEditMode)
            IconButton(
              onPressed: () {
                setState(() => _editModeEnabled = !_editModeEnabled);
              },
              icon: Icon(
                _editModeEnabled
                    ? Icons.edit_off_outlined
                    : Icons.edit_outlined,
                color: _editModeEnabled ? editWarningColor : null,
              ),
              tooltip: _editModeEnabled
                  ? 'Desativar modo edicao/exclusao'
                  : 'Ativar modo edicao/exclusao',
            ),
          IconButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Sair'),
                  content: const Text('Deseja encerrar a sessao?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Sair'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await FirebaseAuth.instance.signOut();
              }
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
          ),
        ],
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isEditHighlightVisible
              ? editWarningColor.withValues(alpha: 0.04)
              : Colors.transparent,
        ),
        child: Column(
          children: [
            if (isEditHighlightVisible)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  border: Border.all(color: editWarningColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Modo edicao/exclusao ativo: acoes de editar e excluir estao habilitadas.',
                      ),
                    ),
                  ],
                ),
              ),
            if (isProductsTab)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 860;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: TextField(
                                    scrollPadding: const EdgeInsets.fromLTRB(
                                      20,
                                      20,
                                      20,
                                      220,
                                    ),
                                    onChanged: (value) {
                                      setState(() => _searchQuery = value);
                                    },
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.search),
                                      hintText: 'Buscar por descricao ou SKU',
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                      suffixIcon: _searchQuery.isEmpty
                                          ? null
                                          : IconButton(
                                              tooltip: 'Limpar busca',
                                              onPressed: () {
                                                setState(
                                                  () => _searchQuery = '',
                                                );
                                              },
                                              icon: const Icon(Icons.close),
                                            ),
                                      filled: true,
                                      fillColor: Theme.of(
                                        context,
                                      ).colorScheme.surface,
                                      isDense: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outlineVariant,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        borderSide: BorderSide(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          width: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: _showAdvancedProductFilters
                                    ? 'Ocultar filtros'
                                    : 'Mostrar filtros',
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: Material(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surface,
                                        shape: CircleBorder(
                                          side: BorderSide(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.outlineVariant,
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: () {
                                            setState(() {
                                              _showAdvancedProductFilters =
                                                  !_showAdvancedProductFilters;
                                            });
                                          },
                                          child: Center(
                                            child: Icon(
                                              _showAdvancedProductFilters
                                                  ? Icons.expand_less
                                                  : Icons.tune,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_showAdvancedProductFilters) ...[
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.outline,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Exibir zerados',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelLarge,
                                    ),
                                  ),
                                  Transform.scale(
                                    scale: 0.85,
                                    child: Switch.adaptive(
                                      value: _showOutOfStockProducts,
                                      onChanged: (value) {
                                        setState(() {
                                          _showOutOfStockProducts = value;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (_hasActiveAdvancedProductFilters)
                              const SizedBox(height: 10),
                            if (isWide)
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: _buildBrandFilterField()),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildExpirationFilterField(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(child: _buildSortOrderField()),
                                      const SizedBox(width: 8),
                                      Tooltip(
                                        message: _sortAscending
                                            ? 'Ordem crescente'
                                            : 'Ordem decrescente',
                                        child: IconButton.outlined(
                                          onPressed: () => setState(
                                            () => _sortAscending =
                                                !_sortAscending,
                                          ),
                                          icon: Icon(
                                            _sortAscending
                                                ? Icons.arrow_upward
                                                : Icons.arrow_downward,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            else
                              Column(
                                children: [
                                  _buildBrandFilterField(),
                                  const SizedBox(height: 10),
                                  _buildExpirationFilterField(),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(child: _buildSortOrderField()),
                                      const SizedBox(width: 8),
                                      Tooltip(
                                        message: _sortAscending
                                            ? 'Ordem crescente'
                                            : 'Ordem decrescente',
                                        child: IconButton.outlined(
                                          onPressed: () => setState(
                                            () => _sortAscending =
                                                !_sortAscending,
                                          ),
                                          icon: Icon(
                                            _sortAscending
                                                ? Icons.arrow_upward
                                                : Icons.arrow_downward,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            if (_hasActiveAdvancedProductFilters) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _QuickStatChip(
                                        icon: Icons.filter_alt_outlined,
                                        label:
                                            '$_activeAdvancedProductFilterCount filtro(s) ativo(s)',
                                        minHeight: 40,
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        height: 40,
                                        child: OutlinedButton.icon(
                                          onPressed:
                                              _clearAdvancedProductFilters,
                                          icon: const Icon(
                                            Icons.clear,
                                            size: 16,
                                          ),
                                          label: const Text('Limpar filtros'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (isOrdersTab)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: TextField(
                                scrollPadding: const EdgeInsets.fromLTRB(
                                  20,
                                  20,
                                  20,
                                  220,
                                ),
                                onChanged: (value) {
                                  setState(() => _orderSearchQuery = value);
                                },
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.search),
                                  hintText:
                                      'Buscar pedidos por produto (descricao ou SKU)',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  suffixIcon: _orderSearchQuery.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Limpar busca',
                                          onPressed: () {
                                            setState(
                                              () => _orderSearchQuery = '',
                                            );
                                          },
                                          icon: const Icon(Icons.close),
                                        ),
                                  filled: true,
                                  fillColor: Theme.of(
                                    context,
                                  ).colorScheme.surface,
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.outlineVariant,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      width: 1.4,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: _showAdvancedOrderFilters
                                ? 'Ocultar filtros'
                                : 'Mostrar filtros',
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Material(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    shape: CircleBorder(
                                      side: BorderSide(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.outlineVariant,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () {
                                        setState(() {
                                          _showAdvancedOrderFilters =
                                              !_showAdvancedOrderFilters;
                                        });
                                      },
                                      child: Center(
                                        child: Icon(
                                          _showAdvancedOrderFilters
                                              ? Icons.expand_less
                                              : Icons.tune,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_showAdvancedOrderFilters) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedOriginFilter,
                          decoration: InputDecoration(
                            labelText: 'Filtrar por origem',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.4,
                              ),
                            ),
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.surface,
                          ),
                          items: [_allOriginsLabel, ..._availableOrigins]
                              .map(
                                (origin) => DropdownMenuItem<String>(
                                  value: origin,
                                  child: Text(origin),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => _selectedOriginFilter = value);
                          },
                        ),
                        if (_hasActiveAdvancedOrderFilters) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _QuickStatChip(
                                    icon: Icons.filter_alt_outlined,
                                    label:
                                        '$_activeAdvancedOrderFilterCount filtro(s) ativo(s)',
                                    minHeight: 40,
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 40,
                                    child: OutlinedButton.icon(
                                      onPressed: _clearAdvancedOrderFilters,
                                      icon: const Icon(Icons.clear, size: 16),
                                      label: const Text('Limpar filtros'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  _ProductsListTab(
                    products: _filteredProducts,
                    orders: _orders,
                    isLoading: _loadingProducts,
                    isLoadingMore: _loadingMoreProducts,
                    canLoadMore: _hasMoreProducts,
                    onLoadMore: _loadMoreProducts,
                    onUpdateStock: _showManualStockUpdateDialog,
                    onUpdateExpirationDate: _showManualExpirationUpdateDialog,
                    isEditModeEnabled: _editModeEnabled,
                    onEditProduct: _showEditProductDialog,
                    onDeleteProduct: _deleteProduct,
                    emptyMessage: _products.isEmpty
                        ? 'Use o botao de adicionar para incluir o primeiro produto.'
                        : 'Nenhum produto encontrado para os filtros aplicados.',
                  ),
                  const _PriceCalculatorTab(),
                  _OrdersListTab(
                    orders: _filteredOrders,
                    products: _products,
                    isLoading: _loadingOrders,
                    isLoadingMore: _loadingMoreOrders,
                    canLoadMore: _hasMoreOrders,
                    onLoadMore: _loadMoreOrders,
                    isEditModeEnabled: _editModeEnabled,
                    onEditOrder: _showEditOrderDialog,
                    onDeleteOrder: _deleteOrder,
                    emptyMessage: _orders.isEmpty
                        ? 'Use o botao de adicionar para registrar o primeiro pedido.'
                        : 'Nenhum pedido encontrado para os filtros aplicados.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isOrdersTab || isProductsTab
          ? FloatingActionButton(
              onPressed: _onAddActionPressed,
              tooltip: isProductsTab ? 'Adicionar produto' : 'Adicionar pedido',
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) {
          setState(() => _selectedIndex = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Produtos',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Preco',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pedidos',
          ),
        ],
      ),
    );
  }

  Widget _buildSortOrderField() {
    return DropdownButtonFormField<_ProductSortOrder>(
      initialValue: _sortOrder,
      decoration: const InputDecoration(
        labelText: 'Ordenar por',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(
          value: _ProductSortOrder.alphabetical,
          child: Text('Alfabético'),
        ),
        DropdownMenuItem(
          value: _ProductSortOrder.expiration,
          child: Text('Validade'),
        ),
        DropdownMenuItem(
          value: _ProductSortOrder.stock,
          child: Text('Estoque'),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() => _sortOrder = value);
      },
    );
  }

  Widget _buildBrandFilterField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedBrandFilter,
      decoration: const InputDecoration(
        labelText: 'Marca',
        border: OutlineInputBorder(),
      ),
      items: [_allBrandsLabel, ..._availableBrands]
          .map(
            (brand) =>
                DropdownMenuItem<String>(value: brand, child: Text(brand)),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value == null) {
          return;
        }
        setState(() => _selectedBrandFilter = value);
      },
    );
  }

  Widget _buildExpirationFilterField() {
    return DropdownButtonFormField<_ExpirationFilter>(
      initialValue: _expirationFilter,
      decoration: const InputDecoration(
        labelText: 'Validade',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: _ExpirationFilter.all, child: Text('Todas')),
        DropdownMenuItem(
          value: _ExpirationFilter.warning,
          child: Text('Vence em ate 30 dias'),
        ),
        DropdownMenuItem(
          value: _ExpirationFilter.expired,
          child: Text('Vencidos'),
        ),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }
        setState(() => _expirationFilter = value);
      },
    );
  }
}

class _ProductsListTab extends StatelessWidget {
  const _ProductsListTab({
    required this.products,
    required this.orders,
    required this.isLoading,
    required this.isLoadingMore,
    required this.canLoadMore,
    required this.onLoadMore,
    required this.onUpdateStock,
    required this.onUpdateExpirationDate,
    required this.isEditModeEnabled,
    required this.onEditProduct,
    required this.onDeleteProduct,
    required this.emptyMessage,
  });

  final List<Product> products;
  final List<Order> orders;
  final bool isLoading;
  final bool isLoadingMore;
  final bool canLoadMore;
  final Future<void> Function() onLoadMore;
  final Future<void> Function(Product product) onUpdateStock;
  final Future<void> Function(Product product) onUpdateExpirationDate;
  final bool isEditModeEnabled;
  final Future<void> Function(Product product) onEditProduct;
  final Future<void> Function(Product product) onDeleteProduct;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (products.isEmpty) {
      return _EmptyState(
        title: emptyMessage.startsWith('Use')
            ? 'Nenhum produto cadastrado'
            : 'Nenhum produto encontrado',
        subtitle: emptyMessage,
      );
    }

    final showFooter = isLoadingMore || canLoadMore;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: products.length + (showFooter ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        if (index == products.length) {
          return _LoadMoreFooter(
            isLoadingMore: isLoadingMore,
            canLoadMore: canLoadMore,
            onLoadMore: onLoadMore,
            label: 'Carregar mais produtos',
          );
        }

        final product = products[index];
        return _ProductCard(
          product: product,
          products: products,
          orders: orders,
          isEditModeEnabled: isEditModeEnabled,
          onUpdateStock: onUpdateStock,
          onUpdateExpirationDate: onUpdateExpirationDate,
          onEditProduct: onEditProduct,
          onDeleteProduct: onDeleteProduct,
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.products,
    required this.orders,
    required this.isEditModeEnabled,
    required this.onUpdateStock,
    required this.onUpdateExpirationDate,
    required this.onEditProduct,
    required this.onDeleteProduct,
  });

  final Product product;
  final List<Product> products;
  final List<Order> orders;
  final bool isEditModeEnabled;
  final Future<void> Function(Product product) onUpdateStock;
  final Future<void> Function(Product product) onUpdateExpirationDate;
  final Future<void> Function(Product product) onEditProduct;
  final Future<void> Function(Product product) onDeleteProduct;

  @override
  Widget build(BuildContext context) {
    final status = _expirationStatus(
      product.expirationDate,
      product.stock,
      context,
    );
    final scheme = Theme.of(context).colorScheme;
    final isOutOfStock = product.stock <= 0;

    final card = Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isOutOfStock ? scheme.surfaceContainerLow : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar colored by expiration status
            Container(
              width: 4,
              color: isOutOfStock ? scheme.outline : status.color,
            ),
            Expanded(
              child: InkWell(
                onTap: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => _ProductOrderHistoryDialog(
                      product: product,
                      products: products,
                      orders: orders,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 2, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _ProductImagePreview(imageUrl: product.imageUrl),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Product name — full row width, up to 2 lines
                            Text(
                              product.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 5),
                            // Secondary info: stock · days until expiration
                            Row(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 13,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${product.stock} un.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 1,
                                  height: 10,
                                  color: scheme.outlineVariant,
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.schedule_outlined,
                                  size: 13,
                                  color: status.color,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  status.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: status.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<_ProductAction>(
                        tooltip: 'Ações do produto',
                        onSelected: (action) {
                          if (action == _ProductAction.updateStock) {
                            onUpdateStock(product);
                            return;
                          }
                          if (action == _ProductAction.edit) {
                            onEditProduct(product);
                            return;
                          }
                          if (action == _ProductAction.delete) {
                            onDeleteProduct(product);
                            return;
                          }
                          onUpdateExpirationDate(product);
                        },
                        itemBuilder: (context) {
                          final items = <PopupMenuEntry<_ProductAction>>[
                            const PopupMenuItem<_ProductAction>(
                              value: _ProductAction.updateStock,
                              child: Row(
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 18),
                                  SizedBox(width: 12),
                                  Text('Atualizar estoque'),
                                ],
                              ),
                            ),
                            const PopupMenuItem<_ProductAction>(
                              value: _ProductAction.updateExpiration,
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_month_outlined, size: 18),
                                  SizedBox(width: 12),
                                  Text('Atualizar validade'),
                                ],
                              ),
                            ),
                          ];

                          if (isEditModeEnabled) {
                            items.add(const PopupMenuDivider());
                            items.add(
                              PopupMenuItem<_ProductAction>(
                                value: _ProductAction.edit,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: Colors.amber.shade700,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Editar produto',
                                      style: TextStyle(
                                        color: Colors.amber.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                            items.add(
                              PopupMenuItem<_ProductAction>(
                                value: _ProductAction.delete,
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.amber.shade700,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Excluir produto',
                                      style: TextStyle(
                                        color: Colors.amber.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return items;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!isOutOfStock) {
      return card;
    }

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: card,
    );
  }
}

class _OrdersListTab extends StatelessWidget {
  const _OrdersListTab({
    required this.orders,
    required this.products,
    required this.isLoading,
    required this.isLoadingMore,
    required this.canLoadMore,
    required this.onLoadMore,
    required this.isEditModeEnabled,
    required this.onEditOrder,
    required this.onDeleteOrder,
    required this.emptyMessage,
  });

  final List<Order> orders;
  final List<Product> products;
  final bool isLoading;
  final bool isLoadingMore;
  final bool canLoadMore;
  final Future<void> Function() onLoadMore;
  final bool isEditModeEnabled;
  final Future<void> Function(Order order) onEditOrder;
  final Future<void> Function(Order order) onDeleteOrder;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return _EmptyState(
        title: emptyMessage.startsWith('Use')
            ? 'Nenhum pedido cadastrado'
            : 'Nenhum pedido encontrado',
        subtitle: emptyMessage,
      );
    }

    final showFooter = isLoadingMore || canLoadMore;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: orders.length + (showFooter ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == orders.length) {
          return _LoadMoreFooter(
            isLoadingMore: isLoadingMore,
            canLoadMore: canLoadMore,
            onLoadMore: onLoadMore,
            label: 'Carregar mais pedidos',
          );
        }

        final order = orders[index];
        final totalItems = order.items.fold<int>(
          0,
          (sum, item) => sum + item.quantity,
        );
        final totalValue = order.items.fold<double>(
          0,
          (sum, item) => sum + (item.quantity * item.costPerItem),
        );
        final totalLines = order.items.length;
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (_) => _OrderItemsDialog(
                  order: order,
                  products: products,
                  orders: orders,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _OriginIcon(iconUrl: order.originIconUrl, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.secondaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          _formatDate(order.registeredAt),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSecondaryContainer,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          order.origin,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Pedido ${order.id}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelSmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'R\$ ${totalValue.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _QuickStatChip(
                              icon: Icons.shopping_basket_outlined,
                              label:
                                  '$totalLines item${totalLines > 1 ? 's' : ''}',
                            ),
                            _QuickStatChip(
                              icon: Icons.inventory_2_outlined,
                              label: '$totalItems unidades',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isEditModeEnabled) ...[
                    const SizedBox(width: 2),
                    PopupMenuButton<_OrderAction>(
                      tooltip: 'Acoes do pedido',
                      onSelected: (action) {
                        if (action == _OrderAction.edit) {
                          onEditOrder(order);
                          return;
                        }
                        onDeleteOrder(order);
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<_OrderAction>(
                          value: _OrderAction.edit,
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: Colors.amber.shade700,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Editar pedido',
                                style: TextStyle(color: Colors.amber.shade700),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem<_OrderAction>(
                          value: _OrderAction.delete,
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: Colors.amber.shade700,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Excluir pedido',
                                style: TextStyle(color: Colors.amber.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PriceCalculatorTab extends StatefulWidget {
  const _PriceCalculatorTab();

  @override
  State<_PriceCalculatorTab> createState() => _PriceCalculatorTabState();
}

class _PriceCalculatorTabState extends State<_PriceCalculatorTab> {
  static const double _defaultIfoodRate = _calculatorDefaultIfoodRate;
  static const double _defaultPaymentRate = _calculatorDefaultPaymentRate;
  static const double _defaultOperationFixed = _calculatorDefaultOperationFixed;
  static const double _defaultMarginPercent = _calculatorDefaultMarginPercent;

  static const String _ifoodRateKey = _calculatorIfoodRateKey;
  static const String _paymentRateKey = _calculatorPaymentRateKey;
  static const String _operationFixedKey = _calculatorOperationFixedKey;
  static const String _marginKey = _calculatorMarginKey;

  static const double _operationReferencePrice = 20;

  final _costController = TextEditingController();
  final _marginController = TextEditingController(
    text: _defaultMarginPercent.toStringAsFixed(0),
  );
  double _ifoodRate = _defaultIfoodRate;
  double _paymentRate = _defaultPaymentRate;
  double _operationFixed = _defaultOperationFixed;

  @override
  void initState() {
    super.initState();
    _loadCalculatorSettings();
  }

  @override
  void dispose() {
    _costController.dispose();
    _marginController.dispose();
    super.dispose();
  }

  Future<void> _loadCalculatorSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) {
      return;
    }

    setState(() {
      _ifoodRate = prefs.getDouble(_ifoodRateKey) ?? _defaultIfoodRate;
      _paymentRate = prefs.getDouble(_paymentRateKey) ?? _defaultPaymentRate;
      _operationFixed =
          prefs.getDouble(_operationFixedKey) ?? _defaultOperationFixed;
      final savedMargin = prefs.getDouble(_marginKey) ?? _defaultMarginPercent;
      final marginDisplay = savedMargin % 1 == 0
          ? savedMargin.toStringAsFixed(0)
          : savedMargin.toStringAsFixed(1);
      _marginController
        ..text = marginDisplay
        ..selection = TextSelection.collapsed(offset: marginDisplay.length);
    });
  }

  Future<void> _persistCalculatorSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_ifoodRateKey, _ifoodRate);
    await prefs.setDouble(_paymentRateKey, _paymentRate);
    await prefs.setDouble(_operationFixedKey, _operationFixed);
    await prefs.setDouble(
      _marginKey,
      _parseDecimal(_marginController.text).clamp(0, 99.9).toDouble(),
    );
  }

  void _onMarginChanged() {
    setState(() {});
    _persistCalculatorSettings();
  }

  Future<double?> _showRateDialog({
    required String title,
    required String label,
    required double initialPercent,
  }) async {
    final controller = TextEditingController(
      text: initialPercent.toStringAsFixed(2),
    );

    final newValue = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: _dialogInsetPadding(context),
        title: Text(title),
        content: TextField(
          scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, suffixText: '%'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = _parseDecimal(controller.text);
              if (value < 0) {
                return;
              }
              Navigator.of(context).pop(value / 100);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    return newValue;
  }

  Future<void> _editIfoodRate() async {
    final newValue = await _showRateDialog(
      title: 'Alterar tarifa iFood',
      label: 'Tarifa iFood',
      initialPercent: _ifoodRate * 100,
    );

    if (newValue != null) {
      setState(() {
        _ifoodRate = newValue.clamp(0, 99.9) / 100;
      });
      await _persistCalculatorSettings();
    }
  }

  Future<void> _editPaymentRate() async {
    final newValue = await _showRateDialog(
      title: 'Alterar taxa de pagamento',
      label: 'Taxa de pagamento',
      initialPercent: _paymentRate * 100,
    );

    if (newValue != null) {
      setState(() {
        _paymentRate = newValue.clamp(0, 99.9) / 100;
      });
      await _persistCalculatorSettings();
    }
  }

  Future<void> _editOperationFixed() async {
    final controller = TextEditingController(
      text: _operationFixed.toStringAsFixed(2),
    );

    final newValue = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: _dialogInsetPadding(context),
        title: const Text('Alterar operacao fixa'),
        content: TextField(
          scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Valor fixo (para preco >= 20)',
            prefixText: 'R\$ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = _parseDecimal(controller.text);
              if (value < 0) {
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (newValue != null) {
      setState(() => _operationFixed = newValue);
      await _persistCalculatorSettings();
    }
  }

  double _parseDecimal(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.').trim());
    return parsed ?? 0;
  }

  void _adjustMargin(double delta) {
    final current = _parseDecimal(
      _marginController.text,
    ).clamp(0, 99.9).toDouble();
    final updated = (current + delta).clamp(0, 99.9).toDouble();
    final display = updated % 1 == 0
        ? updated.toStringAsFixed(0)
        : updated.toStringAsFixed(1);

    _marginController
      ..text = display
      ..selection = TextSelection.collapsed(offset: display.length);

    setState(() {});
    _persistCalculatorSettings();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSmallPhone = screenWidth < 380;
    final isPhone = screenWidth < 600;

    final cost = _parseDecimal(_costController.text);
    final marginPercent = _parseDecimal(
      _marginController.text,
    ).clamp(0, 99.9).toDouble();
    final operationFixed = _operationFixed;
    final marginRate = marginPercent / 100;
    final baseDenominator = 1 - (marginRate + _ifoodRate + _paymentRate);
    final lowPriceDenominator =
        baseDenominator - (operationFixed / _operationReferencePrice);

    double price = 0;
    if (cost > 0 && operationFixed >= 0) {
      final double lowCandidate = lowPriceDenominator > 0
          ? (cost / lowPriceDenominator)
          : -1.0;
      final double highCandidate = baseDenominator > 0
          ? ((cost + operationFixed) / baseDenominator)
          : -1.0;

      if (lowCandidate > 0 && lowCandidate < _operationReferencePrice) {
        price = lowCandidate;
      } else if (highCandidate > 0 &&
          highCandidate >= _operationReferencePrice) {
        price = highCandidate;
      } else if (highCandidate > 0) {
        price = highCandidate;
      } else if (lowCandidate > 0) {
        price = lowCandidate;
      }
    }

    final hasValidInputs = price > 0;
    final double ifoodFee = hasValidInputs ? price * _ifoodRate : 0.0;
    final double operationFee = hasValidInputs
        ? (price >= _operationReferencePrice
              ? operationFixed
              : (price / _operationReferencePrice) * operationFixed)
        : 0.0;
    final double paymentFee = hasValidInputs ? price * _paymentRate : 0.0;
    final double profit = hasValidInputs
        ? price - cost - ifoodFee - operationFee - paymentFee
        : 0.0;
    final double markupPercent = cost > 0
        ? (((price - ifoodFee - paymentFee - operationFee) / cost) - 1) * 100
        : 0.0;
    final profitColor = profit >= 0
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.error;

    double shareOf(double value) {
      if (!hasValidInputs || price <= 0) {
        return 0;
      }
      return (value / price).clamp(0, 1).toDouble();
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        isPhone ? 10 : 16,
        12,
        isPhone ? 10 : 16,
        24,
      ),
      children: [
        Container(
          padding: EdgeInsets.all(isPhone ? 12 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                Theme.of(context).colorScheme.surfaceContainerLow,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compactHeader = constraints.maxWidth < 420;

                  if (compactHeader) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.calculate_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Calculadora de Preco',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(
                            hasValidInputs
                                ? Icons.auto_graph_outlined
                                : Icons.pending_outlined,
                            size: 16,
                          ),
                          label: Text(
                            hasValidInputs
                                ? 'Simulacao ativa'
                                : 'Aguardando dados',
                          ),
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Icon(
                        Icons.calculate_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Calculadora de Preco',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(
                          hasValidInputs
                              ? Icons.auto_graph_outlined
                              : Icons.pending_outlined,
                          size: 16,
                        ),
                        label: Text(
                          hasValidInputs
                              ? 'Simulacao ativa'
                              : 'Aguardando dados',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isPhone ? 10 : 12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preco sugerido',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 280),
                      tween: Tween<double>(
                        begin: 0,
                        end: hasValidInputs ? price : 0,
                      ),
                      builder: (context, animatedPrice, _) {
                        return Text(
                          'R\$ ${animatedPrice.toStringAsFixed(2)}',
                          style:
                              (isSmallPhone
                                      ? Theme.of(context).textTheme.titleLarge
                                      : Theme.of(
                                          context,
                                        ).textTheme.headlineSmall)
                                  ?.copyWith(fontWeight: FontWeight.w800),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickStatChip(
                            icon: Icons.trending_up_outlined,
                            label: 'Lucro R\$ ${profit.toStringAsFixed(2)}',
                            expand: true,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _QuickStatChip(
                            icon: Icons.query_stats_outlined,
                            label:
                                'Markup ${markupPercent.toStringAsFixed(1)}%',
                            expand: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final fields = [
                    TextField(
                      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
                      controller: _costController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Custo',
                        hintText: 'Ex: 12,50',
                        prefixText: 'R\$ ',
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                    ),
                    TextField(
                      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
                      controller: _marginController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => _onMarginChanged(),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        labelText: 'Margem %',
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                        prefixIcon: IconButton(
                          onPressed: () => _adjustMargin(-1),
                          tooltip: 'Diminuir margem',
                          icon: const Icon(Icons.remove, size: 18),
                          visualDensity: VisualDensity.compact,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () => _adjustMargin(1),
                          tooltip: 'Aumentar margem',
                          icon: const Icon(Icons.add, size: 18),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ];

                  if (constraints.maxWidth < 540) {
                    return Column(
                      children: [
                        fields[0],
                        const SizedBox(height: 10),
                        fields[1],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: fields[0]),
                      const SizedBox(width: 10),
                      Expanded(child: fields[1]),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!hasValidInputs)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Informe custo maior que zero e valores compativeis para margem e operacao.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        if (hasValidInputs) ...[
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.stacked_bar_chart_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Composicao do preco',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _PriceCompositionBar(
                  label: 'Custo',
                  valueLabel: 'R\$ ${cost.toStringAsFixed(2)}',
                  fraction: shareOf(cost),
                ),
                const SizedBox(height: 8),
                _PriceCompositionBar(
                  label: 'Tarifa iFood',
                  valueLabel: 'R\$ ${ifoodFee.toStringAsFixed(2)}',
                  fraction: shareOf(ifoodFee),
                ),
                const SizedBox(height: 8),
                _PriceCompositionBar(
                  label: 'Operacao',
                  valueLabel: 'R\$ ${operationFee.toStringAsFixed(2)}',
                  fraction: shareOf(operationFee),
                ),
                const SizedBox(height: 8),
                _PriceCompositionBar(
                  label: 'Taxa pagamento',
                  valueLabel: 'R\$ ${paymentFee.toStringAsFixed(2)}',
                  fraction: shareOf(paymentFee),
                ),
                const SizedBox(height: 8),
                _PriceCompositionBar(
                  label: 'Lucro',
                  valueLabel: 'R\$ ${profit.toStringAsFixed(2)}',
                  fraction: shareOf(profit),
                  color: profitColor,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Indicadores',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final useSingleColumn = constraints.maxWidth < 430;

            final cards = [
              _CalculatorMetricCard(
                icon: Icons.storefront_outlined,
                label: 'Tarifa iFood',
                value: 'R\$ ${ifoodFee.toStringAsFixed(2)}',
                subtitle: '${(_ifoodRate * 100).toStringAsFixed(1)}%',
                onTap: _editIfoodRate,
              ),
              _CalculatorMetricCard(
                icon: Icons.settings_outlined,
                label: 'Operacao',
                value: 'R\$ ${operationFee.toStringAsFixed(2)}',
                subtitle: price >= _operationReferencePrice
                    ? 'Fixo: R\$ ${operationFixed.toStringAsFixed(2)}'
                    : 'Proporcional ate R\$ ${operationFixed.toStringAsFixed(2)}',
                onTap: _editOperationFixed,
              ),
              _CalculatorMetricCard(
                icon: Icons.credit_card_outlined,
                label: 'Taxa de Pagamento',
                value: 'R\$ ${paymentFee.toStringAsFixed(2)}',
                subtitle: '${(_paymentRate * 100).toStringAsFixed(1)}%',
                onTap: _editPaymentRate,
              ),
            ];

            if (useSingleColumn) {
              return Column(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    SizedBox(width: double.infinity, child: cards[i]),
                    if (i != cards.length - 1) const SizedBox(height: 8),
                  ],
                ],
              );
            }

            return Wrap(spacing: 8, runSpacing: 8, children: cards);
          },
        ),
      ],
    );
  }
}

class _CalculatorMetricCard extends StatelessWidget {
  const _CalculatorMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showTapHint = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minWidth: 150),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: scheme.outline),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        if (showTapHint)
                          Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: scheme.outline,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: scheme.outline),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceCompositionBar extends StatelessWidget {
  const _PriceCompositionBar({
    required this.label,
    required this.valueLabel,
    required this.fraction,
    this.color,
  });

  final String label;
  final String valueLabel;
  final double fraction;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedColor = color ?? scheme.primary;
    final isNarrow = MediaQuery.sizeOf(context).width < 360;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isNarrow)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 2),
              Text(
                valueLabel,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              Text(
                valueLabel,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: fraction,
            color: resolvedColor,
            backgroundColor: scheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _ProductOrderHistoryDialog extends StatelessWidget {
  const _ProductOrderHistoryDialog({
    required this.product,
    required this.products,
    required this.orders,
    this.enableItemTap = true,
  });

  final Product product;
  final List<Product> products;
  final List<Order> orders;
  final bool enableItemTap;

  @override
  Widget build(BuildContext context) {
    final ordersById = {for (final order in orders) order.id: order};
    final entries = <_ProductOrderEntry>[];
    for (final order in orders) {
      for (final item in order.items.where(
        (item) => item.productSku == product.sku,
      )) {
        entries.add(
          _ProductOrderEntry(
            orderId: order.id,
            registeredAt: order.registeredAt,
            origin: order.origin,
            originIconUrl: order.originIconUrl,
            quantity: item.quantity,
            costPerItem: item.costPerItem,
            lineTotal: item.quantity * item.costPerItem,
          ),
        );
      }
    }

    entries.sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
    var selectedWindow = _CostHistoryWindow.sixMonths;

    return FutureBuilder<_CalculatorPricingConfig>(
      future: _loadCalculatorPricingConfig(),
      builder: (context, pricingSnapshot) {
        final pricingConfig =
            pricingSnapshot.data ??
            const _CalculatorPricingConfig(
              ifoodRate: _calculatorDefaultIfoodRate,
              paymentRate: _calculatorDefaultPaymentRate,
              operationFixed: _calculatorDefaultOperationFixed,
              marginPercent: _calculatorDefaultMarginPercent,
            );
        var dialogMarginPercent = pricingConfig.marginPercent
            .clamp(0, 99.9)
            .toDouble();
        String formatMargin(double value) {
          return value % 1 == 0
              ? value.toStringAsFixed(0)
              : value.toStringAsFixed(1);
        }

        final marginController = TextEditingController(
          text: formatMargin(dialogMarginPercent),
        );

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final activePricingConfig = _CalculatorPricingConfig(
              ifoodRate: pricingConfig.ifoodRate,
              paymentRate: pricingConfig.paymentRate,
              operationFixed: pricingConfig.operationFixed,
              marginPercent: dialogMarginPercent,
            );
            final now = DateTime.now();
            final filteredEntries = _entriesForCostWindow(
              entries,
              selectedWindow,
              now,
            );
            final lowestUnitCost = filteredEntries.isEmpty
                ? null
                : filteredEntries
                      .map((entry) => entry.costPerItem)
                      .reduce((a, b) => min(a, b));
            final averageUnitCost = filteredEntries.isEmpty
                ? null
                : filteredEntries.fold<double>(
                        0,
                        (sum, entry) => sum + entry.costPerItem,
                      ) /
                      filteredEntries.length;
            final lastUnitCost = filteredEntries.isEmpty
                ? null
                : filteredEntries.first.costPerItem;

            return AlertDialog(
              insetPadding: _dialogInsetPadding(context),
              titlePadding: EdgeInsets.zero,
              contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              content: SizedBox(
                width: _dialogMaxWidth(context, 560),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Row(
                        children: [
                          _ProductImagePreview(imageUrl: product.imageUrl),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${product.sku} · ${product.brand}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (entries.isNotEmpty) ...[
                      Row(
                        children: [
                          for (final option in _CostHistoryWindow.values) ...[
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: _CostWindowButton(
                                  label: option.label,
                                  selected: selectedWindow == option,
                                  onPressed: () {
                                    setDialogState(() {
                                      selectedWindow = option;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Column(
                          children: [
                            _CompactMetricChip(
                              title: 'Menor',
                              value: lowestUnitCost == null
                                  ? '--'
                                  : 'R\$ ${lowestUnitCost.toStringAsFixed(2)}',
                              secondaryValue: lowestUnitCost == null
                                  ? null
                                  : 'R\$ ${_calculateSuggestedPriceFromCost(lowestUnitCost, activePricingConfig).toStringAsFixed(2)}',
                              valueIcon: Icons.receipt_long_outlined,
                              secondaryValueIcon: Icons.sell_outlined,
                              expand: true,
                            ),
                            const SizedBox(height: 6),
                            _CompactMetricChip(
                              title: 'Medio',
                              value: averageUnitCost == null
                                  ? '--'
                                  : 'R\$ ${averageUnitCost.toStringAsFixed(2)}',
                              secondaryValue: averageUnitCost == null
                                  ? null
                                  : 'R\$ ${_calculateSuggestedPriceFromCost(averageUnitCost, activePricingConfig).toStringAsFixed(2)}',
                              valueIcon: Icons.receipt_long_outlined,
                              secondaryValueIcon: Icons.sell_outlined,
                              highlighted: true,
                              expand: true,
                            ),
                            const SizedBox(height: 6),
                            _CompactMetricChip(
                              title: 'Ultimo',
                              value: lastUnitCost == null
                                  ? '--'
                                  : 'R\$ ${lastUnitCost.toStringAsFixed(2)}',
                              secondaryValue: lastUnitCost == null
                                  ? null
                                  : 'R\$ ${_calculateSuggestedPriceFromCost(lastUnitCost, activePricingConfig).toStringAsFixed(2)}',
                              valueIcon: Icons.receipt_long_outlined,
                              secondaryValueIcon: Icons.sell_outlined,
                              expand: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        scrollPadding: const EdgeInsets.fromLTRB(
                          20,
                          20,
                          20,
                          220,
                        ),
                        controller: marginController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: 'Margem da calculadora %',
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          isDense: true,
                          prefixIcon: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                dialogMarginPercent = (dialogMarginPercent - 1)
                                    .clamp(0, 99.9)
                                    .toDouble();
                                final display = formatMargin(
                                  dialogMarginPercent,
                                );
                                marginController
                                  ..text = display
                                  ..selection = TextSelection.collapsed(
                                    offset: display.length,
                                  );
                              });
                              _persistCalculatorMarginPercent(
                                dialogMarginPercent,
                              );
                            },
                            tooltip: 'Diminuir margem',
                            icon: const Icon(Icons.remove, size: 18),
                            visualDensity: VisualDensity.compact,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setDialogState(() {
                                dialogMarginPercent = (dialogMarginPercent + 1)
                                    .clamp(0, 99.9)
                                    .toDouble();
                                final display = formatMargin(
                                  dialogMarginPercent,
                                );
                                marginController
                                  ..text = display
                                  ..selection = TextSelection.collapsed(
                                    offset: display.length,
                                  );
                              });
                              _persistCalculatorMarginPercent(
                                dialogMarginPercent,
                              );
                            },
                            tooltip: 'Aumentar margem',
                            icon: const Icon(Icons.add, size: 18),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        onChanged: (value) {
                          final parsed = double.tryParse(
                            value.replaceAll(',', '.').trim(),
                          )?.clamp(0, 99.9).toDouble();
                          if (parsed == null) {
                            return;
                          }
                          setDialogState(() {
                            dialogMarginPercent = parsed;
                          });
                          _persistCalculatorMarginPercent(dialogMarginPercent);
                        },
                        onEditingComplete: () {
                          final display = formatMargin(dialogMarginPercent);
                          marginController
                            ..text = display
                            ..selection = TextSelection.collapsed(
                              offset: display.length,
                            );
                          FocusScope.of(context).unfocus();
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    Flexible(
                      child: entries.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Este produto ainda nao foi incluido em pedidos.',
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: entries.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 4),
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                final selectedOrder = ordersById[entry.orderId];
                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap:
                                        !enableItemTap || selectedOrder == null
                                        ? null
                                        : () {
                                            showDialog<void>(
                                              context: context,
                                              builder: (_) => _OrderItemsDialog(
                                                order: selectedOrder,
                                                products: products,
                                                orders: orders,
                                                enableItemTap: false,
                                              ),
                                            );
                                          },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outlineVariant,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _OriginIcon(
                                            iconUrl: entry.originIconUrl,
                                            size: 30,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        entry.origin,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Wrap(
                                                      spacing: 6,
                                                      runSpacing: 4,
                                                      crossAxisAlignment:
                                                          WrapCrossAlignment
                                                              .center,
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 3,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .tertiaryContainer,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            'R\$ ${entry.costPerItem.toStringAsFixed(2)}/un',
                                                            style: Theme.of(context)
                                                                .textTheme
                                                                .labelMedium
                                                                ?.copyWith(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.onTertiaryContainer,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${entry.orderId}  •  ${_formatDate(entry.registeredAt)}',
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.labelSmall,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .inventory_2_outlined,
                                                      size: 13,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.outline,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${entry.quantity} un',
                                                      style: Theme.of(
                                                        context,
                                                      ).textTheme.labelSmall,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Icon(
                                                      Icons.summarize_outlined,
                                                      size: 13,
                                                      color: Theme.of(
                                                        context,
                                                      ).colorScheme.outline,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      'Total R\$ ${entry.lineTotal.toStringAsFixed(2)}',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

List<_ProductOrderEntry> _entriesForCostWindow(
  List<_ProductOrderEntry> entries,
  _CostHistoryWindow window,
  DateTime now,
) {
  if (window == _CostHistoryWindow.all) {
    return entries;
  }

  final months = switch (window) {
    _CostHistoryWindow.oneMonth => 1,
    _CostHistoryWindow.threeMonths => 3,
    _CostHistoryWindow.sixMonths => 6,
    _CostHistoryWindow.oneYear => 12,
    _CostHistoryWindow.all => 0,
  };
  final start = DateTime(now.year, now.month - months, now.day);
  return entries
      .where((entry) => !entry.registeredAt.isBefore(start))
      .toList(growable: false);
}

class _OrderItemsDialog extends StatelessWidget {
  const _OrderItemsDialog({
    required this.order,
    required this.products,
    required this.orders,
    this.enableItemTap = true,
  });

  final Order order;
  final List<Product> products;
  final List<Order> orders;
  final bool enableItemTap;

  @override
  Widget build(BuildContext context) {
    final productsBySku = {
      for (final product in products) product.sku: product,
    };
    final totalUnits = order.items.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final totalValue = order.items.fold<double>(
      0,
      (sum, item) => sum + (item.quantity * item.costPerItem),
    );

    return AlertDialog(
      insetPadding: _dialogInsetPadding(context),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      content: SizedBox(
        width: _dialogMaxWidth(context, 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _OriginIcon(iconUrl: order.originIconUrl, size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.origin,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              'Data ${_formatDate(order.registeredAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final metrics = [
                        _CompactMetricChip(
                          icon: Icons.inventory_2_outlined,
                          title: 'Unidades',
                          value: '$totalUnits',
                          expand: true,
                        ),
                        _CompactMetricChip(
                          icon: Icons.shopping_basket_outlined,
                          title: 'Itens',
                          value: '${order.items.length}',
                          expand: true,
                        ),
                        _CompactMetricChip(
                          icon: Icons.payments_outlined,
                          title: 'Total',
                          value: 'R\$ ${totalValue.toStringAsFixed(2)}',
                          highlighted: true,
                          expand: true,
                        ),
                      ];

                      if (constraints.maxWidth < 440) {
                        return Column(
                          children: [
                            metrics[0],
                            const SizedBox(height: 6),
                            metrics[1],
                            const SizedBox(height: 6),
                            metrics[2],
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: metrics[0]),
                          const SizedBox(width: 6),
                          Expanded(child: metrics[1]),
                          const SizedBox(width: 6),
                          Expanded(child: metrics[2]),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: order.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final item = order.items[index];
                  final product = productsBySku[item.productSku];
                  final productName = product?.description ?? item.productSku;
                  final lineTotal = item.quantity * item.costPerItem;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: !enableItemTap || product == null
                          ? null
                          : () {
                              showDialog<void>(
                                context: context,
                                builder: (_) => _ProductOrderHistoryDialog(
                                  product: product,
                                  products: products,
                                  orders: orders,
                                  enableItemTap: false,
                                ),
                              );
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                              ),
                              child: _ProductImageThumbnail(
                                imageUrl: product?.imageUrl ?? '',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          productName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.tertiaryContainer,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'R\$ ${item.costPerItem.toStringAsFixed(2)}/un',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w900,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onTertiaryContainer,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'SKU ${item.productSku} | ${_formatDate(item.expirationDate)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Quantidade ${item.quantity} | Total R\$ ${lineTotal.toStringAsFixed(2)}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

class _CreateProductDialog extends StatefulWidget {
  const _CreateProductDialog({
    required this.brands,
    this.initialProduct,
    this.isEditing = false,
  });

  final List<String> brands;
  final Product? initialProduct;
  final bool isEditing;

  @override
  State<_CreateProductDialog> createState() => _CreateProductDialogState();
}

class _CreateProductDialogState extends State<_CreateProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _stockController = TextEditingController();
  final _expirationDateController = TextEditingController();
  final _newBrandController = TextEditingController();
  late bool _createNewBrand;
  String? _selectedBrand;
  DateTime? _expirationDate;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialProduct;
    if (initial != null) {
      _descriptionController.text = initial.description;
      _imageUrlController.text = initial.imageUrl;
      _stockController.text = initial.stock.toString();
      _expirationDate = initial.expirationDate;
      _expirationDateController.text = initial.expirationDate == null
          ? ''
          : _formatDate(initial.expirationDate!);
    }

    _createNewBrand = widget.brands.isEmpty;
    _selectedBrand = null;

    if (initial != null) {
      final hasBrand = widget.brands.contains(initial.brand);
      _createNewBrand = !hasBrand;
      if (hasBrand) {
        _selectedBrand = initial.brand;
      } else {
        _newBrandController.text = initial.brand;
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _stockController.dispose();
    _expirationDateController.dispose();
    _newBrandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return AlertDialog(
          insetPadding: _dialogInsetPadding(context),
          title: Row(
            children: [
              Icon(
                widget.isEditing
                    ? Icons.edit_outlined
                    : Icons.add_circle_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.isEditing ? 'Editar produto' : 'Novo produto',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 700 : 560),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildBasicInfoSection(context),
                    const SizedBox(height: 16),
                    _buildImageSection(context),
                    const SizedBox(height: 16),
                    _buildBrandSection(context, isWide),
                    const SizedBox(height: 16),
                    _buildStockAndDateSection(context, isWide),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBasicInfoSection(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Informações Básicas',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Descrição',
                hintText: 'Ex: Leite integral 1L, Pão francês, Arroz 5kg',
                prefixIcon: const Icon(Icons.shopping_bag_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              textInputAction: TextInputAction.next,
              validator: (value) => _required(value, 'Descrição'),
              onChanged: (value) => setState(() {}),
            ),
            if (!widget.isEditing) ...[
              const SizedBox(height: 8),
              _buildSkuPreview(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSkuPreview(BuildContext context) {
    final description = _descriptionController.text.trim();
    String skuPreview = 'SKU será gerado automaticamente';
    if (description.isNotEmpty) {
      final letters = description
          .replaceAll(RegExp(r'[^a-zA-Z]'), '')
          .toUpperCase()
          .padRight(6, 'X')
          .substring(0, 6);
      final randomNum = (DateTime.now().millisecondsSinceEpoch % 10000)
          .toString()
          .padLeft(4, '0');
      skuPreview = '$letters$randomNum';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.primaryContainer,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.code_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SKU', style: Theme.of(context).textTheme.labelSmall),
                Text(
                  skuPreview,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.image_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Imagem do Produto',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
              controller: _imageUrlController,
              decoration: InputDecoration(
                labelText: 'URL da imagem',
                hintText: 'https://example.com/image.jpg',
                prefixIcon: const Icon(Icons.link_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              validator: (value) => _required(value, 'URL da imagem'),
              onChanged: (value) => setState(() {}),
            ),
            if (_imageUrlController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildImagePreviewSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreviewSection() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          _imageUrlController.text.trim(),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 8),
                Text(
                  'Imagem não disponível',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrandSection(BuildContext context, bool isWide) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sell_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Marca',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Existente'),
                  icon: Icon(Icons.list_alt_outlined),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Nova'),
                  icon: Icon(Icons.add_outlined),
                ),
              ],
              selected: {_createNewBrand},
              onSelectionChanged: (value) {
                setState(() => _createNewBrand = value.first);
              },
            ),
            const SizedBox(height: 12),
            if (_createNewBrand)
              TextFormField(
                scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
                controller: _newBrandController,
                decoration: InputDecoration(
                  labelText: 'Nome da marca',
                  hintText: 'Ex: Nestlé, Danone, Cargill',
                  prefixIcon: const Icon(Icons.business_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (_createNewBrand) {
                    return _required(value, 'Nome da marca');
                  }
                  return null;
                },
              )
            else ...[
              _buildBrandChips(context, isWide),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBrandChips(BuildContext context, bool isWide) {
    if (widget.brands.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Nenhuma marca cadastrada',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.brands
          .map(
            (brand) => FilterChip(
              label: Text(brand),
              selected: _selectedBrand == brand,
              onSelected: (selected) {
                setState(() => _selectedBrand = selected ? brand : null);
              },
              showCheckmark: true,
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildStockAndDateSection(BuildContext context, bool isWide) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Estoque e Validade',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isWide)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Quantidade',
                        prefixIcon: const Icon(Icons.add_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                      validator: (value) {
                        if (_required(value, 'Estoque') != null) {
                          return _required(value, 'Estoque');
                        }
                        final stock = int.tryParse(value!.trim());
                        if (stock == null || stock < 0) {
                          return 'Inválido';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDatePickerField(context)),
                ],
              )
            else
              Column(
                children: [
                  TextFormField(
                    scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Quantidade',
                      hintText: '0',
                      prefixIcon: const Icon(Icons.add_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    validator: (value) {
                      if (_required(value, 'Estoque') != null) {
                        return _required(value, 'Estoque');
                      }
                      final stock = int.tryParse(value!.trim());
                      if (stock == null || stock < 0) {
                        return 'Inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildDatePickerField(context),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerField(BuildContext context) {
    final now = DateTime.now();
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: TextFormField(
              scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
              controller: _expirationDateController,
              keyboardType: TextInputType.datetime,
              inputFormatters: _dateInputFormatters(),
              decoration: InputDecoration(
                labelText: 'Validade',
                hintText: 'dd/mm/aaaa',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return null;
                }
                final parsed = _parseDateInput(
                  text,
                  minDate: DateTime(now.year, now.month, now.day),
                  maxDate: DateTime(now.year + 20),
                );
                if (parsed == null) {
                  return 'Use o formato dd/mm/aaaa';
                }
                return null;
              },
              onChanged: (value) {
                final parsed = _parseDateInput(
                  value,
                  minDate: DateTime(now.year, now.month, now.day),
                  maxDate: DateTime(now.year + 20),
                );
                _expirationDate = parsed;
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          height: 48,
          child: OutlinedButton(
            onPressed: _pickDate,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Icon(
              Icons.calendar_month_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 20),
      initialDate: _expirationDate ?? now,
    );
    if (picked != null) {
      setState(() {
        _expirationDate = picked;
        _expirationDateController.text = _formatDate(picked);
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final brand = _createNewBrand
        ? _newBrandController.text.trim()
        : (_selectedBrand ?? '').trim();
    if (brand.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe ou selecione a marca.')),
      );
      return;
    }

    Navigator.of(context).pop(
      _ProductFormData(
        description: _descriptionController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        stock: int.parse(_stockController.text.trim()),
        brand: brand,
        expirationDate: _expirationDate,
      ),
    );
  }
}

class _UpdateStockDialog extends StatefulWidget {
  const _UpdateStockDialog({required this.product});

  final Product product;

  @override
  State<_UpdateStockDialog> createState() => _UpdateStockDialogState();
}

class _UpdateStockDialogState extends State<_UpdateStockDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _stockController;

  int get _parsedStock => int.tryParse(_stockController.text.trim()) ?? 0;

  void _setStock(int value) {
    final safeValue = value < 0 ? 0 : value;
    final display = safeValue.toString();
    _stockController
      ..text = display
      ..selection = TextSelection.collapsed(offset: display.length);
    setState(() {});
  }

  void _adjustStock(int delta) {
    _setStock(_parsedStock + delta);
  }

  @override
  void initState() {
    super.initState();
    _stockController = TextEditingController(
      text: widget.product.stock.toString(),
    );
  }

  @override
  void dispose() {
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      insetPadding: _dialogInsetPadding(context),
      title: const Text('Atualizar estoque'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: _dialogMaxWidth(context, 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product.description,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => _adjustStock(-1),
                      tooltip: 'Diminuir',
                      icon: const Icon(Icons.remove),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Novo estoque',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Text(
                            _parsedStock.toString(),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filled(
                      onPressed: () => _adjustStock(1),
                      tooltip: 'Aumentar',
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
                controller: _stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Editar manualmente',
                  prefixIcon: Icon(Icons.edit_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_required(value, 'Novo estoque') != null) {
                    return _required(value, 'Novo estoque');
                  }
                  final parsed = int.tryParse(value!.trim());
                  if (parsed == null || parsed < 0) {
                    return 'Informe um valor inteiro valido.';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(int.parse(_stockController.text.trim()));
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

class _UpdateExpirationDialog extends StatefulWidget {
  const _UpdateExpirationDialog({required this.product});

  final Product product;

  @override
  State<_UpdateExpirationDialog> createState() =>
      _UpdateExpirationDialogState();
}

class _UpdateExpirationDialogState extends State<_UpdateExpirationDialog> {
  DateTime? _selectedDate;
  late final TextEditingController _dateController;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.product.expirationDate;
    _dateController = TextEditingController(
      text: _selectedDate == null ? '' : _formatDate(_selectedDate!),
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      insetPadding: _dialogInsetPadding(context),
      title: const Text('Atualizar validade'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: _dialogMaxWidth(context, 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product.description,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Validade atual',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.product.expirationDate == null
                          ? 'Sem data definida'
                          : _formatDate(widget.product.expirationDate!),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nova validade',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: TextField(
                              scrollPadding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                220,
                              ),
                              controller: _dateController,
                              keyboardType: TextInputType.datetime,
                              inputFormatters: _dateInputFormatters(),
                              decoration: InputDecoration(
                                hintText: 'dd/mm/aaaa',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                isDense: true,
                              ),
                              onChanged: (value) {
                                final now = DateTime.now();
                                setState(() {
                                  _selectedDate = _parseDateInput(
                                    value,
                                    minDate: DateTime(now.year - 10),
                                    maxDate: DateTime(now.year + 20),
                                  );
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _pickDate,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Icon(
                              Icons.calendar_month_outlined,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final now = DateTime.now();
            final typedDate = _parseDateInput(
              _dateController.text,
              minDate: DateTime(now.year - 10),
              maxDate: DateTime(now.year + 20),
            );
            if (_dateController.text.trim().isNotEmpty && typedDate == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Informe uma data valida no formato dd/mm/aaaa.',
                  ),
                ),
              );
              return;
            }
            if (_selectedDate == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Selecione a nova validade.')),
              );
              return;
            }
            Navigator.of(context).pop(_selectedDate);
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20),
      initialDate: _selectedDate ?? widget.product.expirationDate ?? now,
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }
}

class _CreateOrderDialog extends StatefulWidget {
  const _CreateOrderDialog({
    required this.products,
    required this.origins,
    required this.onAddProductRequested,
    this.initialOrder,
    this.isEditing = false,
  });

  final List<Product> products;
  final List<OrderOrigin> origins;
  final Future<Product?> Function() onAddProductRequested;
  final Order? initialOrder;
  final bool isEditing;

  @override
  State<_CreateOrderDialog> createState() => _CreateOrderDialogState();
}

class _CreateOrderDialogState extends State<_CreateOrderDialog> {
  static const String _productPlaceholderSku = '__SELECT_PRODUCT_PLACEHOLDER__';

  final _formKey = GlobalKey<FormState>();
  final _newOriginController = TextEditingController();
  final _newOriginIconController = TextEditingController();
  final List<_OrderItemDraft> _itemDrafts = [];
  late List<Product> _products;
  late bool _createNewOrigin;
  OrderOrigin? _selectedOrigin;

  @override
  void initState() {
    super.initState();
    _products = [...widget.products];
    _createNewOrigin = widget.origins.isEmpty;
    _selectedOrigin = null;

    final initialOrder = widget.initialOrder;
    if (initialOrder != null) {
      final hasOrigin = widget.origins.any(
        (o) => o.name == initialOrder.origin,
      );
      _createNewOrigin = !hasOrigin;
      if (hasOrigin) {
        _selectedOrigin = widget.origins.firstWhere(
          (o) => o.name == initialOrder.origin,
        );
      } else {
        _newOriginController.text = initialOrder.origin;
        _newOriginIconController.text = initialOrder.originIconUrl ?? '';
      }

      for (final item in initialOrder.items) {
        _itemDrafts.add(
          _OrderItemDraft(
            productSku: item.productSku,
            initialQuantity: item.quantity,
            initialCostPerItem: item.costPerItem,
            initialExpirationDate: item.expirationDate,
          ),
        );
      }
    }

    if (_itemDrafts.isEmpty) {
      _itemDrafts.add(_OrderItemDraft(productSku: _productPlaceholderSku));
    }
  }

  @override
  void dispose() {
    _newOriginController.dispose();
    _newOriginIconController.dispose();
    for (final draft in _itemDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return AlertDialog(
          insetPadding: _dialogInsetPadding(context),
          title: Row(
            children: [
              Icon(
                widget.isEditing
                    ? Icons.edit_outlined
                    : Icons.receipt_long_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.isEditing ? 'Editar pedido' : 'Novo pedido',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 800 : 640),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildOriginSection(context),
                    const SizedBox(height: 16),
                    _buildItemsSection(context, isWide),
                    const SizedBox(height: 16),
                    _buildOrderSummary(context),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOriginSection(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Origem do Pedido',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: SegmentedButton<bool>(
                style: ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Lista'),
                    icon: Icon(Icons.store_outlined),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Novo'),
                    icon: Icon(Icons.add_outlined),
                  ),
                ],
                selected: {_createNewOrigin},
                onSelectionChanged: (value) {
                  setState(() => _createNewOrigin = value.first);
                },
              ),
            ),
            const SizedBox(height: 8),
            if (_createNewOrigin)
              Column(
                children: [
                  TextFormField(
                    scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
                    controller: _newOriginController,
                    decoration: InputDecoration(
                      labelText: 'Nome da origem',
                      hintText: 'Ex: Fornecedor ABC, Mercado XYZ',
                      prefixIcon: const Icon(Icons.business_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    validator: (value) {
                      if (_createNewOrigin) return _required(value, 'Origem');
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
                    controller: _newOriginIconController,
                    decoration: InputDecoration(
                      labelText: 'URL do ícone (opcional)',
                      hintText: 'https://example.com/logo.png',
                      prefixIcon: const Icon(Icons.image_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.url,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_newOriginIconController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildOriginIconPreview(),
                  ],
                ],
              )
            else
              _buildOriginChips(context),
          ],
        ),
      ),
    );
  }

  Widget _buildOriginIconPreview() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _newOriginIconController,
      builder: (context, value, _) {
        if (value.text.trim().isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
          child: Row(
            children: [
              const Text('Prévia: ', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 8),
              _OriginIcon(iconUrl: value.text.trim(), size: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOriginChips(BuildContext context) {
    if (widget.origins.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Nenhuma origem cadastrada',
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: widget.origins
          .map(
            (origin) => FilterChip(
              avatar: _OriginIcon(iconUrl: origin.iconUrl, size: 16),
              label: Text(origin.name, style: const TextStyle(fontSize: 13)),
              selected: _selectedOrigin?.name == origin.name,
              onSelected: (selected) {
                setState(() => _selectedOrigin = selected ? origin : null);
              },
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildProductSelector(BuildContext context, int itemIndex) {
    final draft = _itemDrafts[itemIndex];
    final isPlaceholderSelected = draft.productSku == _productPlaceholderSku;
    Product? selectedProduct;
    try {
      selectedProduct = _products.firstWhere((p) => p.sku == draft.productSku);
    } catch (_) {
      selectedProduct = null;
    }

    // Produtos já selecionados em outros itens
    final selectedSkus = {
      for (var i = 0; i < _itemDrafts.length; i++)
        if (i != itemIndex &&
            _itemDrafts[i].productSku != _productPlaceholderSku)
          _itemDrafts[i].productSku,
    };

    return GestureDetector(
      onTap: () =>
          _openProductSelectionDialog(context, itemIndex, selectedSkus),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Row(
          children: [
            if (selectedProduct != null)
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: _ProductImageThumbnail(
                  imageUrl: selectedProduct.imageUrl,
                ),
              ),
            Expanded(
              child: selectedProduct == null
                  ? Text(
                      isPlaceholderSelected
                          ? 'Selecione um produto'
                          : 'Produto indisponível',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selectedProduct.description,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          selectedProduct.sku,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_drop_down,
              color: Theme.of(context).colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openProductSelectionDialog(
    BuildContext context,
    int itemIndex,
    Set<String> selectedSkus,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ProductSelectionDialog(
        products: _products,
        selectedSku: _itemDrafts[itemIndex].productSku,
        excludeSkus: selectedSkus,
        onAddProductRequested: _handleAddProductFromSelection,
      ),
    );

    if (result != null) {
      setState(() => _itemDrafts[itemIndex].productSku = result);
    }
  }

  Future<Product?> _handleAddProductFromSelection() async {
    final created = await widget.onAddProductRequested();
    if (created == null) {
      return null;
    }

    if (_products.any((product) => product.sku == created.sku)) {
      return created;
    }

    setState(() {
      _products = [..._products, created];
    });

    return created;
  }

  Widget _buildItemsSection(BuildContext context, bool isWide) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'Itens do Pedido',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_itemDrafts.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_itemDrafts.length} item${_itemDrafts.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ..._buildItemDraftWidgets(context),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.tertiaryContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildItemDraftWidgets(BuildContext context) {
    return [
      for (var index = 0; index < _itemDrafts.length; index++)
        _buildItemCard(context, index),
    ];
  }

  Widget _buildItemCard(BuildContext context, int index) {
    final draft = _itemDrafts[index];
    final isSmallScreen = MediaQuery.sizeOf(context).width < 600;
    final quantity = int.tryParse(draft.quantityController.text) ?? 0;
    final cost =
        double.tryParse(draft.costController.text.replaceAll(',', '.')) ?? 0;
    final itemTotal = quantity * cost;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Item ${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                if (itemTotal > 0)
                  Text(
                    'R\$ ${itemTotal.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                const SizedBox(width: 8),
                if (_itemDrafts.length > 1)
                  IconButton(
                    onPressed: () => _removeItem(index),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remover item',
                    iconSize: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildProductSelector(context, index),
            const SizedBox(height: 10),
            if (isSmallScreen)
              Column(
                children: [
                  TextFormField(
                    scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
                    controller: draft.quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Qtd',
                      hintText: '1',
                      prefixIcon: const Icon(
                        Icons.format_list_numbered_outlined,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                    ),
                    validator: (value) {
                      if (_required(value, 'Quantidade') != null) {
                        return _required(value, 'Quantidade');
                      }
                      final qty = int.tryParse(value!.trim());
                      if (qty == null || qty <= 0) return 'Inválido';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
                    controller: draft.costController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Custo unitário',
                      hintText: '0,00',
                      prefixIcon: const Icon(Icons.attach_money_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                    ),
                    validator: (value) {
                      if (_required(value, 'Custo') != null) {
                        return _required(value, 'Custo');
                      }
                      final c = double.tryParse(
                        value!.trim().replaceAll(',', '.'),
                      );
                      if (c == null || c < 0) return 'Inválido';
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
                      controller: draft.quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Qtd',
                        hintText: '1',
                        prefixIcon: const Icon(
                          Icons.format_list_numbered_outlined,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                      validator: (value) {
                        if (_required(value, 'Quantidade') != null) {
                          return _required(value, 'Quantidade');
                        }
                        final qty = int.tryParse(value!.trim());
                        if (qty == null || qty <= 0) return 'Inválido';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
                      controller: draft.costController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Custo unitário',
                        hintText: '0,00',
                        prefixIcon: const Icon(Icons.attach_money_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                      validator: (value) {
                        if (_required(value, 'Custo') != null) {
                          return _required(value, 'Custo');
                        }
                        final c = double.tryParse(
                          value!.trim().replaceAll(',', '.'),
                        );
                        if (c == null || c < 0) return 'Inválido';
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            _buildItemDatePicker(context, index),
          ],
        ),
      ),
    );
  }

  Widget _buildItemDatePicker(BuildContext context, int index) {
    final draft = _itemDrafts[index];
    final now = DateTime.now();
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: TextFormField(
              scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
              controller: draft.expirationDateController,
              keyboardType: TextInputType.datetime,
              inputFormatters: _dateInputFormatters(),
              decoration: InputDecoration(
                labelText: 'Validade',
                hintText: 'dd/mm/aaaa',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  draft.expirationDate = _parseDateInput(
                    value,
                    minDate: DateTime(now.year, now.month, now.day),
                    maxDate: DateTime(now.year + 20),
                  );
                });
              },
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) {
                  return 'Informe a validade';
                }
                final parsed = _parseDateInput(
                  text,
                  minDate: DateTime(now.year, now.month, now.day),
                  maxDate: DateTime(now.year + 20),
                );
                if (parsed == null) {
                  return 'Use o formato dd/mm/aaaa';
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          height: 48,
          child: OutlinedButton(
            onPressed: () => _pickDateForItem(index),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Icon(
              Icons.calendar_month_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary(BuildContext context) {
    double totalValue = 0;
    int totalItems = 0;

    for (final draft in _itemDrafts) {
      final qty = int.tryParse(draft.quantityController.text.trim()) ?? 0;
      final cost =
          double.tryParse(
            draft.costController.text.trim().replaceAll(',', '.'),
          ) ??
          0;
      totalItems += qty;
      totalValue += qty * cost;
    }

    return Card(
      elevation: 0,
      color: Theme.of(
        context,
      ).colorScheme.primaryContainer.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumo',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total de itens',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      totalItems.toString(),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Valor total',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      'R\$ ${totalValue.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _addItem() {
    setState(() {
      _itemDrafts.add(_OrderItemDraft(productSku: _productPlaceholderSku));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _itemDrafts[index].dispose();
      _itemDrafts.removeAt(index);
    });
  }

  Future<void> _pickDateForItem(int index) async {
    final now = DateTime.now();
    final current = _itemDrafts[index];
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 20),
      initialDate: current.expirationDate ?? now,
    );
    if (picked != null) {
      setState(() {
        current.expirationDate = picked;
        current.expirationDateController.text = _formatDate(picked);
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final origin = _createNewOrigin
        ? _newOriginController.text.trim()
        : (_selectedOrigin?.name ?? '').trim();

    final originIconUrl = _createNewOrigin
        ? (_newOriginIconController.text.trim().isEmpty
              ? null
              : _newOriginIconController.text.trim())
        : _selectedOrigin?.iconUrl;

    if (origin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe ou selecione a origem.')),
      );
      return;
    }

    final items = <_OrderItemFormData>[];
    for (final draft in _itemDrafts) {
      if (draft.productSku == _productPlaceholderSku) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione um produto válido para todos os itens.'),
          ),
        );
        return;
      }

      if (draft.expirationDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione a validade para todos os itens.'),
          ),
        );
        return;
      }

      items.add(
        _OrderItemFormData(
          productSku: draft.productSku,
          quantity: int.parse(draft.quantityController.text.trim()),
          costPerItem: double.parse(
            draft.costController.text.trim().replaceAll(',', '.'),
          ),
          expirationDate: draft.expirationDate!,
        ),
      );
    }

    Navigator.of(context).pop(
      _OrderFormData(
        origin: origin,
        originIconUrl: originIconUrl,
        items: items,
      ),
    );
  }
}

class _OrderItemDraft {
  _OrderItemDraft({
    required this.productSku,
    int initialQuantity = 1,
    double initialCostPerItem = 0,
    DateTime? initialExpirationDate,
  }) : expirationDate = initialExpirationDate,
       quantityController = TextEditingController(
         text: initialQuantity.toString(),
       ),
       costController = TextEditingController(
         text: initialCostPerItem <= 0
             ? ''
             : initialCostPerItem.toStringAsFixed(2),
       ),
       expirationDateController = TextEditingController(
         text: initialExpirationDate == null
             ? ''
             : _formatDate(initialExpirationDate),
       );

  String productSku;
  DateTime? expirationDate;
  final TextEditingController quantityController;
  final TextEditingController costController;
  final TextEditingController expirationDateController;

  void dispose() {
    quantityController.dispose();
    costController.dispose();
    expirationDateController.dispose();
  }
}

class _OriginIcon extends StatelessWidget {
  const _OriginIcon({this.iconUrl, required this.size});

  final String? iconUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = iconUrl?.trim() ?? '';
    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(size * 0.25),
        ),
        child: Icon(Icons.storefront_outlined, size: size * 0.55),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(Icons.broken_image_outlined, size: size * 0.55),
        ),
      ),
    );
  }
}

class _ProductImagePreview extends StatelessWidget {
  const _ProductImagePreview({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image_not_supported_outlined, size: 18),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          return Container(
            width: 64,
            height: 64,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined),
          );
        },
      ),
    );
  }
}

class _ProductImageThumbnail extends StatelessWidget {
  const _ProductImageThumbnail({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 18,
          color: Theme.of(context).colorScheme.outline,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

class _ProductSelectionDialog extends StatefulWidget {
  const _ProductSelectionDialog({
    required this.products,
    required this.selectedSku,
    required this.excludeSkus,
    required this.onAddProductRequested,
  });

  final List<Product> products;
  final String selectedSku;
  final Set<String> excludeSkus;
  final Future<Product?> Function() onAddProductRequested;

  @override
  State<_ProductSelectionDialog> createState() =>
      _ProductSelectionDialogState();
}

class _ProductSelectionDialogState extends State<_ProductSelectionDialog> {
  late TextEditingController _filterController;
  late List<Product> _filteredProducts;
  late List<Product> _products;

  @override
  void initState() {
    super.initState();
    _products = [...widget.products];
    _filterController = TextEditingController();
    _updateFilteredProducts();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _updateFilteredProducts() {
    final query = _filterController.text.toLowerCase().trim();
    _filteredProducts = _products
        .where(
          (product) =>
              !widget.excludeSkus.contains(product.sku) &&
              (query.isEmpty ||
                  product.sku.toLowerCase().contains(query) ||
                  product.description.toLowerCase().contains(query) ||
                  product.brand.toLowerCase().contains(query)),
        )
        .toList();
  }

  Future<void> _onAddProductPressed() async {
    final created = await widget.onAddProductRequested();
    if (!mounted) {
      return;
    }

    if (created != null && !_products.any((p) => p.sku == created.sku)) {
      _products = [..._products, created];
    }

    setState(() {
      _updateFilteredProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Selecionar Produto',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _onAddProductPressed,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Adicionar novo produto'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 220),
                  controller: _filterController,
                  decoration: InputDecoration(
                    hintText: 'Filtrar por SKU ou descrição',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(_updateFilteredProducts);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Nenhum produto disponível',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredProducts.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      final isSelected = product.sku == widget.selectedSku;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                                    .withValues(alpha: 0.3)
                              : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context, product.sku),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
                                    ),
                                    child: _ProductImageThumbnail(
                                      imageUrl: product.imageUrl,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          product.description,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              product.sku,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.labelSmall,
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.tertiaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${product.stock}un',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onTertiaryContainer,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

const double _calculatorDefaultIfoodRate = 0.12;
const double _calculatorDefaultPaymentRate = 0.032;
const double _calculatorDefaultOperationFixed = 2;
const double _calculatorDefaultMarginPercent = 20;
const String _calculatorIfoodRateKey = 'calculator_ifood_rate';
const String _calculatorPaymentRateKey = 'calculator_payment_rate';
const String _calculatorOperationFixedKey = 'calculator_operation_fixed';
const String _calculatorMarginKey = 'calculator_margin_percent';

class _CalculatorPricingConfig {
  const _CalculatorPricingConfig({
    required this.ifoodRate,
    required this.paymentRate,
    required this.operationFixed,
    required this.marginPercent,
  });

  final double ifoodRate;
  final double paymentRate;
  final double operationFixed;
  final double marginPercent;
}

Future<_CalculatorPricingConfig> _loadCalculatorPricingConfig() async {
  final prefs = await SharedPreferences.getInstance();
  return _CalculatorPricingConfig(
    ifoodRate:
        prefs.getDouble(_calculatorIfoodRateKey) ?? _calculatorDefaultIfoodRate,
    paymentRate:
        prefs.getDouble(_calculatorPaymentRateKey) ??
        _calculatorDefaultPaymentRate,
    operationFixed:
        prefs.getDouble(_calculatorOperationFixedKey) ??
        _calculatorDefaultOperationFixed,
    marginPercent:
        prefs.getDouble(_calculatorMarginKey) ??
        _calculatorDefaultMarginPercent,
  );
}

Future<void> _persistCalculatorMarginPercent(double marginPercent) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble(
    _calculatorMarginKey,
    marginPercent.clamp(0, 99.9).toDouble(),
  );
}

double _calculateSuggestedPriceFromCost(
  double cost,
  _CalculatorPricingConfig config,
) {
  if (cost <= 0 || config.operationFixed < 0) {
    return 0;
  }

  const operationReferencePrice = 20.0;
  final marginRate = (config.marginPercent / 100).clamp(0, 0.999).toDouble();
  final baseDenominator =
      1 - (marginRate + config.ifoodRate + config.paymentRate);
  final lowPriceDenominator =
      baseDenominator - (config.operationFixed / operationReferencePrice);

  final lowCandidate = lowPriceDenominator > 0
      ? (cost / lowPriceDenominator)
      : -1.0;
  final highCandidate = baseDenominator > 0
      ? ((cost + config.operationFixed) / baseDenominator)
      : -1.0;

  if (lowCandidate > 0 && lowCandidate < operationReferencePrice) {
    return lowCandidate;
  }
  if (highCandidate > 0 && highCandidate >= operationReferencePrice) {
    return highCandidate;
  }
  if (highCandidate > 0) {
    return highCandidate;
  }
  if (lowCandidate > 0) {
    return lowCandidate;
  }

  return 0;
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = date.year.toString();
  return '$day/$month/$year';
}

DateTime? _parseDateInput(String raw, {DateTime? minDate, DateTime? maxDate}) {
  final text = raw.trim();
  if (text.isEmpty) {
    return null;
  }

  final match = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(text);
  if (match == null) {
    return null;
  }

  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);

  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }

  final normalized = DateTime(parsed.year, parsed.month, parsed.day);
  if (minDate != null) {
    final min = DateTime(minDate.year, minDate.month, minDate.day);
    if (normalized.isBefore(min)) {
      return null;
    }
  }
  if (maxDate != null) {
    final max = DateTime(maxDate.year, maxDate.month, maxDate.day);
    if (normalized.isAfter(max)) {
      return null;
    }
  }

  return normalized;
}

List<TextInputFormatter> _dateInputFormatters() => [
  FilteringTextInputFormatter.allow(RegExp('[0-9/]')),
  LengthLimitingTextInputFormatter(10),
];

String? _required(String? value, String fieldName) {
  if (value == null || value.trim().isEmpty) {
    return '$fieldName e obrigatorio';
  }
  return null;
}

_ExpirationStatus _expirationStatus(
  DateTime? expirationDate,
  int stock,
  BuildContext context,
) {
  if (stock <= 0) {
    return _ExpirationStatus(
      'Estoque zerado',
      Theme.of(context).colorScheme.outline,
    );
  }

  if (expirationDate == null) {
    return _ExpirationStatus(
      'Sem validade',
      Theme.of(context).colorScheme.outline,
    );
  }

  final today = DateTime.now();
  final date = DateTime(
    expirationDate.year,
    expirationDate.month,
    expirationDate.day,
  );
  final todayDate = DateTime(today.year, today.month, today.day);
  final daysLeft = date.difference(todayDate).inDays;
  final warning = todayDate.add(const Duration(days: 30));
  final scheme = Theme.of(context).colorScheme;

  if (date.isBefore(todayDate)) {
    return _ExpirationStatus('${daysLeft.abs()}d vencido', scheme.error);
  }
  if (date.isAtSameMomentAs(todayDate)) {
    return _ExpirationStatus('Vence hoje', Colors.orange.shade800);
  }
  if (date.isBefore(warning) || date.isAtSameMomentAs(warning)) {
    return _ExpirationStatus('${daysLeft}d restantes', Colors.orange.shade800);
  }
  return _ExpirationStatus('${daysLeft}d restantes', scheme.primary);
}

class _ExpirationStatus {
  const _ExpirationStatus(this.label, this.color);

  final String label;
  final Color color;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({
    required this.isLoadingMore,
    required this.canLoadMore,
    required this.onLoadMore,
    required this.label,
  });

  final bool isLoadingMore;
  final bool canLoadMore;
  final Future<void> Function() onLoadMore;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Center(
        child: isLoadingMore
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : OutlinedButton.icon(
                onPressed: canLoadMore ? onLoadMore : null,
                icon: const Icon(Icons.expand_more, size: 16),
                label: Text(label),
              ),
      ),
    );
  }
}

class _ProductFormData {
  const _ProductFormData({
    required this.description,
    required this.imageUrl,
    required this.stock,
    required this.brand,
    required this.expirationDate,
  });

  final String description;
  final String imageUrl;
  final int stock;
  final String brand;
  final DateTime? expirationDate;
}

class _OrderFormData {
  const _OrderFormData({
    required this.origin,
    required this.items,
    this.originIconUrl,
  });

  final String origin;
  final String? originIconUrl;
  final List<_OrderItemFormData> items;
}

class _OrderItemFormData {
  const _OrderItemFormData({
    required this.productSku,
    required this.quantity,
    required this.costPerItem,
    required this.expirationDate,
  });

  final String productSku;
  final int quantity;
  final double costPerItem;
  final DateTime expirationDate;
}

class _ProductOrderEntry {
  const _ProductOrderEntry({
    required this.orderId,
    required this.registeredAt,
    required this.origin,
    required this.originIconUrl,
    required this.quantity,
    required this.costPerItem,
    required this.lineTotal,
  });

  final String orderId;
  final DateTime registeredAt;
  final String origin;
  final String? originIconUrl;
  final int quantity;
  final double costPerItem;
  final double lineTotal;
}

enum _ProductAction { updateStock, updateExpiration, edit, delete }

enum _OrderAction { edit, delete }

enum _ExpirationFilter { all, warning, expired }

enum _ProductSortOrder { alphabetical, expiration, stock }

enum _CostHistoryWindow {
  oneMonth('1 mes'),
  threeMonths('3 meses'),
  sixMonths('6 meses'),
  oneYear('1 ano'),
  all('Tudo');

  const _CostHistoryWindow(this.label);
  final String label;
}

double _dialogHorizontalInset(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < 420) {
    return 12;
  }
  if (width < 600) {
    return 20;
  }
  return 40;
}

EdgeInsets _dialogInsetPadding(BuildContext context) {
  return EdgeInsets.symmetric(
    horizontal: _dialogHorizontalInset(context),
    vertical: 24,
  );
}

double _dialogMaxWidth(BuildContext context, double preferredMaxWidth) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final availableWidth =
      screenWidth - (_dialogHorizontalInset(context) * 2) - 24;
  return min(preferredMaxWidth, max(availableWidth, 280));
}

class _QuickStatChip extends StatelessWidget {
  const _QuickStatChip({
    required this.icon,
    required this.label,
    this.expand = false,
    this.minHeight,
  });

  final IconData icon;
  final String label;
  final bool expand;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: expand ? double.infinity : null,
      constraints: minHeight == null
          ? null
          : BoxConstraints(minHeight: minHeight!),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          if (expand)
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            )
          else
            Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _CostWindowButton extends StatelessWidget {
  const _CostWindowButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 34,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
          ),
          backgroundColor: selected
              ? scheme.primaryContainer.withValues(alpha: 0.65)
              : scheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onPressed,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected ? scheme.primary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactMetricChip extends StatelessWidget {
  const _CompactMetricChip({
    this.icon,
    required this.title,
    required this.value,
    this.secondaryValue,
    this.valueIcon,
    this.secondaryValueIcon,
    this.highlighted = false,
    this.expand = false,
  });

  final IconData? icon;
  final String title;
  final String value;
  final String? secondaryValue;
  final IconData? valueIcon;
  final IconData? secondaryValueIcon;
  final bool highlighted;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = highlighted
        ? scheme.primaryContainer.withValues(alpha: 0.55)
        : scheme.surface;

    return Container(
      width: expand ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: background,
        border: Border.all(
          color: highlighted ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 13,
              color: highlighted ? scheme.primary : scheme.outline,
            ),
            const SizedBox(width: 5),
          ],
          if (expand)
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: scheme.outline),
              ),
            )
          else
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.outline),
            ),
          const SizedBox(width: 4),
          if (secondaryValue != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MetricValueWithIcon(
                  value: value,
                  icon: valueIcon,
                  highlighted: highlighted,
                ),
                const SizedBox(width: 8),
                _MetricValueWithIcon(
                  value: secondaryValue!,
                  icon: secondaryValueIcon,
                  highlighted: highlighted,
                  subdued: true,
                ),
              ],
            )
          else
            Text(
              value,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: highlighted ? scheme.primary : scheme.onSurface,
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricValueWithIcon extends StatelessWidget {
  const _MetricValueWithIcon({
    required this.value,
    required this.highlighted,
    this.icon,
    this.subdued = false,
  });

  final String value;
  final IconData? icon;
  final bool highlighted;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = highlighted ? scheme.primary : scheme.onSurface;
    final valueColor = subdued
        ? (highlighted
              ? scheme.primary.withValues(alpha: 0.72)
              : scheme.outline)
        : baseColor;

    return SizedBox(
      width: 96,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: valueColor),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: subdued ? FontWeight.w600 : FontWeight.w800,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
