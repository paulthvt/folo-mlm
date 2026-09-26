import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/app.dart';
import 'package:folo/core/supabase/supabase_config.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restores a stored session before the first frame, so the router's first
  // redirect already knows the answer and no auth screen flashes on launch.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  runApp(const ProviderScope(child: FoloApp()));
}
