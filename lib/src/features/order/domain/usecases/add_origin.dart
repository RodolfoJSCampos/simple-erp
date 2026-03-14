import '../../../../core/usecases/usecase.dart';
import '../entities/order_origin.dart';
import '../repositories/order_repository.dart';

class AddOrigin implements UseCase<Future<void>, OrderOrigin> {
  AddOrigin(this._repository);

  final OrderRepository _repository;

  @override
  Future<void> call(OrderOrigin params) {
    return _repository.addOrigin(params);
  }
}
