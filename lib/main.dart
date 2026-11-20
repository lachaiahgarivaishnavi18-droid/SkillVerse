import 'dart:ui' show PlatformDispatcher;
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;

import 'curriculum_icon.dart';
import 'data/app_content.dart';
import 'data/course_models.dart';
import 'data/exam_session.dart';
import 'data/feedback_report.dart';
import 'data/course_discovery.dart';
import 'data/lesson_guides.dart';
import 'data/learning_activity.dart';
import 'data/project_briefs.dart';
import 'data/quiz_bank.dart';
import 'data/scenario_quiz_questions.dart';
import 'data/interview_attempt.dart';
import 'data/interview_questions.dart';
import 'data/interview_roles.dart';
import 'data/interview_guidance.dart';
import 'services/app_store.dart';
import 'services/skillverse_cloud.dart';

part 'android_accessibility.dart';
part 'feedback_ui.dart';
part 'interview_flow.dart';
part 'interview_review.dart';
part 'course_discovery_ui.dart';
part 'lesson_page.dart';
part 'exam_flow.dart';
part 'learning_progress_ui.dart';
part 'learning_settings.dart';
part 'certificate_flow.dart';
part 'project_briefs_ui.dart';

const _blue = Color(0xFF2457D6);
const _brandNight = Color(0xFF06183D);
const _brandPurple = Color(0xFF7B3DFF);
const _paleBlue = Color(0xFFEAF0FF);
const _pageBackground = Color(0xFFF5F7FC);
bool get _usesAndroidServices =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

const _minutesPerTestQuestion = 2;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.create(
    cloud: await SkillverseCloud.initialize(),
  );
  _installOptionalDiagnostics(store);
  runApp(LearningApp(store: store));
}

class LearningApp extends StatelessWidget {
  const LearningApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Skillverse',
    debugShowCheckedModeBanner: false,
    theme: _skillVerseTheme(highContrast: false),
    highContrastTheme: _skillVerseTheme(highContrast: true),
    home: StartupRouter(store: store),
  );
}

class StartupRouter extends StatefulWidget {
  const StartupRouter({super.key, required this.store});

  final AppStore store;

  @override
  State<StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<StartupRouter> {
  bool _showSplash = true;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _splashTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash && !MediaQuery.disableAnimationsOf(context)) {
      return const SplashScreen();
    }
    return widget.store.isAuthenticated
        ? MainScreen(store: widget.store)
        : WelcomePage(store: widget.store);
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_brandNight, Color(0xFF0B317C), _brandPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final logoSize = math
                .min(
                  360.0,
                  math.min(
                    constraints.maxWidth - 32,
                    constraints.maxHeight - 56,
                  ),
                )
                .clamp(0.0, 360.0);
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkillVerseBrand(width: logoSize),
                  const SizedBox(height: 20),
                  const SizedBox(
                    width: 150,
                    child: LinearProgressIndicator(
                      semanticsLabel: 'Starting Skillverse',
                      color: Colors.white,
                      backgroundColor: Color(0x557777FF),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.store});

  final AppStore store;

  void _openAuthentication(BuildContext context, {required bool signIn}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            AuthLandingPage(store: store, initialShowSignIn: signIn),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_brandNight, Color(0xFF0B317C), _brandPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SkillVerseBrand(),
                const SizedBox(height: 28),
                const Text(
                  'Your next skill starts here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Learn at your pace, practice with purpose, and track your progress.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        _openAuthentication(context, signIn: false),
                    child: const Text('Create Account'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _openAuthentication(context, signIn: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                    child: const Text('Sign In'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class SkillVerseBrand extends StatelessWidget {
  const SkillVerseBrand({super.key, this.compact = false, this.width});

  final bool compact;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? (compact ? 160 : 240),
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.asset(
          'assets/brand/skillverse_logo.png',
          fit: BoxFit.contain,
          semanticLabel: 'Skillverse logo',
        ),
      ),
    );
  }
}

class AuthLandingPage extends StatefulWidget {
  const AuthLandingPage({
    super.key,
    required this.store,
    this.initialShowSignIn = true,
  });

  final AppStore store;
  final bool initialShowSignIn;

  @override
  State<AuthLandingPage> createState() => _AuthLandingPageState();
}

class _AuthLandingPageState extends State<AuthLandingPage> {
  late bool _showSignIn;
  String _registeredEmail = '';

  @override
  void initState() {
    super.initState();
    _showSignIn = widget.initialShowSignIn;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_brandNight, Color(0xFF0B317C), Color(0xFF1F2DCE)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Card(
              color: Colors.white.withValues(alpha: 0.96),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SkillVerseBrand(width: 264),
                      const SizedBox(height: 18),
                      SegmentedButton<bool>(
                        direction: _largeText(context)
                            ? Axis.vertical
                            : Axis.horizontal,
                        segments: const [
                          ButtonSegment(value: true, label: Text('Sign In')),
                          ButtonSegment(
                            value: false,
                            label: Text('Create Account'),
                          ),
                        ],
                        selected: {_showSignIn},
                        onSelectionChanged: (selection) =>
                            setState(() => _showSignIn = selection.first),
                      ),
                      const SizedBox(height: 18),
                      if (_showSignIn)
                        SignInForm(
                          store: widget.store,
                          initialEmail: _registeredEmail,
                        )
                      else
                        SignUpForm(
                          store: widget.store,
                          onRegistered: (email, requiresConfirmation) {
                            setState(() {
                              _registeredEmail = email;
                              _showSignIn = true;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  requiresConfirmation
                                      ? 'Check your email for a confirmation link, then sign in.'
                                      : 'Account created. Sign in to continue.',
                                ),
                              ),
                            );
                          },
                        ),
                      TextButton.icon(
                        onPressed: () =>
                            _reportProblem(context, FeedbackKind.appBug),
                        icon: const Icon(Icons.bug_report_outlined),
                        label: const Text('Report an app bug'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SignInForm extends StatefulWidget {
  const SignInForm({super.key, required this.store, this.initialEmail = ''});

  final String initialEmail;

  final AppStore store;

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final _formKey = GlobalKey<FormState>();
  late final _emailController = TextEditingController(
    text: widget.initialEmail,
  );
  final _passwordController = TextEditingController();
  bool _rememberMe = true;
  bool _isSubmitting = false;
  bool _dirty = false;
  String? _signInError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _GuardUnsaved(
    dirty: _dirty,
    busy: _isSubmitting,
    child: AutofillGroup(
      child: FocusTraversalGroup(
        child: Form(
          onChanged: () {
            if (!_dirty || _signInError != null) {
              setState(() {
                _dirty = true;
                _signInError = null;
              });
            }
          },
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email Address'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Email is required.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_isSubmitting) _submit();
                },
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Password is required.'
                    : null,
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: CheckboxListTile(
                      value: _rememberMe,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Remember me'),
                      onChanged: (value) =>
                          setState(() => _rememberMe = value ?? true),
                    ),
                  ),
                  TextButton(
                    onPressed: _requestPasswordReset,
                    child: const Text('Change password'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: const Icon(Icons.login),
                  label: Text(_isSubmitting ? 'Signing in...' : 'Login'),
                ),
              ),
              if (_signInError case final message?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      _isSubmitting = true;
      _signInError = null;
    });
    try {
      await widget.store.signIn(
        email: _emailController.text,
        password: _passwordController.text,
        rememberMe: _rememberMe,
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => MainScreen(store: widget.store),
          ),
          (route) => false,
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _signInError = _authMessage(
          error,
          'Could not sign in. Check your details and try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _requestPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your email to reset your password.'),
        ),
      );
      return;
    }
    final currentPassword = _passwordController.text;
    if (currentPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your current password first.')),
      );
      return;
    }
    var replacement = '';
    final newPassword = await showDialog<String>(
      context: context,
      animationStyle: _sheetMotion(context),
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Change your local password'),
        content: TextField(
          onChanged: (value) => replacement = value,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New password',
            helperText: 'Use at least 6 characters.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, replacement),
            child: const Text('Change password'),
          ),
        ],
      ),
    );
    if (newPassword == null || !mounted) return;
    try {
      await widget.store.resetPassword(
        email: email,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your password has been updated.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _authMessage(
                error,
                'Could not change your password. Check the passwords and try again.',
              ),
            ),
          ),
        );
      }
    }
  }
}

class SignUpForm extends StatefulWidget {
  const SignUpForm({
    super.key,
    required this.store,
    required this.onRegistered,
  });

  final void Function(String email, bool requiresConfirmation) onRegistered;

  final AppStore store;

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _termsAccepted = false;
  bool _passwordVisible = false;
  bool _confirmVisible = false;
  bool _isSubmitting = false;
  bool _dirty = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _GuardUnsaved(
    dirty: _dirty,
    busy: _isSubmitting,
    child: AutofillGroup(
      child: FocusTraversalGroup(
        child: Form(
          onChanged: () {
            if (!_dirty) setState(() => _dirty = true);
          },
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                autofillHints: const [AutofillHints.name],
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Name is required.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email Address'),
                validator: AppStore.validateEmail,
              ),
              if (widget.store.cloud == null) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Mobile Number'),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: _PasswordVisibility(
                    visible: _passwordVisible,
                    field: 'password',
                    onPressed: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                  ),
                ),
                validator: (value) => (value == null || value.trim().length < 6)
                    ? 'Use at least 6 characters.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: !_confirmVisible,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_isSubmitting && _termsAccepted) _submit();
                },
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  suffixIcon: _PasswordVisibility(
                    visible: _confirmVisible,
                    field: 'confirmation password',
                    onPressed: () =>
                        setState(() => _confirmVisible = !_confirmVisible),
                  ),
                ),
                validator: (value) => value != _passwordController.text
                    ? 'Passwords do not match.'
                    : null,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _termsAccepted,
                title: const Text('I agree to the terms and conditions'),
                onChanged: (value) =>
                    setState(() => _termsAccepted = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting || !_termsAccepted ? null : _submit,
                  icon: const Icon(Icons.person_add),
                  label: Text(
                    _isSubmitting ? 'Creating account...' : 'Create Account',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final requiresConfirmation = await widget.store.signUp(
        fullName: _nameController.text,
        email: _emailController.text,
        mobile: _mobileController.text,
        password: _passwordController.text,
        confirmPassword: _confirmController.text,
      );
      if (mounted) {
        widget.onRegistered(_emailController.text.trim(), requiresConfirmation);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _authMessage(
              error,
              'Could not create your account. Check your details and try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(store: widget.store, onSelectTab: _selectTab),
      LearnPage(store: widget.store),
      InterviewHubPage(store: widget.store),
      ProjectsPage(store: widget.store),
      ProfilePage(store: widget.store),
    ];
    final navigation = NavigationBar(
      animationDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : null,
      selectedIndex: _selectedIndex,
      onDestinationSelected: _selectTab,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.menu_book_outlined),
          selectedIcon: Icon(Icons.menu_book),
          label: 'Learn',
        ),
        NavigationDestination(
          icon: Icon(Icons.question_answer_outlined),
          selectedIcon: Icon(Icons.question_answer),
          label: 'Interview',
        ),
        NavigationDestination(
          icon: Icon(Icons.folder_outlined),
          selectedIcon: Icon(Icons.folder),
          label: 'Projects',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
    return PopScope<void>(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedIndex != 0) _selectTab(0);
      },
      child: Scaffold(
        body: SafeArea(
          child: IndexedStack(
            index: _selectedIndex == 1 ? 0 : 1,
            children: [
              ExcludeFocus(excluding: _selectedIndex != 1, child: pages[1]),
              if (_selectedIndex == 1)
                const SizedBox.shrink()
              else
                KeyedSubtree(
                  key: ValueKey(_selectedIndex),
                  child: pages[_selectedIndex],
                ),
            ],
          ),
        ),
        bottomNavigationBar: _largeText(context)
            ? SafeArea(
                top: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = math.max(
                      constraints.maxWidth,
                      76 *
                          5 *
                          (MediaQuery.textScalerOf(context).scale(14) / 14),
                    );
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(width: width, child: navigation),
                    );
                  },
                ),
              )
            : navigation,
      ),
    );
  }

  void _selectTab(int index) {
    if (index == _selectedIndex) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _selectedIndex = index);
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store, required this.onSelectTab});

  final AppStore store;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final activeCourses = store.coursesInProgress;
      final featured = activeCourses.firstOrNull;
      final goal = store.learningGoal;
      final theme = Theme.of(context);
      final actions = [
        _FeatureTile(
          icon: Icons.menu_book,
          title: 'Learning courses',
          subtitle: '${courses.length} subjects with structured lessons',
          onTap: () => onSelectTab(1),
        ),
        _FeatureTile(
          icon: Icons.question_answer,
          title: 'Interview practice',
          subtitle: 'Question bank, mock interviews and tests',
          onTap: () => onSelectTab(2),
        ),
        _FeatureTile(
          icon: Icons.leaderboard,
          title: 'Leaderboard',
          subtitle: 'Global, weekly and monthly rankings',
          onTap: () => _push(context, LeaderboardPage(store: store)),
        ),
        _FeatureTile(
          icon: Icons.workspace_premium,
          title: 'Certificates',
          subtitle: 'Download course completion PDFs',
          onTap: () => _push(context, CertificatesPage(store: store)),
        ),
        _FeatureTile(
          icon: Icons.bar_chart,
          title: 'Results and performance',
          subtitle: '${store.attempts.length} saved test attempts',
          onTap: () => _push(context, PerformancePage(store: store)),
        ),
        _FeatureTile(
          icon: Icons.folder_special,
          title: 'Projects',
          subtitle: '${store.projects.length} personal projects',
          onTap: () => onSelectTab(3),
        ),
      ];
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gutter = constraints.maxWidth < 420 ? 16.0 : 24.0;
              final contentWidth = constraints.maxWidth - 2 * gutter;
              final tileWidth = contentWidth >= 640
                  ? (contentWidth - 12) / 2
                  : contentWidth;
              return ListView(
                padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 24),
                children: [
                  Row(
                    children: [
                      const SkillVerseBrand(width: 60),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Skillverse',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: _brandNight,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Open profile',
                        onPressed: () => onSelectTab(4),
                        icon: const Icon(
                          Icons.account_circle_outlined,
                          color: _blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_brandNight, Color(0xFF243D94)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${store.displayName}!',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (featured != null)
                          _ResumeLearning(store: store, course: featured)
                        else ...[
                          Text(
                            goal?.reason ??
                                'Choose a goal to find your first course.',
                            style: const TextStyle(color: Colors.white),
                          ),
                          if (goal != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              goal.course.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          FilledButton.tonalIcon(
                            onPressed: () {
                              if (goal == null) {
                                _chooseLearningGoal(
                                  context,
                                  store,
                                  start: true,
                                );
                              } else {
                                _openCourseLesson(
                                  context,
                                  store,
                                  goal.course,
                                  goal.course.allLessons.first,
                                );
                              }
                            },
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start Learning'),
                          ),
                        ],
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () =>
                                  _chooseLearningGoal(context, store),
                              child: Text(
                                goal == null
                                    ? 'Set learning goal'
                                    : 'Change goal',
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => onSelectTab(1),
                              child: const Text('Browse courses'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _SectionHeading(title: 'Your learning'),
                  const SizedBox(height: 8),
                  _FeatureTile(
                    icon: Icons.collections_bookmark_outlined,
                    title: 'My Learning',
                    subtitle: 'In progress, saved and completed courses',
                    onTap: () => _push(context, _MyLearningPage(store: store)),
                  ),
                  _ProgressSummary(store: store),
                  _WeeklyGoalCard(store: store),
                  if (activeCourses.length > 1) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        for (final course in activeCourses.skip(1).take(2))
                          SizedBox(
                            width: tileWidth,
                            child: _HomeCourseProgress(
                              store: store,
                              course: course,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  const _SectionHeading(title: 'Explore'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      for (final action in actions)
                        SizedBox(width: tileWidth, child: action),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

class _HomeCourseProgress extends StatelessWidget {
  const _HomeCourseProgress({required this.store, required this.course});

  final AppStore store;
  final Course course;

  @override
  Widget build(BuildContext context) {
    final lessons = course.allLessons;
    final completed = lessons
        .where((lesson) => store.completedLessons.contains(lesson.id))
        .length;
    final progress = store.progressFor(course);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            _push(context, CourseDetailPage(course: course, store: store)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CurriculumIcon.course(course),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      course.title,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$completed of ${lessons.length} lessons · ${(progress * 100).round()}%',
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                semanticsLabel: '${course.title} lesson progress',
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LearnPage extends StatefulWidget {
  const LearnPage({super.key, required this.store});

  final AppStore store;

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  final _search = TextEditingController();
  String _category = 'All';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setFilters(String query, String category) {
    _search.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    setState(() => _category = category);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      final categories = const [
        'All',
        'Beginner',
        'Intermediate',
        'Advanced',
        'Completed',
        'In progress',
        'Not started',
      ];
      final query = _search.text.trim();
      final filteredCourses = courses.where((course) {
        final matchesSearch = matchesCourseSearch(course, query);
        final matchesCategory = switch (_category) {
          'Beginner' ||
          'Intermediate' ||
          'Advanced' => course.matchesLevel(_category),
          'Completed' => widget.store.isCourseComplete(course),
          'In progress' =>
            !widget.store.isCourseComplete(course) &&
                widget.store.hasStartedCourse(course),
          'Not started' =>
            !widget.store.isCourseComplete(course) &&
                !widget.store.hasStartedCourse(course),
          _ => true,
        };
        return matchesSearch && matchesCategory;
      }).toList();

      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _PageTitle(
            title: 'Learning courses',
            subtitle: 'Choose a subject and continue at your own pace.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.collections_bookmark_outlined),
              label: const Text('My Learning'),
              onPressed: () =>
                  _push(context, _MyLearningPage(store: widget.store)),
            ),
          ),
          const SizedBox(height: 16),
          _ProgressSummary(store: widget.store),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search courses',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(category),
                      avatar: CurriculumIcon(label: category, size: 16),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (filteredCourses.isEmpty) ...[
            const _EmptyState(
              icon: Icons.search_off,
              title: 'No courses found',
              subtitle: 'Try a related topic or clear your search and filters.',
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final topic in relatedCourseTopics(query))
                  ActionChip(
                    label: Text('Search $topic'),
                    onPressed: () => _setFilters(topic, 'All'),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _setFilters('', 'All'),
                child: const Text('Clear search and filters'),
              ),
            ),
          ] else
            for (final course in filteredCourses)
              _DiscoveryCourseTile(course: course, store: widget.store),
        ],
      );
    },
  );
}

class CourseDetailPage extends StatefulWidget {
  const CourseDetailPage({
    super.key,
    required this.course,
    required this.store,
    this.initialDifficulty = 'All',
  });

  final Course course;
  final String initialDifficulty;
  final AppStore store;

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  late String _difficulty = widget.initialDifficulty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Lesson> get _visibleLessons => widget.course.allLessons
      .where(
        (lesson) =>
            _difficulty == 'All' || lesson.difficulty.label == _difficulty,
      )
      .toList();

  final ScrollController _controller = ScrollController();
  final GlobalKey _modulesKey = GlobalKey();
  final GlobalKey _lessonsKey = GlobalKey();

  void _showInfo(
    String title,
    String message, {
    List<String> topics = const [],
  }) {
    showModalBottomSheet<void>(
      context: context,
      sheetAnimationStyle: _sheetMotion(context),
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (topics.isEmpty) Text(message),
                for (final topic in topics)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CurriculumIcon.topic(
                      widget.course.allLessons.firstWhere(
                        (lesson) => lesson.topics.contains(topic),
                      ),
                      topic,
                    ),
                    title: Text(topic),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.course.title),
      actions: [_ReportContentButton(widget.course.id)],
    ),
    body: ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final lessonCount = widget.course.allLessons.length;
        final completed = widget.store.completedLessons;
        final unfinished = widget.course.allLessons
            .where((lesson) => !completed.contains(lesson.id))
            .toList();
        final nextLesson = widget.store.continueLesson(
          widget.course,
          difficulty: _difficulty == 'All' ? null : _difficulty,
        );
        final topicCount = widget.course.topicCount;
        final hourValues = RegExp(r'\d+')
            .allMatches(widget.course.duration)
            .map((match) => int.parse(match.group(0)!));
        final estimatedHours = hourValues.lastOrNull;
        final remainingHours = estimatedHours == null
            ? null
            : (estimatedHours * (1 - widget.store.progressFor(widget.course)))
                  .ceil();
        return SingleChildScrollView(
          controller: _controller,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.course.description.isEmpty
                    ? 'A self-paced introduction to ${widget.course.title}.'
                    : widget.course.description,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: Text(widget.course.level),
                    onPressed: () => _showInfo(
                      'Learning level',
                      '${widget.course.title} is listed as ${widget.course.level.toLowerCase()}. '
                          'Use the learning objectives and prerequisites to judge the right starting point.',
                    ),
                  ),
                  ActionChip(
                    label: Text(widget.course.duration),
                    onPressed: () => _showInfo(
                      'Course duration',
                      'Study time is ${widget.course.duration}. '
                          '${remainingHours == null ? 'Complete the modules at your own pace.' : 'Approximate remaining time is $remainingHours hours based on completed lessons.'}',
                    ),
                  ),
                  ActionChip(
                    label: Text('$lessonCount lessons'),
                    onPressed: () => _scrollToKey(_lessonsKey),
                  ),
                  ActionChip(
                    label: Text(
                      '${widget.course.learningModules.length} modules',
                    ),
                    onPressed: () => _scrollToKey(_modulesKey),
                  ),
                  ActionChip(
                    label: Text('$topicCount topics'),
                    onPressed: () => _showInfo(
                      'Topics covered',
                      'This course is still being expanded.',
                      topics: widget.course.allTopics,
                    ),
                  ),
                ],
              ),
              _ProgressSummary(store: widget.store, course: widget.course),
              if (nextLesson != null)
                FilledButton.icon(
                  onPressed: () => _push(
                    context,
                    LessonPage(
                      lesson: nextLesson,
                      store: widget.store,
                      courseLessons: _visibleLessons,
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Continue Learning'),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.preview_outlined),
                      label: const Text('Preview course'),
                      onPressed: () => _showCoursePreview(
                        context,
                        widget.store,
                        widget.course,
                      ),
                    ),
                  ),
                  _SaveCourseButton(course: widget.course, store: widget.store),
                ],
              ),
              if (widget.course.objectives.isNotEmpty) ...[
                const _SectionHeading(title: 'Learning outcomes'),
                const SizedBox(height: 6),
                for (final objective in widget.course.objectives)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.check, color: _blue),
                    title: Text(objective),
                  ),
              ],
              if (widget.course.prerequisites.isNotEmpty) ...[
                const SizedBox(height: 8),
                const _SectionHeading(title: 'Prerequisites'),
                for (final prerequisite in widget.course.prerequisites)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.info_outline),
                    title: Text(prerequisite),
                  ),
                for (final entry in prerequisiteLessons(widget.course))
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.menu_book_outlined, color: _blue),
                    title: Text(entry.lesson.title),
                    subtitle: Text(
                      'Introductory lesson · ${entry.course.title}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openCourseLesson(
                      context,
                      widget.store,
                      entry.course,
                      entry.lesson,
                    ),
                  ),
              ],
              if (widget.course.tools.isNotEmpty) ...[
                const SizedBox(height: 8),
                const _SectionHeading(title: 'Tools and technologies'),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final tool in widget.course.tools)
                        Chip(
                          avatar: CurriculumIcon(
                            label: tool,
                            contextLabels: [widget.course.title],
                            size: 16,
                          ),
                          label: Text(tool),
                        ),
                    ],
                  ),
                ),
              ],
              if (projectBriefFor(widget.course) case final brief?) ...[
                const SizedBox(height: 16),
                const _SectionHeading(title: 'Capstone project'),
                const SizedBox(height: 6),
                Text(brief.objective),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        _showProjectBrief(context, widget.store, brief),
                    icon: const Icon(Icons.assignment_outlined),
                    label: const Text('View project brief'),
                  ),
                ),
              ] else if (widget.course.capstoneProject.isNotEmpty) ...[
                const SizedBox(height: 16),
                const _SectionHeading(title: 'Capstone project'),
                const SizedBox(height: 6),
                Text(widget.course.capstoneProject),
              ],
              const SizedBox(height: 14),
              Container(
                key: _lessonsKey,
                child: Container(
                  key: _modulesKey,
                  child: const _SectionHeading(title: 'Modules and lessons'),
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final level in [
                      'All',
                      'Beginner',
                      'Intermediate',
                      'Advanced',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(level),
                          avatar: CurriculumIcon(label: level, size: 16),
                          selected: _difficulty == level,
                          onSelected: (_) =>
                              setState(() => _difficulty = level),
                        ),
                      ),
                  ],
                ),
              ),
              if (_visibleLessons.isEmpty)
                const Text('No lessons match this level.'),
              for (final module in widget.course.learningModules.where(
                (module) => module.lessons.any(
                  (lesson) => _visibleLessons.contains(lesson),
                ),
              ))
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: ExpansionTile(
                    leading: CurriculumIcon.module(widget.course, module),
                    title: Text(
                      module.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: _ModuleProgress(
                      summary: module.summary,
                      progress: widget.store.lessonProgress(
                        module.lessons,
                        completedIds: completed,
                      ),
                    ),
                    children: [
                      for (final lesson in module.lessons.where(
                        (lesson) => _visibleLessons.contains(lesson),
                      ))
                        ListTile(
                          leading: CurriculumIcon.lesson(
                            widget.course,
                            module,
                            lesson,
                          ),
                          title: Text(lesson.title),
                          subtitle: Text(
                            completed.contains(lesson.id)
                                ? '${lesson.difficulty.label} · Completed'
                                : lesson.difficulty.label,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.store.completedLessons.contains(
                                lesson.id,
                              ))
                                const Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: _blue,
                                ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          onTap: () => _push(
                            context,
                            LessonPage(
                              lesson: lesson,
                              store: widget.store,
                              courseLessons: _visibleLessons,
                            ),
                          ),
                        ),
                      if (module.assignment.isNotEmpty)
                        ListTile(
                          title: const Text('Module assignment'),
                          subtitle: Text(module.assignment),
                        ),
                      if (module.questions.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.quiz_outlined),
                          label: Text(
                            'Practice questions · ${module.questions.length}',
                          ),
                          onPressed: () => _push(
                            context,
                            ModuleQuizPage(
                              module: module,
                              practice: true,
                              store: widget.store,
                            ),
                          ),
                        ),
                      if (module.moduleQuizQuestions.isNotEmpty)
                        TextButton.icon(
                          icon: const Icon(Icons.fact_check_outlined),
                          label: Text(
                            'Module quiz · ${module.moduleQuizQuestions.length}',
                          ),
                          onPressed: () => _push(
                            context,
                            ModuleQuizPage(module: module, store: widget.store),
                          ),
                        ),
                    ],
                  ),
                ),
              if (widget.course.finalQuestions.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionHeading(title: 'Final assessment'),
                const SizedBox(height: 6),
                Text(
                  widget.store.isCourseComplete(widget.course)
                      ? 'All lessons completed and the final assessment passed.'
                      : widget.store.passedCourseAssessments.contains(
                          widget.course.id,
                        )
                      ? 'Assessment passed. Complete every lesson to finish this course.'
                      : 'Complete every lesson, then pass the full ${widget.course.finalQuestions.length}-question assessment with at least 70%.',
                ),
                if (unfinished.isNotEmpty)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.lock_outline),
                    title: Text(
                      'Assessment locked · ${unfinished.length} lessons remaining',
                    ),
                    subtitle: Text(
                      'Complete the remaining lessons starting with ${unfinished.first.title}.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openCourseLesson(
                      context,
                      widget.store,
                      widget.course,
                      unfinished.first,
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: unfinished.isEmpty
                      ? () => _openFinalAssessment(
                          context,
                          widget.store,
                          widget.course,
                        )
                      : null,
                  icon: const Icon(Icons.fact_check),
                  label: Text(
                    widget.store.examDraft(
                              widget.course.quizSubject ?? widget.course.title,
                              widget.course.id,
                            ) !=
                            null
                        ? 'Resume final assessment'
                        : widget.store.passedCourseAssessments.contains(
                            widget.course.id,
                          )
                        ? 'Retake final assessment'
                        : 'Start final assessment',
                  ),
                ),
                if (widget.store.certificateFor(widget.course) != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Preview certificate'),
                    onPressed: () => _previewCertificate(
                      context,
                      widget.store,
                      widget.course,
                    ),
                  ),
                if (widget.store.isCourseComplete(widget.course))
                  const ListTile(
                    leading: Icon(Icons.verified, color: Color(0xFF175C32)),
                    title: Text('Course requirements completed'),
                    subtitle: Text(
                      'This Skillverse completion record documents your learning progress.',
                    ),
                  ),
              ],
              if (widget.store.isAuthenticated &&
                  (widget.store.hasStartedCourse(widget.course) ||
                      widget.store.isCourseComplete(widget.course))) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () =>
                      _confirmCourseReset(context, widget.store, widget.course),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset course progress'),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class ModuleQuizPage extends StatefulWidget {
  const ModuleQuizPage({
    super.key,
    required this.module,
    this.practice = false,
    this.store,
  });

  final CourseModule module;
  final bool practice;
  final AppStore? store;

  @override
  State<ModuleQuizPage> createState() => _ModuleQuizPageState();
}

class _ModuleQuizPageState extends State<ModuleQuizPage> {
  final _answers = <String, int>{};
  final _checked = <String>{};
  final _scroll = ScrollController();
  int _index = 0;
  bool _submitted = false;
  TestAttempt? _result;
  bool _saving = false;
  bool _leaving = false;
  DateTime _started = DateTime.now();
  late String _attemptId = 'module-${_started.microsecondsSinceEpoch}';

  late final String? _owner;

  @override
  void initState() {
    super.initState();
    _owner = widget.store?.currentUserId;
  }

  Future<void> _confirmExit() async {
    if (_leaving || _saving) return;
    _leaving = true;
    final leave = await _confirmTestExit(context, canResume: false);
    _leaving = false;
    if (mounted && leave) Navigator.of(context).pop();
  }

  List<QuizQuestion> get _questions => widget.practice
      ? widget.module.questions
      : widget.module.moduleQuizQuestions;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _go(int index) {
    setState(() => _index = index);
    _scroll.jumpTo(0);
  }

  Future<void> _finishOrRetry() async {
    if (_saving) return;
    if (_owner != widget.store?.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your account changed. Reopen this quiz to start a new session.',
          ),
        ),
      );
      return;
    }
    if (!_submitted && widget.store?.isAuthenticated == true) {
      setState(() => _saving = true);
      try {
        final questions = _questions;
        final completedAt = DateTime.now();
        final result = TestAttempt(
          id: _attemptId,
          subject: questions.first.subject,
          completedAt: completedAt,
          selections: Map.of(_answers),
          questionIds: questions.map((q) => q.id).toList(),
          durationSeconds: completedAt.difference(_started).inSeconds,
          mode: widget.practice ? 'modulePractice' : 'moduleQuiz',
          questions: List.of(questions),
          version: assessmentVersion(questions),
          moduleTitle: widget.module.title,
        );
        await widget.store!.saveAttempt(result);
        if (_owner != widget.store?.currentUserId) return;
        _result = result;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not save quiz points. Try again.'),
            ),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      if (!mounted) return;
    }

    setState(() {
      if (_submitted) {
        _started = DateTime.now();
        _attemptId = 'module-${_started.microsecondsSinceEpoch}';
        _result = null;
        _answers.clear();
        _checked.clear();
      }
      _submitted = !_submitted;
      _index = 0;
    });
    _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.practice ? 'Practice questions' : 'Module quiz';
    final questions = _questions;
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(
          child: Text('No questions available for this module.'),
        ),
      );
    }
    final question = questions[_index];
    final selection = _answers[question.id];
    final showAnswer = _submitted || _checked.contains(question.id);
    final correct = selection == question.answerIndex;
    final score = _submitted
        ? questions.where((q) => _answers[q.id] == q.answerIndex).length
        : 0;
    final canFinish = _answers.length == questions.length;

    return PopScope<void>(
      canPop: !_saving && (_submitted || _answers.isEmpty),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmExit());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [_ReportContentButton(question.id)],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _index > 0 ? () => _go(_index - 1) : null,
                child: const Text('Previous'),
              ),
              OutlinedButton(
                onPressed: _index + 1 < questions.length
                    ? () => _go(_index + 1)
                    : null,
                child: const Text('Next'),
              ),
              FilledButton(
                onPressed: !_saving && (_submitted || canFinish)
                    ? _finishOrRetry
                    : null,
                child: Text(
                  _submitted
                      ? 'Try again'
                      : widget.practice
                      ? 'See results'
                      : 'Submit quiz',
                ),
              ),
            ],
          ),
        ),
        body: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Semantics(
              liveRegion: true,
              header: true,
              child: Text(
                'Question ${_index + 1} of ${questions.length} · ${question.difficultyLabel}',
              ),
            ),
            const SizedBox(height: 8),
            _SectionHeading(title: widget.module.title),
            const SizedBox(height: 16),
            if (_submitted) ...[
              const _SectionHeading(title: 'Results'),
              Text(
                'Score $score / ${questions.length} · ${(score * 100 / questions.length).round()}%',
              ),
              Text('${questions.length - score} incorrect'),
              if (_result case final result?) ...[
                _ResultNextStep(store: widget.store!, attempt: result),
                _TopicResults(results: topicResults(_attemptAnswers([result]))),
              ],
              const SizedBox(height: 16),
            ],
            Text(
              question.prompt,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < question.options.length; i++)
              ListTile(
                selected: selection == i,
                leading: Icon(
                  showAnswer && i == question.answerIndex
                      ? Icons.check_circle_outline
                      : selection == i
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(question.options[i]),
                onTap: showAnswer || _saving
                    ? null
                    : () => setState(() => _answers[question.id] = i),
              ),
            if (showAnswer) ...[
              const SizedBox(height: 8),
              Text(correct ? 'Correct' : 'Incorrect'),
              if (!correct)
                Text(
                  'Correct answer · ${question.options[question.answerIndex]}',
                ),
              const SizedBox(height: 4),
              Text(question.explanation),
            ] else if (widget.practice) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: selection == null
                    ? null
                    : () => setState(() => _checked.add(question.id)),
                child: const Text('Check answer'),
              ),
            ],
            const SizedBox(height: 16),
            if (_submitted && widget.module.assignment.isNotEmpty) ...[
              const SizedBox(height: 20),
              const _SectionHeading(title: 'Module assignment'),
              Text(widget.module.assignment),
            ],
          ],
        ),
      ),
    );
  }
}

class InterviewHubPage extends StatelessWidget {
  const InterviewHubPage({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const _PageTitle(
        title: 'Interview practice',
        subtitle: 'Practice with curated questions and timed assessments.',
      ),
      const SizedBox(height: 12),
      _FeatureTile(
        icon: Icons.menu_book_outlined,
        title: 'Interview preparation lessons',
        subtitle: 'Technical Fundamentals with worked examples and practice exercises',
        onTap: () {
          final course = courses.firstWhere(
            (course) => course.id == 'technical-fundamentals',
          );
          _push(context, CourseDetailPage(course: course, store: store));
        },
      ),
      _FeatureTile(
        icon: Icons.library_books,
        title: 'Interview questions',
        subtitle:
            '${interviewQuestions.length} questions across ${interviewQuestions.map((q) => q.category).toSet().length} categories',
        onTap: () => _push(context, InterviewQuestionsPage(store: store)),
      ),
      _FeatureTile(
        icon: Icons.record_voice_over,
        title: 'Mock interviews',
        subtitle: 'Role sets, timed or untimed practice, and keyword guidance',
        onTap: () => _push(context, MockInterviewTopicsPage(store: store)),
      ),
      _FeatureTile(
        icon: Icons.timer,
        title: 'Mock tests',
        subtitle: '10 multiple-choice questions with a countdown',
        onTap: () => _push(context, MockTestTopicsPage(store: store)),
      ),
      _FeatureTile(
        icon: Icons.shuffle,
        title: 'Random practice',
        subtitle: 'Try a shuffled set of questions',
        onTap: () => _push(
          context,
          QuestionDetailPage(
            questions: [...interviewQuestions]..shuffle(),
            initialIndex: 0,
            store: store,
          ),
        ),
      ),
      _FeatureTile(
        icon: Icons.business,
        title: 'Company practice',
        subtitle: 'Service-based, product-based and fresher practice',
        onTap: () => _push(
          context,
          MockInterviewTopicsPage(store: store, companyPractice: true),
        ),
      ),
      _FeatureTile(
        icon: Icons.assignment_turned_in_outlined,
        title: 'Interview history and progress',
        subtitle: 'Review scores and question coverage for your account',
        onTap: () => _push(context, InterviewHistoryPage(store: store)),
      ),
      _FeatureTile(
        icon: Icons.bookmark_outline,
        title: 'Study Queue',
        subtitle: 'Saved questions with role, topic, and difficulty filters',
        onTap: () => _push(
          context,
          InterviewQuestionsPage(store: store, savedOnly: true),
        ),
      ),
      _FeatureTile(
        icon: Icons.history,
        title: 'Test history',
        subtitle: 'Review completed tests on this device',
        onTap: () => _push(context, TestHistoryPage(store: store)),
      ),
      _FeatureTile(
        icon: Icons.insights,
        title: 'Performance',
        subtitle: 'See scores from your saved test attempts',
        onTap: () => _push(context, PerformancePage(store: store)),
      ),
    ],
  );
}

class InterviewQuestionsPage extends StatefulWidget {
  const InterviewQuestionsPage({
    super.key,
    required this.store,
    this.savedOnly = false,
  });

  final AppStore store;
  final bool savedOnly;

  @override
  State<InterviewQuestionsPage> createState() => _InterviewQuestionsPageState();
}

class _InterviewQuestionsPageState extends State<InterviewQuestionsPage> {
  String _query = '';
  String _category = 'All';
  String _difficulty = 'All';
  InterviewRole? _role;
  String _topic = 'All';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.savedOnly ? 'Study Queue' : 'Question bank'),
    ),
    body: ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final categories = interviewQuestions
            .map((question) => question.category)
            .toSet()
            .toList();
        final bookmarks = widget.savedOnly
            ? widget.store.bookmarks
            : const <String>{};
        final terms = _query.trim().toLowerCase().split(RegExp(r'\s+'));
        final candidates = interviewQuestions.where((question) {
          final searchText =
              '${question.question} ${question.topic} ${question.category} ${question.answer}'
                  .toLowerCase();
          final matchesText = terms.every(searchText.contains);
          final matchesCategory =
              _category == 'All' || question.category == _category;
          final matchesDifficulty =
              _difficulty == 'All' || question.difficulty == _difficulty;
          final matchesSaved =
              !widget.savedOnly || bookmarks.contains(question.id);
          final role = _role;
          return (role == null || matchesInterviewRole(question, role)) &&
              matchesText &&
              matchesCategory &&
              matchesDifficulty &&
              matchesSaved;
        }).toList();
        final topics = [
          if (widget.savedOnly) ...{
            if (_topic != 'All') _topic,
            ...candidates.map((question) => question.topic),
          },
        ]..sort();
        final questions = _topic == 'All'
            ? candidates
            : candidates.where((question) => question.topic == _topic).toList();
        return CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search questions',
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        _FilterChip(
                          label: 'Category · $_category',
                          options: ['All', ...categories],
                          onSelected: (value) =>
                              setState(() => _category = value),
                        ),
                        _FilterChip(
                          label: 'Difficulty · $_difficulty',
                          options: const [
                            'All',
                            'Beginner',
                            'Intermediate',
                            'Advanced',
                          ],
                          onSelected: (value) =>
                              setState(() => _difficulty = value),
                        ),
                        if (widget.savedOnly) ...[
                          _FilterChip(
                            label: 'Role · ${_role?.label ?? 'All'}',
                            options: [
                              'All',
                              ...InterviewRole.values.map((role) => role.label),
                            ],
                            onSelected: (value) => setState(() {
                              _role = InterviewRole.values
                                  .where((role) => role.label == value)
                                  .firstOrNull;
                              _topic = 'All';
                            }),
                          ),
                          _FilterChip(
                            label: 'Topic · $_topic',
                            options: ['All', ...topics],
                            onSelected: (value) =>
                                setState(() => _topic = value),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        questions.length == 1
                            ? '1 question'
                            : '${questions.length} questions',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (questions.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  icon: Icons.search_off,
                  title: 'No questions found',
                  subtitle: widget.savedOnly && bookmarks.isEmpty
                      ? 'Bookmark a question to add it to your Study Queue.'
                      : 'Try a different search or remove a filter.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverList.builder(
                  itemCount: questions.length,
                  itemBuilder: (context, index) => Card(
                    child: ListTile(
                      title: Text(questions[index].question),
                      subtitle: Text(
                        '${questions[index].category} · ${questions[index].topic} · ${questions[index].difficulty}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _push(
                        context,
                        QuestionDetailPage(
                          questions: questions,
                          initialIndex: index,
                          store: widget.store,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class QuestionDetailPage extends StatefulWidget {
  const QuestionDetailPage({
    super.key,
    required this.questions,
    required this.initialIndex,
    required this.store,
  });

  final List<InterviewQuestion> questions;
  final int initialIndex;
  final AppStore store;

  @override
  State<QuestionDetailPage> createState() => _QuestionDetailPageState();
}

class _QuestionDetailPageState extends State<QuestionDetailPage> {
  late int _index = widget.initialIndex;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(int offset) {
    setState(() => _index += offset);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  InterviewQuestion get _question => widget.questions[_index];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${_index + 1} of ${widget.questions.length}'),
      actions: [
        _InterviewBookmark(store: widget.store, question: _question),
        _ReportContentButton(_question.id),
      ],
    ),
    body: ListView(
      controller: _scroll,
      padding: const EdgeInsets.all(20),
      children: [
        Chip(label: Text('${_question.category} · ${_question.difficulty}')),
        const SizedBox(height: 14),
        Text(
          _question.question,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () =>
              _openSingleQuestionPractice(context, widget.store, _question),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Practice answer'),
        ),
        const SizedBox(height: 16),
        _InterviewReference(question: _question, heading: 'Answer'),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final reviewed = widget.store.reviewedInterviewQuestions.contains(
              _question.id,
            );
            return OutlinedButton.icon(
              onPressed: reviewed
                  ? null
                  : () async {
                      try {
                        await widget.store.markInterviewQuestionReviewed(
                          _question.id,
                        );
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not save review. Try again.',
                              ),
                            ),
                          );
                        }
                      }
                    },
              icon: Icon(reviewed ? Icons.check : Icons.check_circle_outline),
              label: Text(reviewed ? 'Reviewed' : 'Mark as reviewed'),
            );
          },
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _index == 0 ? null : () => _move(-1),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _index == widget.questions.length - 1
                  ? null
                  : () => _move(1),
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
            ),
          ],
        ),
      ],
    ),
  );
}

class MockTestTopicsPage extends StatelessWidget {
  const MockTestTopicsPage({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mock tests')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Choose a subject and test mode. Available test lengths depend on the unique questions in the local question bank.',
          ),
        ),
        ListenableBuilder(
          listenable: store,
          builder: (context, _) => Column(
            children: [
              for (final draft in store.examDrafts)
                _SavedExamTile(draft: draft, store: store),
            ],
          ),
        ),
        for (final subject in {
          ...quizBankSubjects,
          ...scenarioQuizQuestions.map((q) => q.subject),
        })
          Builder(
            builder: (context) {
              final count = _quizQuestionsForSubject(subject).length;
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: _paleBlue,
                    child: Icon(Icons.quiz, color: _blue),
                  ),
                  title: Text(subject),
                  subtitle: Text('$count unique question(s) available'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(
                    context,
                    TestSetupPage(subject: subject, store: store),
                  ),
                ),
              );
            },
          ),
      ],
    ),
  );
}

enum TestMode { practice, exam }

class TestSetupPage extends StatefulWidget {
  const TestSetupPage({
    super.key,
    required this.subject,
    required this.store,
    this.courseId,
  });

  final String subject;
  final AppStore store;
  final String? courseId;

  @override
  State<TestSetupPage> createState() => _TestSetupPageState();
}

class _TestSetupPageState extends State<TestSetupPage> {
  int _questionCount = 10;
  bool _opening = false;
  String _difficulty = 'All levels';
  TestMode _mode = TestMode.exam;

  List<QuizQuestion> get _filteredQuestions {
    final subjectQuestions = _quizQuestionsForSubject(widget.subject);
    if (_difficulty == 'All levels') return subjectQuestions.toList();
    return subjectQuestions
        .where((question) => question.difficultyLabel == _difficulty)
        .toList();
  }

  Future<void> _openTest(List<QuizQuestion> questions, TestMode mode) async {
    if (_opening) return;
    setState(() => _opening = true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MockTestPage(
          subject: widget.subject,
          questions: questions,
          store: widget.store,
          mode: mode,
          courseId: widget.courseId,
        ),
      ),
    );
    if (mounted) setState(() => _opening = false);
  }

  @override
  Widget build(BuildContext context) {
    final available = _filteredQuestions;
    final samples = available
        .where((q) => q.id.startsWith('case-v1-'))
        .toList();
    final lengths = <int>[
      if (available.isNotEmpty && available.length < 10) available.length,
      10,
      20,
      30,
      50,
    ];
    final questionCount =
        available.isNotEmpty && available.length < _questionCount
        ? lengths.first
        : _questionCount;
    final draft = widget.store.examDraft(widget.subject, widget.courseId);
    final canStart =
        !_opening &&
        available.length >= questionCount &&
        (_mode == TestMode.practice || draft == null);
    return Scaffold(
      appBar: AppBar(title: const Text('Test setup')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.subject,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '${available.length} unique questions available for ${_difficulty.toLowerCase()}.',
          ),
          if (draft != null)
            _SavedExamTile(
              draft: draft,
              store: widget.store,
              onChanged: () {
                if (mounted) setState(() {});
              },
            ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _difficulty,
            decoration: const InputDecoration(labelText: 'Difficulty'),
            items: const ['All levels', 'Beginner', 'Intermediate', 'Advanced']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _difficulty = value;
                  if (_filteredQuestions.length < _questionCount) {
                    _questionCount = 10;
                  }
                });
              }
            },
          ),
          const SizedBox(height: 14),
          const _SectionHeading(title: 'Question count'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: lengths.map((count) {
              final enabled = available.length >= count;
              return ChoiceChip(
                label: Text('$count ${count == 1 ? 'Question' : 'Questions'}'),
                selected: questionCount == count,
                onSelected: enabled
                    ? (_) => setState(() => _questionCount = count)
                    : null,
              );
            }).toList(),
          ),
          if (available.length < _questionCount)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Choose another difficulty to find questions for this subject.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 18),
          DropdownButtonFormField<TestMode>(
            initialValue: _mode,
            decoration: const InputDecoration(labelText: 'Test mode'),
            items: widget.courseId == null
                ? const [
                    DropdownMenuItem(
                      value: TestMode.practice,
                      child: Text('Practice mode'),
                    ),
                    DropdownMenuItem(
                      value: TestMode.exam,
                      child: Text('Exam mode'),
                    ),
                  ]
                : const [
                    DropdownMenuItem(
                      value: TestMode.exam,
                      child: Text('Final exam mode'),
                    ),
                  ],
            onChanged: widget.courseId == null
                ? (value) {
                    if (value != null) setState(() => _mode = value);
                  }
                : null,
          ),
          const SizedBox(height: 20),
          const _SectionHeading(title: 'Instructions'),
          const SizedBox(height: 8),
          const Text(
            'Each question is worth one mark. Practice is untimed and explains each answer after you check it. '
            'Exams allow two minutes per question and submit when the deadline expires, including after you reopen a saved exam.',
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: canStart
                ? () => _openTest(
                    _selectTestQuestions(available, questionCount),
                    _mode,
                  )
                : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(
              'Start ${_mode == TestMode.practice ? 'practice' : 'exam'}',
            ),
          ),
          if (samples.isNotEmpty && widget.courseId == null)
            OutlinedButton.icon(
              onPressed: _opening
                  ? null
                  : () => _openTest(samples, TestMode.practice),
              icon: const Icon(Icons.science_outlined),
              label: const Text('Practice application questions'),
            ),
        ],
      ),
    );
  }
}

class MockTestPage extends StatefulWidget {
  const MockTestPage({
    super.key,
    required this.subject,
    required this.questions,
    required this.store,
    required this.mode,
    this.courseId,
    this.draft,
  });

  final String subject;
  final List<QuizQuestion> questions;
  final AppStore store;
  final TestMode mode;
  final String? courseId;
  final ExamDraft? draft;

  @override
  State<MockTestPage> createState() => _MockTestPageState();
}

class _MockTestPageState extends State<MockTestPage> {
  Duration get _duration =>
      Duration(minutes: widget.questions.length * _minutesPerTestQuestion);

  final Map<String, int> _answers = {};
  final Set<int> _marked = {};
  final Set<String> _revealed = {};
  late final String? _owner;
  late final ExamDraft? _draft;
  late final String _id;
  late final DateTime _started;
  late final String _version;
  late Duration _remaining;
  Timer? _timer;
  AppLifecycleListener? _lifecycle;
  int _index = 0;
  bool _submitting = false;
  bool _finished = false;
  bool _dialogOpen = false;
  bool _autoSubmitTried = false;
  TestAttempt? _submission;

  QuizQuestion get _question => widget.questions[_index];
  bool get _isPractice => widget.mode == TestMode.practice;
  bool get _currentRevealed => _revealed.contains(_question.id);
  bool get _expired => !_isPractice && _remaining == Duration.zero;
  bool get _locked =>
      _submitting || _finished || _expired || _submission != null;

  @override
  void initState() {
    super.initState();
    _owner = widget.store.currentUserId;
    final existing = widget.draft;
    _started = existing?.startedAt ?? DateTime.now().toUtc();
    _id =
        existing?.id ??
        '${_started.microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 31)}';
    _version = existing?.version ?? assessmentVersion(widget.questions);
    _draft = _isPractice
        ? null
        : existing ??
              ExamDraft(
                id: _id,
                subject: widget.subject,
                courseId: widget.courseId,
                startedAt: _started,
                deadline: _started.add(_duration),
                questions: widget.questions,
                version: _version,
                answers: const {},
                marked: const {},
                index: 0,
                fullCourseAssessment: widget.store.isFullCourseAssessment(
                  widget.courseId,
                  widget.questions,
                ),
              );
    _remaining = _draft?.remainingAt(DateTime.now()) ?? Duration.zero;
    if (existing != null) {
      _answers.addAll(existing.answers);
      _marked.addAll(existing.marked);
      _index = existing.index;
      _submission = widget.store.attempts
          .where((item) => item.id == _id)
          .firstOrNull;
    }
    if (_draft != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      _lifecycle = AppLifecycleListener(
        onResume: _tick,
        onStateChange: (state) {
          if (state != AppLifecycleState.resumed &&
              !_finished &&
              !_submitting) {
            _checkpoint();
          }
        },
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _checkpoint();
        _tick();
      });
    }
  }

  void _tick() {
    if (!mounted || _finished || _draft == null) return;
    final remaining = _draft.remainingAt(DateTime.now());
    if (_remaining != remaining) setState(() => _remaining = remaining);
    if ((_expired || _submission != null) &&
        !_dialogOpen &&
        !_autoSubmitTried &&
        !_submitting) {
      _autoSubmitTried = true;
      unawaited(_submit());
    }
  }

  Future<void> _saveDraft() async {
    final draft = _draft;
    final owner = _owner;
    if (draft == null || owner == null || _finished) return;
    try {
      await widget.store.saveExamDraft(
        draft.withProgress(_answers, _marked, _index),
        owner,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save exam progress on this device.'),
          ),
        );
      }
      rethrow;
    }
  }

  void _checkpoint() {
    unawaited(_saveDraft().catchError((Object _) {}));
  }

  void _change(VoidCallback update) {
    if (_locked) return;
    if (_draft case final draft?
        when draft.remainingAt(DateTime.now()) == Duration.zero) {
      _tick();
      return;
    }
    setState(update);
    _checkpoint();
  }

  Future<void> _confirmLeave() async {
    if (_dialogOpen || _submitting || _finished) return;
    _dialogOpen = true;
    final leave = await _confirmTestExit(
      context,
      canResume: _draft != null && _owner != null,
    );
    if (!mounted) return;
    if (!leave) {
      _dialogOpen = false;
      _tick();
      return;
    }
    try {
      await _saveDraft();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _dialogOpen = false;
      _tick();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: _finished,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) unawaited(_confirmLeave());
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.subject),
        actions: [
          if (!_largeText(context))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  _isPractice
                      ? 'Untimed practice'
                      : _formatDuration(
                          (_remaining.inMilliseconds / 1000).ceil(),
                        ),
                  semanticsLabel: _isPractice
                      ? 'Untimed practice'
                      : 'Time remaining ${_formatDuration((_remaining.inMilliseconds / 1000).ceil())}',
                  style: const TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_largeText(context))
            Text(
              _isPractice
                  ? 'Untimed practice'
                  : 'Time remaining ${_formatDuration((_remaining.inMilliseconds / 1000).ceil())}',
            ),
          LinearProgressIndicator(
            semanticsLabel: 'Exam question progress',
            value: (_index + 1) / widget.questions.length,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Question ${_index + 1} of ${widget.questions.length} · '
                  '${_question.difficultyLabel}',
                ),
              ),
              if (!_isPractice) ...[
                TextButton.icon(
                  onPressed: _locked
                      ? null
                      : () => _change(() {
                          if (!_marked.add(_index)) _marked.remove(_index);
                        }),
                  icon: Icon(
                    _marked.contains(_index) ? Icons.flag : Icons.outlined_flag,
                  ),
                  label: Text(_marked.contains(_index) ? 'Marked' : 'Review'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _question.prompt,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          RadioGroup<int>(
            groupValue: _answers[_question.id],
            onChanged: (value) {
              if (_isPractice && _currentRevealed) return;
              if (value != null) {
                _change(() => _answers[_question.id] = value);
              }
            },
            child: Column(
              children: [
                for (
                  var optionIndex = 0;
                  optionIndex < _question.options.length;
                  optionIndex++
                )
                  Card(
                    child: RadioListTile<int>(
                      value: optionIndex,
                      title: Text(_question.options[optionIndex]),
                    ),
                  ),
              ],
            ),
          ),
          if (_isPractice && _currentRevealed) ...[
            const SizedBox(height: 10),
            _PracticeFeedback(
              question: _question,
              selected: _answers[_question.id]!,
            ),
          ],
          const SizedBox(height: 12),
          if (!_isPractice)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(widget.questions.length, (index) {
                final question = widget.questions[index];
                final answered = _answers.containsKey(question.id);
                final marked = _marked.contains(index);
                final current = index == _index;
                final status = [
                  if (current) 'current',
                  if (marked) 'marked for review',
                  answered ? 'answered' : 'unanswered',
                ].join(', ');
                return OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: index == _index
                        ? _paleBlue
                        : _marked.contains(index)
                        ? const Color(0xFFFFF3CD)
                        : answered
                        ? const Color(0xFFE6F4EA)
                        : null,
                    minimumSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: _locked
                      ? null
                      : () => _change(() => _index = index),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${index + 1}',
                        semanticsLabel: 'Question ${index + 1}, $status',
                      ),
                      if (current) const Icon(Icons.arrow_right, size: 16),
                      if (marked) const Icon(Icons.flag_outlined, size: 16),
                      if (answered) const Icon(Icons.check, size: 16),
                    ],
                  ),
                );
              }),
            ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _locked || _isPractice || _index == 0
                    ? null
                    : () => _change(() => _index -= 1),
                child: const Text('Previous'),
              ),
              if (_isPractice)
                FilledButton(
                  onPressed: _submitting
                      ? null
                      : _currentRevealed
                      ? _index < widget.questions.length - 1
                            ? () => _change(() => _index += 1)
                            : _confirmSubmit
                      : _answers.containsKey(_question.id)
                      ? _revealPracticeAnswer
                      : null,
                  child: Text(
                    _currentRevealed
                        ? _index < widget.questions.length - 1
                              ? 'Next question'
                              : 'Finish practice'
                        : 'Submit answer / Reveal answer',
                  ),
                )
              else if (!_expired &&
                  _submission == null &&
                  _index < widget.questions.length - 1)
                FilledButton(
                  onPressed: _locked ? null : () => _change(() => _index += 1),
                  child: const Text('Next'),
                )
              else
                FilledButton(
                  onPressed: _submitting ? null : _confirmSubmit,
                  child: Text(
                    _expired || _submission != null
                        ? 'Save exam result'
                        : 'Submit exam',
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  void _revealPracticeAnswer() {
    setState(() => _revealed.add(_question.id));
  }

  Future<void> _confirmSubmit() async {
    if (_dialogOpen || _submitting || _finished) return;
    if (_isPractice || _expired || _submission != null) {
      await _submit();
      return;
    }
    final unanswered = widget.questions.length - _answers.length;
    _dialogOpen = true;
    final confirmed = await showDialog<bool>(
      context: context,
      animationStyle: _sheetMotion(context),
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Submit this test?'),
        content: Text(
          unanswered == 0
              ? 'Your answers will be scored and saved on this device.'
              : 'You have $unanswered unanswered question(s). Your test will still be scored and saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue test'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    _dialogOpen = false;
    if (confirmed == true) {
      await _submit();
    } else {
      _tick();
    }
  }

  Future<void> _submit() async {
    if (_submitting || _finished || _dialogOpen || !mounted) return;
    setState(() => _submitting = true);
    final now = DateTime.now().toUtc();
    final draft = _draft;
    final completed = draft != null && now.isAfter(draft.deadline)
        ? draft.deadline
        : now;
    final attempt = _submission ??= TestAttempt(
      id: _id,
      subject: widget.subject,
      completedAt: completed,
      selections: Map.of(_answers),
      questionIds: widget.questions.map((question) => question.id).toList(),
      durationSeconds: math.max(0, completed.difference(_started).inSeconds),
      mode: widget.mode.name,
      courseId: widget.courseId,
      questions: List.of(widget.questions),
      version: _version,
      fullCourseAssessment: draft?.fullCourseAssessment ?? false,
    );
    try {
      if (_owner != widget.store.currentUserId) {
        throw StateError('The exam account changed.');
      }
      await widget.store.saveAttempt(attempt);
      if (draft != null && _owner == widget.store.currentUserId) {
        await widget.store.discardExamDraft(draft);
      }
      _finished = true;
      _timer?.cancel();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TestResultPage(
            attempt: attempt,
            questions: widget.questions,
            store: widget.store,
            courseId: widget.courseId,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save your result. Tap Submit again to retry.',
          ),
        ),
      );
    }
  }
}

class _PracticeFeedback extends StatelessWidget {
  const _PracticeFeedback({required this.question, required this.selected});

  final QuizQuestion question;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final correct = selected == question.answerIndex;
    return Card(
      color: correct ? const Color(0xFFE6F4EA) : const Color(0xFFFFEBEE),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              correct ? 'Correct' : 'Not quite',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (!correct)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Correct answer: ${question.options[question.answerIndex]}',
                ),
              ),
            const SizedBox(height: 6),
            Text(question.explanation),
          ],
        ),
      ),
    );
  }
}

class TestResultPage extends StatelessWidget {
  const TestResultPage({
    super.key,
    required this.attempt,
    required this.questions,
    required this.store,
    this.courseId,
  });

  final TestAttempt attempt;
  final List<QuizQuestion> questions;
  final AppStore store;
  final String? courseId;

  int get correct => questions.where((question) {
    return attempt.selections[question.id] == question.answerIndex;
  }).length;

  @override
  Widget build(BuildContext context) {
    final percentage = questions.isEmpty
        ? 0
        : (100 * correct / attempt.total).round();
    final accuracy = attempt.selections.isEmpty
        ? 0
        : (100 * correct / attempt.selections.length).round();
    return Scaffold(
      appBar: AppBar(title: const Text('Test results')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: _paleBlue,
              child: Text(
                '$percentage%',
                style: const TextStyle(
                  color: _blue,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '${attempt.subject} · ${attempt.mode}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          if (attempt.version case final version?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Center(
                child: Text(
                  'Assessment version ${version.substring(0, math.min(12, version.length))}',
                ),
              ),
            ),
          const SizedBox(height: 18),
          _MetricCard(
            items: [
              ('Total questions', '${attempt.total}'),
              ('Correct', '$correct'),
              ('Incorrect', '${attempt.selections.length - correct}'),
              ('Unanswered', '${attempt.total - attempt.selections.length}'),
              ('Total marks', '$correct / ${attempt.total}'),
              ('Accuracy', '$accuracy%'),
              ('Time taken', _formatDuration(attempt.durationSeconds)),
            ],
          ),
          if (courseId != null) ...[
            const SizedBox(height: 10),
            Card(
              color: attempt.percentage >= 70
                  ? const Color(0xFFE6F4EA)
                  : _paleBlue,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  attempt.percentage >= 70
                      ? 'This attempt passed the 70% threshold.'
                      : 'This attempt fell short of the 70% pass mark.',
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _ResultNextStep(store: store, attempt: attempt),
          _TopicResults(results: topicResults(_attemptAnswers([attempt]))),
          const SizedBox(height: 12),
          const _SectionHeading(title: 'Answer review'),
          const SizedBox(height: 8),
          for (var index = 0; index < questions.length; index++)
            _AnswerReviewCard(
              index: index,
              question: questions[index],
              selected: attempt.selections[questions[index].id],
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () =>
                _pushReplacement(context, MockTestTopicsPage(store: store)),
            icon: const Icon(Icons.replay),
            label: const Text('Retake a test'),
          ),
          OutlinedButton.icon(
            onPressed: () => _push(context, PerformancePage(store: store)),
            icon: const Icon(Icons.insights),
            label: const Text('View performance'),
          ),
        ],
      ),
    );
  }
}

class _AnswerReviewCard extends StatelessWidget {
  const _AnswerReviewCard({
    required this.index,
    required this.question,
    required this.selected,
  });

  final int index;
  final QuizQuestion question;
  final int? selected;

  @override
  Widget build(BuildContext context) {
    final isCorrect = selected == question.answerIndex;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: _ReportContentButton(question.id),
            ),
            Text(
              '${index + 1}. ${question.prompt}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              selected == null
                  ? 'Unanswered'
                  : '${isCorrect ? 'Correct' : 'Your answer'}: ${question.options[selected!]}',
              style: TextStyle(
                color: isCorrect
                    ? const Color(0xFF175C32)
                    : const Color(0xFF9E202A),
              ),
            ),
            if (!isCorrect)
              Text('Correct answer: ${question.options[question.answerIndex]}'),
            const SizedBox(height: 5),
            Text(question.explanation),
          ],
        ),
      ),
    );
  }
}

class TestHistoryPage extends StatefulWidget {
  const TestHistoryPage({super.key, required this.store});

  final AppStore store;

  @override
  State<TestHistoryPage> createState() => _TestHistoryPageState();
}

class _TestHistoryPageState extends State<TestHistoryPage> {
  String _sort = 'Latest';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Test history')),
    body: ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final attempts = widget.store.attempts.toList();
        final drafts = widget.store.examDrafts;
        if (_sort == 'Oldest') {
          attempts.sort((a, b) => a.completedAt.compareTo(b.completedAt));
        } else if (_sort == 'Highest score') {
          attempts.sort((a, b) => _score(b).compareTo(_score(a)));
        } else {
          attempts.sort((a, b) => b.completedAt.compareTo(a.completedAt));
        }
        if (attempts.isEmpty && drafts.isEmpty) {
          return const _EmptyState(
            icon: Icons.history,
            title: 'No tests completed',
            subtitle: 'Your completed tests will be listed here.',
          );
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: DropdownButtonFormField<String>(
                initialValue: _sort,
                decoration: const InputDecoration(labelText: 'Sort by'),
                items: const [
                  DropdownMenuItem(value: 'Latest', child: Text('Latest')),
                  DropdownMenuItem(value: 'Oldest', child: Text('Oldest')),
                  DropdownMenuItem(
                    value: 'Highest score',
                    child: Text('Highest score'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _sort = value);
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: drafts.length + attempts.length,
                itemBuilder: (context, index) {
                  if (index < drafts.length) {
                    return _SavedExamTile(
                      draft: drafts[index],
                      store: widget.store,
                    );
                  }
                  final attempt = attempts[index - drafts.length];
                  final percentage = _score(attempt);
                  return Card(
                    child: ListTile(
                      title: Text(attempt.subject),
                      subtitle: Text(
                        '${_formatDate(attempt.completedAt)} · '
                        '$percentage% · ${attempt.mode} · '
                        '${_formatDuration(attempt.durationSeconds)}',
                      ),
                      trailing: Text('$percentage%'),
                      onTap: () =>
                          _openSavedResult(context, attempt, widget.store),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    ),
  );
}

class PerformancePage extends StatelessWidget {
  const PerformancePage({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Performance')),
    body: ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final attempts = store.attempts;
        if (attempts.isEmpty) {
          return const _EmptyState(
            icon: Icons.insights,
            title: 'No performance data yet',
            subtitle:
                'Complete a mock test to see scores and subject breakdowns.',
          );
        }
        final missed = _missedQuestions(attempts);
        final topics = topicResults(_attemptAnswers(attempts));
        final correct = topics.values.fold<int>(
          0,
          (total, entry) => total + entry.correct,
        );
        final answered = topics.values.fold<int>(
          0,
          (total, entry) => total + entry.correct + entry.incorrect,
        );
        final accuracy = answered == 0
            ? '—'
            : '${(100 * correct / answered).round()}%';
        final percentages = attempts.map(_score).toList();
        final average =
            percentages.reduce((a, b) => a + b) / percentages.length;
        final highest = percentages.reduce(math.max);
        final subjectScores = <String, List<int>>{};
        for (final attempt in attempts) {
          subjectScores
              .putIfAbsent(attempt.subject, () => [])
              .add(_score(attempt));
        }
        final weakSubject = subjectScores.entries.reduce(
          (a, b) => _average(a.value) <= _average(b.value) ? a : b,
        );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _MetricCard(
              items: [
                ('Tests attempted', '${attempts.length}'),
                ('Average score', '${average.round()}%'),
                ('Highest score', '$highest%'),
                ('Overall accuracy', accuracy),
              ],
            ),
            const SizedBox(height: 20),
            _TopicResults(results: topics),
            if (missed.isNotEmpty)
              FilledButton.icon(
                onPressed: () => _practiceMissed(context, store, missed),
                icon: const Icon(Icons.replay),
                label: const Text('Practice Missed Concepts'),
              ),
            const _SectionHeading(title: 'Subject performance'),
            const SizedBox(height: 8),
            for (final entry in subjectScores.entries)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(entry.key)),
                          Text('${_average(entry.value).round()}%'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _average(entry.value) / 100,
                      ),
                      const SizedBox(height: 4),
                      Text('${entry.value.length} test(s)'),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 14),
            _SectionHeading(title: 'Suggested focus: ${weakSubject.key}'),
            const SizedBox(height: 8),
            Text(
              'Your saved average in ${weakSubject.key} is '
              '${_average(weakSubject.value).round()}%. Review explanations '
              'for missed answers, then retake a test to check your progress.',
            ),
            const SizedBox(height: 14),
            const _SectionHeading(title: 'Recent progress'),
            const SizedBox(height: 8),
            for (final attempt in attempts.take(8))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(attempt.subject),
                subtitle: Text(_formatDate(attempt.completedAt)),
                trailing: Text('${_score(attempt)}%'),
              ),
          ],
        );
      },
    ),
  );
}

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => DefaultTabController(
      key: ValueKey(store.currentUserId),
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboard'),
          bottom: TabBar(
            isScrollable: _largeText(context),
            tabs: const [
              Tab(text: 'Global'),
              Tab(text: 'Weekly'),
              Tab(text: 'Monthly'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final period in ['global', 'weekly', 'monthly'])
              _LeaderboardTab(store: store, period: period),
          ],
        ),
      ),
    ),
  );
}

class _LeaderboardTab extends StatefulWidget {
  const _LeaderboardTab({required this.store, required this.period});

  final AppStore store;
  final String period;

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  late var _entries = _load();

  Future<({List<LeaderboardEntry> entries, bool pendingSync})> _load() async {
    final backend = widget.store.cloud;
    final owner = widget.store.currentUserId;
    if (backend == null || owner == null) {
      return (entries: const <LeaderboardEntry>[], pendingSync: false);
    }
    var pendingSync = false;
    try {
      await widget.store.syncLeaderboardResults();
    } catch (_) {
      // Rankings are readable even when delivery of a saved result fails.
      pendingSync = true;
    }
    if (widget.store.currentUserId != owner) {
      return (entries: const <LeaderboardEntry>[], pendingSync: false);
    }
    final entries = await backend.leaderboard(widget.period);
    return (
      entries: widget.store.currentUserId == owner
          ? entries
          : const <LeaderboardEntry>[],
      pendingSync: pendingSync,
    );
  }

  void _reload() {
    setState(() {
      _entries = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.store.cloud == null) {
      return const Center(
        child: SingleChildScrollView(
          child: _EmptyState(
            icon: Icons.leaderboard,
            title: 'Rankings unavailable',
            subtitle: 'Leaderboard rankings require a connected database.',
          ),
        ),
      );
    }
    if (!widget.store.isAuthenticated) {
      return const Center(
        child: SingleChildScrollView(
          child: _EmptyState(
            icon: Icons.lock_outline,
            title: 'Sign in to see rankings',
            subtitle: 'Live rankings are available to registered Skillverse accounts.',
          ),
        ),
      );
    }
    return FutureBuilder(
      future: _entries,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load rankings.'),
                  TextButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }
        final (:entries, :pendingSync) = snapshot.requireData;
        if (entries.isEmpty && !pendingSync) {
          return const Center(
            child: SingleChildScrollView(
              child: _EmptyState(
                icon: Icons.leaderboard,
                title: 'No rankings yet',
                subtitle: 'Rankings appear when registered users add their full names.',
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              return ListTile(
                leading: const Icon(Icons.cloud_done_outlined),
                title: const Text('Live rankings'),
                subtitle: Text(
                  pendingSync
                      ? 'Some saved results are waiting to sync.'
                      : 'Scores from registered Skillverse accounts.',
                ),
                trailing: pendingSync
                    ? IconButton(
                        tooltip: 'Retry syncing saved results',
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                      )
                    : null,
              );
            }
            final entry = entries[index - 1];
            final rank = entry.rank;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: rank == 1
                      ? const Color(0xFFFFD54F)
                      : _paleBlue,
                  child: Text(rank?.toString() ?? '–'),
                ),
                title: Text(
                  entry.name.isEmpty ? 'Add your full name' : entry.name,
                ),
                subtitle: Text(
                  entry.isYou
                      ? (rank == null ? 'You · Unranked' : 'You · #$rank')
                      : '#$rank',
                ),
                trailing: Text(
                  '${entry.points} pts',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: entry.isYou && entry.name.isEmpty
                    ? () async {
                        await _editDisplayName(context, widget.store);
                        if (mounted) _reload();
                      }
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}

class CertificatesPage extends StatelessWidget {
  const CertificatesPage({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final certificateCourses = courses
        .where((course) => store.certificateFor(course) != null)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Certificates')),
      body: certificateCourses.isEmpty
          ? const _EmptyState(
              icon: Icons.workspace_premium,
              title: 'No certificates yet',
              subtitle: 'Complete course lessons and pass the final assessment to unlock a PDF certificate.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: certificateCourses.length,
              itemBuilder: (context, index) {
                final course = certificateCourses[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _paleBlue,
                      child: CurriculumIcon.course(course),
                    ),
                    title: Text(course.title),
                    subtitle: Text(
                      '${store.certificateFor(course)?.studentName ?? store.displayName} · ${store.certificateFor(course)?.id ?? ''}',
                    ),
                    trailing: const Icon(Icons.preview_outlined),
                    onTap: () => _previewCertificate(context, store, course),
                  ),
                );
              },
            ),
    );
  }
}

class ProjectsPage extends StatelessWidget {
  const ProjectsPage({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => Scaffold(
      backgroundColor: _pageBackground,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('My projects'),
            floating: true,
            actions: [
              IconButton(
                tooltip: 'Add project',
                onPressed: () => _editProject(context, store),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: _FeatureTile(
                icon: Icons.assignment_outlined,
                title: 'Browse project briefs',
                subtitle:
                    'Course-linked practice projects and evaluation criteria',
                onTap: () => _browseProjectBriefs(context, store),
              ),
            ),
          ),
          if (store.projects.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                icon: Icons.folder_open,
                title: 'No projects yet',
                subtitle: 'Add a project to keep your portfolio organized.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverList.builder(
                itemCount: store.projects.length,
                itemBuilder: (context, index) {
                  final project = store.projects[index];
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: _paleBlue,
                        child: Icon(Icons.folder, color: _blue),
                      ),
                      title: Text(project.title),
                      subtitle: Text(
                        '${project.category} · ${project.technologies}\n'
                        '${project.description}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'edit') {
                            await _editProject(
                              context,
                              store,
                              project: project,
                            );
                          } else if (action == 'delete') {
                            await _confirmDelete(context, store, project);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                      onTap: () => _showProject(context, store, project),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editProject(context, store),
        icon: const Icon(Icons.add),
        label: const Text('Add project'),
      ),
    ),
  );
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _PageTitle(
          title: 'My profile',
          subtitle: 'Your learning activity is stored on this device.',
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              radius: 27,
              backgroundColor: _paleBlue,
              child: Icon(Icons.person, color: _blue, size: 30),
            ),
            title: Text(
              store.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Local learner profile'),
            trailing: IconButton(
              tooltip: 'Edit name',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editDisplayName(context, store),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _LearningMilestones(store: store),
        _FeatureTile(
          icon: Icons.menu_book,
          title: 'My courses',
          subtitle: '${store.completedLessonCount} lessons completed',
          onTap: () => _push(
            context,
            Scaffold(
              appBar: AppBar(title: const Text('My courses')),
              body: LearnPage(store: store),
            ),
          ),
        ),
        _FeatureTile(
          icon: Icons.folder,
          title: 'My projects',
          subtitle: '${store.projects.length} projects',
          onTap: () => _push(context, ProjectsPage(store: store)),
        ),
        _FeatureTile(
          icon: Icons.bookmark,
          title: 'Saved questions',
          subtitle: '${store.bookmarks.length} bookmarked',
          onTap: () => _push(
            context,
            InterviewQuestionsPage(store: store, savedOnly: true),
          ),
        ),
        _FeatureTile(
          icon: Icons.leaderboard,
          title: 'Leaderboards',
          subtitle: 'Global, weekly and monthly',
          onTap: () => _push(context, LeaderboardPage(store: store)),
        ),
        _FeatureTile(
          icon: Icons.workspace_premium,
          title: 'Certificates',
          subtitle: 'Download PDF certificates',
          onTap: () => _push(context, CertificatesPage(store: store)),
        ),
        _FeatureTile(
          icon: Icons.history,
          title: 'Test history',
          subtitle: '${store.attempts.length} attempts',
          onTap: () => _push(context, TestHistoryPage(store: store)),
        ),
        _FeatureTile(
          icon: Icons.timeline_outlined,
          title: 'Activity history',
          subtitle: 'Completed lessons, practice, quizzes, and interviews',
          onTap: () => _push(context, _LearningActivityPage(store: store)),
        ),
        if (!store.isAuthenticated)
          _FeatureTile(
            icon: Icons.login,
            title: 'Login / Sign in',
            subtitle: 'Access your Skillverse account',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AuthLandingPage(store: store),
              ),
            ),
          ),
        if (store.isAuthenticated)
          _FeatureTile(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of your Skillverse account',
            onTap: () async {
              await store.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(
                    builder: (_) => AuthLandingPage(store: store),
                  ),
                  (route) => false,
                );
              }
            },
          ),
        _FeatureTile(
          icon: Icons.settings_outlined,
          title: 'Settings',
          subtitle: 'Weekly goal, reminders, and progress export',
          onTap: () => _push(context, _LearningSettingsPage(store: store)),
        ),
        _FeatureTile(
          icon: Icons.feedback_outlined,
          title: 'Feedback and privacy',
          subtitle: 'Report a problem, manage diagnostics, and see where data is stored',
          onTap: () => _push(context, _FeedbackPage(store: store)),
        ),
      ],
    ),
  );
}

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({required this.store, this.course});

  final AppStore store;
  final Course? course;

  @override
  Widget build(BuildContext context) {
    final lessons =
        course?.allLessons ?? courses.expand((item) => item.allLessons);
    final (completed: completed, total: total) = store.lessonProgress(lessons);
    final progress = total == 0 ? 0.0 : completed / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up, color: _blue),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        course == null ? 'Course progress' : course!.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Text(
                  '$completed / $total lessons · ${(progress * 100).round()}%',
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: Color(0xFF4D5667))),
    ],
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: _paleBlue,
        child: Icon(icon, color: _blue),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => options
          .map((option) => PopupMenuItem(value: option, child: Text(option)))
          .toList(),
      tooltip: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Align(
          widthFactor: 1,
          child: Chip(
            label: Text(label),
            avatar: const Icon(Icons.filter_list, size: 18),
          ),
        ),
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.items});

  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(child: Text(item.$1)),
                  Text(
                    item.$2,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class _CodeBlock extends StatefulWidget {
  const _CodeBlock({required this.text});

  final String text;

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFF182238),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Semantics(
      label: 'Code example',
      child: Scrollbar(
        controller: _horizontal,
        thumbVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          controller: _horizontal,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
          child: SelectableText(
            widget.text,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: _blue),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

Future<void> _editDisplayName(BuildContext context, AppStore store) async {
  final initialName = store.profileName;
  var editedName = initialName;
  final name = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    animationStyle: _sheetMotion(context),
    builder: (dialog) => StatefulBuilder(
      builder: (context, update) => _GuardUnsaved(
        dirty: editedName != initialName,
        child: AlertDialog(
          scrollable: true,
          title: const Text('Edit profile name'),
          content: TextFormField(
            initialValue: initialName,
            autofocus: true,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onChanged: (value) => update(() => editedName = value),
            decoration: const InputDecoration(labelText: 'Full Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.maybePop(dialog),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: editedName.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialog, editedName),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    ),
  );
  if (name == null || !context.mounted) return;
  try {
    await store.updateDisplayName(name);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not update your profile. Check the name and try again.',
          ),
        ),
      );
    }
  }
}

Future<void> _showLocalStorageInfo(BuildContext context, AppStore store) async {
  final build = await AppBuild.read();
  if (!context.mounted) return;
  showAboutDialog(
    context: context,
    applicationName: 'Skillverse',
    applicationVersion: '${build.version} (build ${build.number})',
    children: [
      const Text(
        'Course progress, bookmarks, projects, and learning history are stored on this device.',
      ),
      const SizedBox(height: 8),
      Text(
        store.cloud == null
            ? 'This build uses local accounts. Live rankings require Supabase configuration.'
            : 'This build uses Supabase for cloud accounts and live rankings. A connection is required to sign in or refresh rankings.',
      ),
    ],
  );
}

void _openSavedResult(
  BuildContext context,
  TestAttempt attempt,
  AppStore store,
) {
  final questions = attempt.reviewQuestions;
  _push(
    context,
    TestResultPage(
      attempt: attempt,
      questions: questions,
      store: store,
      courseId: attempt.courseId,
    ),
  );
}

List<QuizQuestion> _quizQuestionsForSubject(String subject) {
  return quizQuestions
      .where(
        (question) =>
            question.subject == subject ||
            (subject == 'Technical Fundamentals' &&
                question.subject == 'Technical Questions'),
      )
      .toList();
}

int _score(TestAttempt attempt) => attempt.percentage;

double _average(List<int> values) =>
    values.reduce((a, b) => a + b) / values.length;

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
}

String _formatDate(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

void _push(BuildContext context, Widget page) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

void _pushReplacement(BuildContext context, Widget page) {
  Navigator.of(context)
      .pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
}
