import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode, showCupertinoModalPopup;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// A calendar day no later than [last], as local midnight; null when
/// dismissed. The platform's own picker (docs/architecture.md → Design
/// packages): a wheel on iOS, the Material calendar elsewhere.
Future<DateTime?> pickDay(
  BuildContext context, {
  required DateTime initial,
  required DateTime last,
}) async {
  final picked = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
      ? await showCupertinoModalPopup<DateTime>(
          context: context,
          builder: (_) => _Wheel(initial: initial, last: last),
        )
      : await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(1900),
          lastDate: last,
        );
  return picked == null
      ? null
      : DateTime(picked.year, picked.month, picked.day);
}

class _Wheel extends StatefulWidget {
  const _Wheel({required this.initial, required this.last});

  final DateTime initial;
  final DateTime last;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late DateTime _day = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context, _day),
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
            SizedBox(
              // UIKit's standard picker height.
              height: 216,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: widget.initial,
                maximumDate: widget.last,
                onDateTimeChanged: (day) => _day = day,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
