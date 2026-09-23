import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The initialised client. `Supabase.initialize` runs in `main()`, so reading
/// this provider before that completes is a programming error, not a state to
/// handle.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);
