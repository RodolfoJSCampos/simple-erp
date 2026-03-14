import 'package:flutter/material.dart';

import '../features/dashboard/presentation/pages/dashboard_page.dart';
import 'dependencies.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple ERP',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: DashboardPage(
        productController: dependencies.productController,
        orderController: dependencies.orderController,
        usingFirebase: dependencies.usingFirebase,
      ),
    );
  }
}
