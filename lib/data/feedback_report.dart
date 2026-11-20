import 'package:flutter/services.dart';

enum FeedbackKind {
  content('Course or question content'),
  appBug('App bug'),
  firstLesson('First-lesson observation'),
  diagnostics('Crash diagnostics');

  const FeedbackKind(this.label);
  final String label;
}

enum DiagnosticSource { framework, dart }

class AppBuild {
  const AppBuild(this.version, this.number);

  final String version;
  final String number;

  static const _channel = MethodChannel('skillverse/build');

  static Future<AppBuild> read() async {
    try {
      final values = await _channel.invokeMapMethod<String, String>('info');
      if (values != null) return AppBuild(values['version']!, values['build']!);
    } on PlatformException {
      // Flutter build flags below are also available on non-Android targets.
    } on MissingPluginException {
      // The Android package manager channel is unavailable.
    }
    return const AppBuild(
      String.fromEnvironment('FLUTTER_BUILD_NAME', defaultValue: 'Unavailable'),
      String.fromEnvironment(
        'FLUTTER_BUILD_NUMBER',
        defaultValue: 'Unavailable',
      ),
    );
  }
}

String buildFeedbackReport({
  required FeedbackKind kind,
  required AppBuild build,
  required String description,
  String? contentId,
  Map<DiagnosticSource, int> diagnostics = const {},
}) {
  return [
    'Skillverse feedback',
    'Type: ${kind.label}',
    'App version: ${build.version}',
    'Build: ${build.number}',
    if (contentId != null) 'Content ID: $contentId',
    if (kind == FeedbackKind.diagnostics)
      for (final source in DiagnosticSource.values)
        '${source == DiagnosticSource.framework ? 'Flutter framework errors' : 'Unhandled Dart errors'}: ${diagnostics[source] ?? 0}',
    if (description.trim().isNotEmpty) ...['', description.trim()],
  ].join('\n');
}
