import '../../../../core/usecases/usecase.dart';
import '../repositories/product_repository.dart';

class UpdateProductStockParams {
  const UpdateProductStockParams({required this.sku, required this.newStock});

  final String sku;
  final int newStock;
}

class UpdateProductStock
    implements UseCase<Future<void>, UpdateProductStockParams> {
  UpdateProductStock(this._repository);

  final ProductRepository _repository;

  @override
  Future<void> call(UpdateProductStockParams params) {
    return _repository.updateStock(params.sku, params.newStock);
  }
}
