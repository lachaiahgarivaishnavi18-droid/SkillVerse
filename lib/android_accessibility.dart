part of 'main.dart';

bool _largeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) >= 20;

ThemeData _skillVerseTheme({required bool highContrast}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _blue,
    contrastLevel: highContrast ? 1 : .35,
  );
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: _pageBackground,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    appBarTheme: const AppBarTheme(
      backgroundColor: _pageBackground,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      errorMaxLines: 4,
      helperMaxLines: 4,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline),
      ),
    ),
  );
  return theme.copyWith(
    focusColor: scheme.primary.withValues(alpha: .20),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: _AndroidPageTransitions()},
    ),
  );
}

class _AndroidPageTransitions extends PageTransitionsBuilder {
  const _AndroidPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => MediaQuery.disableAnimationsOf(context)
      ? child
      : const PredictiveBackPageTransitionsBuilder().buildTransitions(
          route,
          context,
          animation,
          secondaryAnimation,
          child,
        );
}

AnimationStyle? _sheetMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ? AnimationStyle.noAnimation : null;

class _GuardUnsaved extends StatefulWidget {
  const _GuardUnsaved({
    required this.dirty,
    required this.child,
    this.busy = false,
    this.leaveLabel = 'Discard changes',
    this.message = 'Your unsaved changes will be lost.',
    this.beforeLeave,
  });

  final bool dirty;
  final bool busy;
  final Widget child;
  final String leaveLabel;
  final String message;
  final Future<void> Function()? beforeLeave;

  @override
  State<_GuardUnsaved> createState() => _GuardUnsavedState();
}

class _GuardUnsavedState extends State<_GuardUnsaved> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: !widget.busy && !widget.dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop || !widget.dirty || widget.busy || _open) return;
      _open = true;
      final leave = await showDialog<bool>(
        context: context,
        animationStyle: _sheetMotion(context),
        builder: (dialog) => AlertDialog(
          scrollable: true,
          title: const Text('Leave this screen?'),
          content: Text(widget.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(widget.leaveLabel),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (leave == true) {
        try {
          await widget.beforeLeave?.call();
          if (context.mounted) Navigator.of(context).pop();
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not save your changes. Try leaving again.',
                ),
              ),
            );
          }
        }
      }
      _open = false;
    },
    child: widget.child,
  );
}

String _authMessage(Object error, String fallback) {
  if (error is SocketException || error is TimeoutException) {
    return 'Check your internet connection and try again.';
  }
  if (error is AuthException) {
    return switch (error.code) {
      'invalid_credentials' => 'Check your email and password, then try again.',
      'email_not_confirmed' =>
        'Confirm your email using the link in your inbox, then sign in.',
      'email_exists' || 'user_already_exists' =>
        'An account already uses this email. Try signing in.',
      'over_email_send_rate_limit' || 'over_request_rate_limit' =>
        'Too many attempts. Wait a moment and try again.',
      'weak_password' => 'Choose a stronger password and try again.',
      _ => fallback,
    };
  }
  if (error is StateError &&
      {
        'No account found for this email.',
        'Incorrect password.',
        'Incorrect email or current password.',
        'An account already exists for this email.',
      }.contains(error.message)) {
    return '${error.message} Check your details and try again.';
  }
  return fallback;
}

class _PasswordVisibility extends StatelessWidget {
  const _PasswordVisibility({
    required this.visible,
    required this.field,
    required this.onPressed,
  });

  final bool visible;
  final String field;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final action = visible ? 'Hide $field' : 'Show $field';
    return Tooltip(
      message: action,
      excludeFromSemantics: true,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          visible ? Icons.visibility_off : Icons.visibility,
          semanticLabel: action,
        ),
      ),
    );
  }
}
