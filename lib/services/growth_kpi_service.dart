import 'package:cloud_functions/cloud_functions.dart';

class GrowthKpiService {
  final FirebaseFunctions _functions;

  GrowthKpiService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  Future<Map<String, dynamic>> getEngineKpis(String engine) async {
    final callable = _functions.httpsCallable('getGrowthKpis');
    final res = await callable.call({'engine': engine});
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  Future<void> logAnalyticsEvent({
    required String type,
    String? shortname,
    Map<String, dynamic>? meta,
  }) async {
    final callable = _functions.httpsCallable('logAnalyticsEvent');
    await callable.call({
      'type': type,
      if (shortname != null) 'shortname': shortname,
      if (meta != null) 'meta': meta,
    });
  }
}

