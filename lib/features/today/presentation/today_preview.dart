import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:folo/app/theme/app_theme.dart';
import 'package:folo/features/today/domain/today_snapshot.dart';
import 'package:folo/features/today/presentation/today_page.dart';

/// Today in both modes and both layouts, for `flutter widget-preview start`.
///
/// The sample book of contacts lives here and only here: the app itself has no
/// repository yet, so it renders the empty state (see [todaySnapshotProvider]).
/// Nothing in the app imports this file.
@Preview(group: 'Today', name: 'Mobile — light', size: Size(390, 844))
Widget todayMobileLight() => _app(AppTheme.light, sampleToday);

@Preview(group: 'Today', name: 'Mobile — dark', size: Size(390, 844))
Widget todayMobileDark() => _app(AppTheme.dark, sampleToday);

@Preview(group: 'Today', name: 'Desktop — light', size: Size(1440, 900))
Widget todayDesktopLight() => _app(AppTheme.light, sampleToday);

@Preview(group: 'Today', name: 'Desktop — dark', size: Size(1440, 900))
Widget todayDesktopDark() => _app(AppTheme.dark, sampleToday);

@Preview(group: 'Today', name: 'Empty — light', size: Size(390, 844))
Widget todayEmptyLight() => _app(AppTheme.light, null);

Widget _app(ThemeData theme, TodaySnapshot? snapshot) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: TodayView(snapshot: snapshot),
  );
}

/// The fictional book of contacts the design docs use, so previews and the Figma
/// screens read as the same product.
const sampleToday = TodaySnapshot(
  greeting: 'Good morning, Pauline',
  dateLabel: 'Monday 22 September',
  heroSentence: 'Three people are worth a message today',
  progress: 0.25,
  progressLabel: '1 of 4 done',
  effortLabel: 'about 15 minutes',
  suggestions: [
    (
      name: 'Marie Dupont',
      reason: 'Said she would decide after her holiday — she is back today',
      dateLabel: null,
    ),
    (
      name: 'Claire Besson',
      reason: 'Her refill usually runs out around now',
      dateLabel: null,
    ),
    (
      name: 'Lucas Morel',
      reason: 'Turns 42 tomorrow',
      dateLabel: 'Birthday tomorrow',
    ),
    (
      name: 'Amina Haddad',
      reason: 'Promised to call her back after the team evening',
      dateLabel: 'Promised Friday',
    ),
  ],
  goal: (
    title: 'New conversations',
    value: 24,
    target: 40,
    pace: 'Slightly behind pace',
    behindPace: true,
    timeLeft: '11 days left',
  ),
  stats: [
    (label: 'Followed up', value: '18', note: 'of 40 you aimed for'),
    (label: 'Waiting on you', value: '6', note: 'oldest is 9 days'),
  ],
  recent: [
    (title: 'Sophie Renard', meta: 'Yesterday · Message'),
    (title: 'Karim Benali', meta: '2 days ago · Call'),
    (title: 'Élodie Fabre', meta: '4 days ago · Coffee'),
  ],
);
