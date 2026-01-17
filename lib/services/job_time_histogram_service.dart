import 'package:cloud_functions/cloud_functions.dart';

class JobTimeHistogramService {
  final FirebaseFunctions _functions;

  JobTimeHistogramService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Returns 96 buckets (15-minute blocks) for job start times.
  Future<List<int>> getStartHistogram({
    String scope = 'global',
    String? districtId,
  }) async {
    final callable = _functions.httpsCallable('getJobStartTimeHistogram');
    final res = await callable.call({
      'scope': scope,
      if (districtId != null) 'districtId': districtId,
    });

    final data = res.data;
    if (data is! Map) return List<int>.filled(96, 0);
    final buckets = data['buckets'];
    if (buckets is List) {
      final out = List<int>.filled(96, 0);
      for (int i = 0; i < out.length && i < buckets.length; i++) {
        final v = buckets[i];
        if (v is int) out[i] = v;
        if (v is num) out[i] = v.toInt();
      }
      return out;
    }
    return List<int>.filled(96, 0);
  }
}

