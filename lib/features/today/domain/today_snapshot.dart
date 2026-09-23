/// One person worth a message today, and the reason why.
typedef TodaySuggestion = ({
  String name,
  String reason,

  /// Set only when a real date drives the suggestion — a birthday, a promised
  /// call-back. Renders as the accent chip.
  String? dateLabel,
});

/// A count plus the reason it matters.
typedef TodayStat = ({String label, String value, String? note});

/// Something that already happened.
typedef TodayActivity = ({String title, String meta});

/// The user's own intent for the month.
typedef TodayGoal = ({
  String title,
  int value,
  int target,
  String pace,
  bool behindPace,
  String timeLeft,
});

/// Everything the Today screen renders. The screen is a pure function of this,
/// so it can be previewed and tested without a repository.
class TodaySnapshot {
  const TodaySnapshot({
    required this.greeting,
    required this.dateLabel,
    required this.heroSentence,
    required this.progress,
    required this.progressLabel,
    required this.effortLabel,
    required this.suggestions,
    required this.goal,
    required this.stats,
    required this.recent,
  });

  /// "Good morning, Pauline".
  final String greeting;

  /// "Monday 22 September".
  final String dateLabel;

  /// A sentence, never a number, so it cannot read as a quota.
  final String heroSentence;

  /// 0–1, how far through today's suggestions the user is.
  final double progress;

  /// "1 of 4 done".
  final String progressLabel;

  /// Effort in minutes, never a percentage of a target.
  final String effortLabel;

  /// Capped at ~5 on mobile (design principle #3).
  final List<TodaySuggestion> suggestions;

  final TodayGoal goal;
  final List<TodayStat> stats;

  /// Shown in the desktop right column only.
  final List<TodayActivity> recent;
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
