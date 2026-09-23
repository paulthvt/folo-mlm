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
