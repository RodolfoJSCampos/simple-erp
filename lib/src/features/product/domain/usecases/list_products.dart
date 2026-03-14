import '../../../../core/usecases/usecase.dart';
import '../entities/product.dart';
import '../repositories/product_repository.dart';

class ListProducts implements UseCase<Future<List<Product>>, NoParams> {
  ListProducts(this._repository);

  final ProductRepository _repository;

  @override
  Future<List<Product>> call(NoParams params) {
    return _repository.listProducts();
  }
}
