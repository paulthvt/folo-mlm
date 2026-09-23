import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Goes back one screen.
///
/// Pops when there is something to pop — the user navigated here — and
/// otherwise goes to [fallback], which is the case when they arrived by URL on
/// web or by a deep link. `context.go` alone would replace the whole stack and
/// leave the system back gesture with nothing to pop, which on Android exits
/// the app.
void backOr(BuildContext context, String fallback) =>
    context.canPop() ? context.pop() : context.go(fallback);
