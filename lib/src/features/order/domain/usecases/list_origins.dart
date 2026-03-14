import '../../../../core/usecases/usecase.dart';
import '../entities/order_origin.dart';
import '../repositories/order_repository.dart';

class ListOrigins implements UseCase<Future<List<OrderOrigin>>, NoParams> {
  ListOrigins(this._repository);

  final OrderRepository _repository;

  @override
  Future<List<OrderOrigin>> call(NoParams params) {
    return _repository.listOrigins();
  }
}
