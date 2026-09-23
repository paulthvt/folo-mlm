import 'package:flutter_test/flutter_test.dart';
import 'package:folo/core/supabase/supabase_config.dart';

void main() {
  test('url points at the Folo project', () {
    expect(SupabaseConfig.url, 'https://cskjeqspecsyqioietrj.supabase.co');
  });

  test('the committed key is a publishable key, never a secret', () {
    expect(SupabaseConfig.publishableKey, startsWith('sb_publishable_'));
    // A service-role or legacy anon key is a JWT: three dot-separated parts.
    expect(SupabaseConfig.publishableKey.split('.').length, 1);
    expect(SupabaseConfig.publishableKey, isNot(contains('service_role')));
  });

  test('the redirect url matches the registered deep link', () {
    expect(SupabaseConfig.redirectUrl, 'io.supabase.folo://login-callback/');
  });
}
