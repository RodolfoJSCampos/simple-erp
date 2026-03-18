import '../../../../core/usecases/usecase.dart';
import '../entities/order_page.dart';
import '../repositories/order_repository.dart';

class ListOrdersPage
    implements UseCase<Future<OrderPage>, ListOrdersPageParams> {
  ListOrdersPage(this._repository);

  final OrderRepository _repository;

  @override
  Future<OrderPage> call(ListOrdersPageParams params) {
    return _repository.listOrdersPage(
      limit: params.limit,
      afterCursor: params.afterCursor,
    );
  }
}

class ListOrdersPageParams {
  const ListOrdersPageParams({required this.limit, this.afterCursor});

  final int limit;
  final String? afterCursor;
}
