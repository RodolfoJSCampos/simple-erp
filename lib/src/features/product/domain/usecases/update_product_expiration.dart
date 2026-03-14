import '../../../../core/usecases/usecase.dart';
import '../repositories/product_repository.dart';

class UpdateProductExpirationParams {
  const UpdateProductExpirationParams({
    required this.sku,
    required this.newExpirationDate,
  });

  final String sku;
  final DateTime newExpirationDate;
}

class UpdateProductExpiration
    implements UseCase<Future<void>, UpdateProductExpirationParams> {
  UpdateProductExpiration(this._repository);

  final ProductRepository _repository;

  @override
  Future<void> call(UpdateProductExpirationParams params) {
    return _repository.updateExpirationDate(
      params.sku,
      params.newExpirationDate,
    );
  }
}
