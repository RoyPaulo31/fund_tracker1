import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/fund_tracker_app.dart';

Future<void> main() async {
  // GitHub Copilot (GPT-5.3-Codex)
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cuaduhsxecopgdqjphav.supabase.co',
    anonKey: 'sb_publishable_Gja9VahCmTvaZdQNlJ-sMg_SJrdHEgv',
  );

  runApp(const FundTrackerApp());
}
