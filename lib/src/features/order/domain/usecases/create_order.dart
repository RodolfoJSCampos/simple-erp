import '../../../../core/usecases/usecase.dart';
import '../entities/order.dart';
import '../repositories/order_repository.dart';

class CreateOrder implements UseCase<Future<void>, Order> {
  CreateOrder(this._repository);

  final OrderRepository _repository;

  @override
  Future<void> call(Order params) {
    return _repository.saveOrder(params);
  }
}
