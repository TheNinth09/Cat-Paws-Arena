class PurchaseResult {
  const PurchaseResult.success([this.message = '']) : success = true;

  const PurchaseResult.failure(this.message) : success = false;

  final bool success;
  final String message;
}

abstract class PurchaseService {
  Future<PurchaseResult> purchase(String productId);
}

class UnavailablePurchaseService implements PurchaseService {
  const UnavailablePurchaseService();

  @override
  Future<PurchaseResult> purchase(String productId) async =>
      const PurchaseResult.failure('Achizițiile nu sunt disponibile încă.');
}
