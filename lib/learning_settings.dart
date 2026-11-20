part of 'main.dart';

class _LearningSettingsPage extends StatefulWidget {
  const _LearningSettingsPage({required this.store});
  final AppStore store;

  @override
  State<_LearningSettingsPage> createState() => _LearningSettingsPageState();
}

class _LearningSettingsPageState extends State<_LearningSettingsPage> {
  static const _channel = MethodChannel('skillverse/reminders');
  var _time = const TimeOfDay(hour: 19, minute: 0);
  var _enabled = false;
  var _loading = _usesAndroidServices;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    if (_usesAndroidServices) {
      _lifecycle = AppLifecycleListener(
        onResume: () {
          if (!_loading) unawaited(_loadReminder());
        },
      );
      unawaited(_loadReminder());
    }
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  Future<void> _loadReminder() async {
    if (!_loading) setState(() => _loading = true);
    try {
      final state = await _channel.invokeMapMethod<String, Object?>('get');
      if (state != null && mounted) _apply(state);
    } catch (_) {
      _showReminderMessage('Could not read reminder settings.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(Map<String, Object?> state) {
    setState(() {
      _enabled = state['enabled'] == true;
      _time = TimeOfDay(
        hour: state['hour'] as int,
        minute: state['minute'] as int,
      );
    });
  }

  Future<void> _saveReminder(bool enabled, TimeOfDay time) async {
    setState(() => _loading = true);
    try {
      final state = await _channel.invokeMapMethod<String, Object?>('set', {
        'enabled': enabled,
        'hour': time.hour,
        'minute': time.minute,
      });
      if (!mounted || state == null) return;
      _apply(state);
      if (enabled && !_enabled) {
        _showReminderMessage(
          'Allow Skillverse learning notifications in Android settings to enable reminders.',
        );
      }
    } catch (_) {
      _showReminderMessage('Could not update the learning reminder.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showReminderMessage(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _chooseTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null && mounted) await _saveReminder(_enabled, selected);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) => _WeeklyGoalCard(store: widget.store),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                value: _enabled,
                title: const Text('Daily learning reminder'),
                subtitle: Text(
                  _usesAndroidServices
                      ? 'Receive a notification on this device around your chosen time.'
                      : 'Available in the Android app.',
                ),
                onChanged: !_usesAndroidServices || _loading
                    ? null
                    : (value) => _saveReminder(value, _time),
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Reminder time'),
                subtitle: Text(_time.format(context)),
                onTap: !_usesAndroidServices || _loading ? null : _chooseTime,
              ),
            ],
          ),
        ),
        _FeatureTile(
          icon: Icons.download_outlined,
          title: 'Export progress and activity',
          subtitle: 'Save a readable text report',
          onTap: () => _exportLearningProgress(context, widget.store),
        ),
        _FeatureTile(
          icon: Icons.info_outline,
          title: 'About Skillverse',
          subtitle: 'App version and local storage',
          onTap: () => _showLocalStorageInfo(context, widget.store),
        ),
      ],
    ),
  );
}
