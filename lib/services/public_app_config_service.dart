import 'package:cloud_functions/cloud_functions.dart';

class PublicAppConfig {
  const PublicAppConfig({
    required this.stripePublishableKey,
    required this.stripeMerchantDisplayName,
  });

  final String stripePublishableKey;
  final String stripeMerchantDisplayName;
}

class PublicAppConfigService {
  PublicAppConfigService({FirebaseFunctions? functions}) : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<PublicAppConfig?> fetch() async {
    try {
      final callable = _functions.httpsCallable('getPublicAppConfig');
      final res = await callable.call();
      final data = Map<String, dynamic>.from(res.data as Map);
      final key = (data['stripePublishableKey'] as String?)?.trim() ?? '';
      final merchant = (data['stripeMerchantDisplayName'] as String?)?.trim() ?? 'Sub67';
      if (key.isEmpty) return null;
      return PublicAppConfig(stripePublishableKey: key, stripeMerchantDisplayName: merchant);
    } catch (_) {
      return null;
    }
  }
}

