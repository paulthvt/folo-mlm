import 'package:loomia/features/contacts/domain/person.dart';

/// What an entry records. [stage] entries are written by the database when a
/// person changes stage, [step] entries when a workflow step is ticked; the
/// user writes the others.
enum ActivityKind {
  note,
  call,
  message,
  order,
  meeting,
  stage,
  step;

  /// Offered in Log something.
  bool get byUser => this != stage && this != step;
}

/// One thing in a person's history. Never edited, only deleted.
class Activity {
  Activity({
    required this.id,
    required this.personId,
    required this.kind,
    required this.happenedOn,
    required this.createdAt,
    this.text,
    this.stage,
  }) : assert(
         kind == ActivityKind.stage
             ? stage != null && text == null
             : stage == null && text != null && text.trim().isNotEmpty,
         'A stage entry has a stage and no text; any other has non-blank text and no stage',
       );

  final String id;
  final String personId;
  final ActivityKind kind;

  /// The calendar day it happened, as local midnight.
  final DateTime happenedOn;

  /// What happened; null only on stage entries.
  final String? text;

  /// The stage moved to; stage entries only.
  final Stage? stage;
  final DateTime createdAt;

  /// The day it shows under. A stage entry's [happenedOn] is the server's UTC
  /// day, and "today" is decided on the device, so it uses the local day of
  /// [createdAt].
  DateTime get day {
    if (kind != ActivityKind.stage) return happenedOn;
    final local = createdAt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

/// What Log something collects. Never a stage entry.
typedef ActivityDraft = ({ActivityKind kind, DateTime happenedOn, String text});
