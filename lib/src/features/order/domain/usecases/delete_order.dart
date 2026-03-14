import '../../../../core/usecases/usecase.dart';
import '../repositories/order_repository.dart';

class DeleteOrder implements UseCase<Future<void>, String> {
  DeleteOrder(this._repository);

  final OrderRepository _repository;

  @override
  Future<void> call(String params) {
    return _repository.deleteOrder(params);
  }
}
