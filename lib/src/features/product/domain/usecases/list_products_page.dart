import '../../../../core/usecases/usecase.dart';
import '../entities/product_page.dart';
import '../repositories/product_repository.dart';

class ListProductsPage
    implements UseCase<Future<ProductPage>, ListProductsPageParams> {
  ListProductsPage(this._repository);

  final ProductRepository _repository;

  @override
  Future<ProductPage> call(ListProductsPageParams params) {
    return _repository.listProductsPage(
      limit: params.limit,
      afterSku: params.afterSku,
    );
  }
}

class ListProductsPageParams {
  const ListProductsPageParams({required this.limit, this.afterSku});

  final int limit;
  final String? afterSku;
}
