import '../../../../core/usecases/usecase.dart';
import '../entities/order.dart';
import '../repositories/order_repository.dart';

class ListOrders implements UseCase<Future<List<Order>>, NoParams> {
  ListOrders(this._repository);

  final OrderRepository _repository;

  @override
  Future<List<Order>> call(NoParams params) {
    return _repository.listOrders();
  }
}
