import '../../../../core/usecases/usecase.dart';
import '../entities/product_cost.dart';
import '../repositories/product_repository.dart';

class RegisterProductCostParams {
  const RegisterProductCostParams({required this.sku, required this.cost});

  final String sku;
  final ProductCost cost;
}

class RegisterProductCost
    implements UseCase<Future<void>, RegisterProductCostParams> {
  RegisterProductCost(this._repository);

  final ProductRepository _repository;

  @override
  Future<void> call(RegisterProductCostParams params) {
    return _repository.addCostToProduct(params.sku, params.cost);
  }
}
