import '../../../../core/usecases/usecase.dart';
import '../repositories/product_repository.dart';

class AddBrand implements UseCase<Future<void>, String> {
  AddBrand(this._repository);

  final ProductRepository _repository;

  @override
  Future<void> call(String params) {
    return _repository.addBrand(params);
  }
}
