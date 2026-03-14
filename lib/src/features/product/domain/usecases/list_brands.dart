import '../../../../core/usecases/usecase.dart';
import '../repositories/product_repository.dart';

class ListBrands implements UseCase<Future<List<String>>, NoParams> {
  ListBrands(this._repository);

  final ProductRepository _repository;

  @override
  Future<List<String>> call(NoParams params) {
    return _repository.listBrands();
  }
}
