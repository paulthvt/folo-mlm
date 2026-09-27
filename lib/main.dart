import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/app.dart';
import 'package:folo/core/supabase/supabase_config.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Committed on purpose: a DSN can only send events, and ships inside every
/// binary anyway.
const _sentryDsn =
    'https://35d8f6322bf91e8d854d0d247867ab97@o4512160213499904.ingest.de.sentry.io/4512160219398224';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      // An empty DSN turns the SDK off: debug and profile builds report to the
      // console only. PII stays off (the default), so no email or IP is sent.
      // ponytail: web stack traces stay minified; upload source maps with
      // sentry_dart_plugin once web has testers.
      options.dsn = kReleaseMode ? _sentryDsn : '';
    },
    appRunner: () async {
      // Restores a stored session before the first frame, so the router's
      // first redirect already knows the answer and no auth screen flashes on
      // launch.
      await Supabase.initialize(
        url: SupabaseConfig.url,
        publishableKey: SupabaseConfig.publishableKey,
      );
      runApp(const ProviderScope(child: FoloApp()));
    },
  );
}
