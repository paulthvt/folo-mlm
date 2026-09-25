import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:folo/app/shell/app_shell.dart';
import 'package:folo/app/theme/app_spacing.dart';
import 'package:folo/core/layout/breakpoints.dart';
import 'package:folo/core/ui/action_item.dart';
import 'package:folo/core/ui/activity_item.dart';
import 'package:folo/core/ui/empty_state.dart';
import 'package:folo/core/ui/folo_top_bar.dart';
import 'package:folo/core/ui/goal_card.dart';
import 'package:folo/core/ui/section_header.dart';
import 'package:folo/core/ui/stat_tile.dart';
import 'package:folo/features/today/domain/today_snapshot.dart';
import 'package:folo/features/today/presentation/today_hero.dart';
import 'package:folo/l10n/app_localizations.dart';

/// What Today renders.
///
/// Sample data while there is no repository, so the screen can be walked through
/// end to end. Return null to see the empty state. When Supabase lands this
/// becomes the only line that changes.
final todaySnapshotProvider = Provider<TodaySnapshot?>((ref) => sampleToday);

/// The home. Everything else in the product is support (design principle #1).
class TodayPage extends ConsumerWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TodayView(
      snapshot: ref.watch(todaySnapshotProvider),
      // With a sidebar, Settings is its account block instead.
      accountAction: context.screenSize.usesSideNavigation
          ? null
          : const AccountButton(),
    );
  }
}

/// The screen as a pure function of [snapshot], so it can be previewed and
/// tested without providers.
class TodayView extends StatelessWidget {
  const TodayView({required this.snapshot, this.accountAction, super.key});

  final TodaySnapshot? snapshot;

  /// Top-bar entry to Settings, where there is no sidebar to hold it.
  final Widget? accountAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: switch (context.screenSize) {
          ScreenSize.desktop => _Desktop(snapshot: snapshot),
          ScreenSize.tablet || ScreenSize.mobile => _Column(
            snapshot: snapshot,
            accountAction: accountAction,
          ),
        },
      ),
    );
  }
}

/// Mobile and tablet: one column, the goal below the fold on purpose — it is
/// context, not the job.
class _Column extends StatelessWidget {
  const _Column({required this.snapshot, required this.accountAction});

  final TodaySnapshot? snapshot;
  final Widget? accountAction;

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            FoloTopBar(
              eyebrow: data?.dateLabel,
              title: data?.greeting ?? l10n.todayTitle,
              action: accountAction,
            ),
            if (data == null)
              const _UpToDate()
            else ...[
              TodayHero(
                eyebrow: l10n.todayTitle,
                headline: data.heroSentence,
                progress: data.progress,
                progressLabel: data.progressLabel,
                effortLabel: data.effortLabel,
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionHeader(title: l10n.todaySectionPriority),
              _Suggestions(data.suggestions),
              const SizedBox(height: AppSpacing.lg),
              SectionHeader(title: l10n.todaySectionThisMonth),
              _Goal(data.goal),
              const SizedBox(height: AppSpacing.ms),
              _Stats(data.stats, perRow: 2),
            ],
          ],
        ),
      ),
    );
  }
}

/// Desktop: the extra width buys one more priority item and moves context
/// beside the actions instead of below them. The right column exists only here.
class _Desktop extends StatelessWidget {
  const _Desktop({required this.snapshot});

  final TodaySnapshot? snapshot;

  /// Fixed, per `docs/design/responsive-design.md`. The left column takes the
  /// rest so a resized window narrows the actions, never the context.
  static const double _contextColumn = 400;

  @override
  Widget build(BuildContext context) {
    final data = snapshot;
    final l10n = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: Breakpoints.maxContentWidth,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FoloTopBar(
                eyebrow: data?.dateLabel,
                title: data?.greeting ?? l10n.todayTitle,
                large: true,
              ),
              if (data == null)
                const _UpToDate()
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TodayHero(
                            eyebrow: l10n.todayTitle,
                            headline: data.heroSentence,
                            progress: data.progress,
                            progressLabel: data.progressLabel,
                            effortLabel: data.effortLabel,
                            compact: false,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          SectionHeader(title: l10n.todaySectionPriority),
                          _Suggestions(data.suggestions),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xl),
                    SizedBox(
                      width: _contextColumn,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(title: l10n.todaySectionThisMonth),
                          _Goal(data.goal),
                          const SizedBox(height: AppSpacing.ms),
                          _Stats(data.stats, perRow: 2),
                          const SizedBox(height: AppSpacing.xl),
                          SectionHeader(title: l10n.todaySectionRecent),
                          for (final (index, activity) in data.recent.indexed)
                            ActivityItem(
                              title: activity.title,
                              meta: activity.meta,
                              showRailLine: index < data.recent.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions(this.suggestions);

  final List<TodaySuggestion> suggestions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (index, suggestion) in suggestions.indexed) ...[
          if (index > 0) const SizedBox(height: AppSpacing.ms),
          ActionItem(
            name: suggestion.name,
            reason: suggestion.reason,
            chip: suggestion.dateLabel == null
                ? null
                : DateChip(suggestion.dateLabel!),
          ),
        ],
      ],
    );
  }
}

class _Goal extends StatelessWidget {
  const _Goal(this.goal);

  final TodayGoal goal;

  @override
  Widget build(BuildContext context) {
    return GoalCard(
      title: goal.title,
      value: goal.value,
      target: goal.target,
      pace: goal.pace,
      behindPace: goal.behindPace,
      timeLeft: goal.timeLeft,
    );
  }
}

/// Two-up on mobile, two-up beside the goal on desktop. One tinted pair at most
/// per screen, so the tones alternate plain / secondary.
class _Stats extends StatelessWidget {
  const _Stats(this.stats, {required this.perRow});

  final List<TodayStat> stats;
  final int perRow;

  @override
  Widget build(BuildContext context) {
    final rows = <List<int>>[];
    for (var first = 0; first < stats.length; first += perRow) {
      final last = (first + perRow).clamp(0, stats.length);
      rows.add([for (var i = first; i < last; i++) i]);
    }

    return Column(
      children: [
        for (final (rowIndex, row) in rows.indexed) ...[
          if (rowIndex > 0) const SizedBox(height: AppSpacing.ms),
          // Tiles in a row match heights even when one note wraps.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (position, index) in row.indexed) ...[
                  if (position > 0) const SizedBox(width: AppSpacing.ms),
                  Expanded(
                    child: StatTile(
                      label: stats[index].label,
                      value: stats[index].value,
                      note: stats[index].note,
                      tone: index.isOdd ? StatTone.secondary : StatTone.plain,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _UpToDate extends StatelessWidget {
  const _UpToDate();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return EmptyState(
      icon: Icons.wb_twilight_rounded,
      title: l10n.todayEmptyTitle,
      body: l10n.todayEmptyBody,
    );
  }
}
