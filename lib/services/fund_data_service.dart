import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fund_item.dart';

class FundDataService {
  FundDataService(this.client);

  final SupabaseClient client;

  Future<List<FundItem>> loadFundItems() async {
    try {
      final response = await client
          .from('fund_items')
          .select('id, title, category, amount, status, notes, updated_at')
          .order('updated_at', ascending: false);

      final rows = (response as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      return rows.map(FundItem.fromMap).toList();
    } catch (_) {
      return const <FundItem>[];
    }
  }
}
