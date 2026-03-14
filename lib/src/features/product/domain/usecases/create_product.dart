import '../../../../core/usecases/usecase.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

class CreateProduct implements UseCase<Future<void>, Product> {
  CreateProduct(this._repository);

  final ProductRepository _repository;

  @override
  Future<void> call(Product params) {
    return _repository.saveProduct(params);
  }
}
