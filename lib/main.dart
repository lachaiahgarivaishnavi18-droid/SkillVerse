import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import 'data/app_content.dart';
import 'data/course_models.dart';
import 'data/quiz_bank.dart';
import 'services/app_store.dart';

const _blue = Color(0xFF2457D6);
const _brandNight = Color(0xFF06183D);
const _brandBlue = Color(0xFF1D8BF2);
const _brandPurple = Color(0xFF7B3DFF);
const _paleBlue = Color(0xFFEAF0FF);
const _pageBackground = Color(0xFFF5F7FC);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await AppStore.create();
  runApp(LearningApp(store: store));
}

class LearningApp extends StatelessWidget {
  const LearningApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SkillVerse',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: _blue),
      scaffoldBackgroundColor: _pageBackground,
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    ),
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
    if (_showSplash) return const SplashScreen();
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
      child: const SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkillVerseBrand(),
              SizedBox(height: 32),
              SizedBox(
                width: 150,
                child: LinearProgressIndicator(
                  color: Colors.white,
                  backgroundColor: Color(0x557777FF),
                ),
              ),
            ],
          ),
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
                  style: TextStyle(color: Colors.white70, fontSize: 16),
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
  const SkillVerseBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 160 : 240,
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.asset(
          'assets/brand/skillverse_logo.png',
          fit: BoxFit.contain,
          semanticLabel: 'SkillVerse logo',
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
            padding: const EdgeInsets.all(20),
            child: Card(
              color: Colors.white.withValues(alpha: 0.96),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SkillVerseBrand(compact: true),
                      const SizedBox(height: 18),
                      SegmentedButton<bool>(
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
                          onRegistered: (email) {
                            setState(() {
                              _registeredEmail = email;
                              _showSignIn = true;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Account created. Sign in to continue.',
                                ),
                              ),
                            );
                          },
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: Column(
      children: [
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Email is required.'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
          validator: (value) =>
              (value == null || value.isEmpty) ? 'Password is required.' : null,
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (value) =>
                      setState(() => _rememberMe = value ?? true),
                ),
                const Text('Remember me'),
              ],
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
      ],
    ),
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _isSubmitting = true);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is StateError ? error.message : error.toString()),
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
      builder: (context) => AlertDialog(
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
          const SnackBar(
            content: Text('Your local password has been updated.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
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

  final ValueChanged<String> onRegistered;

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
  Widget build(BuildContext context) => Form(
    key: _formKey,
    child: Column(
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Full Name'),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Name is required.'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email'),
          validator: AppStore.validateEmail,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _mobileController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Mobile Number'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _passwordController,
          obscureText: !_passwordVisible,
          decoration: InputDecoration(
            labelText: 'Password',
            suffixIcon: IconButton(
              icon: Icon(
                _passwordVisible ? Icons.visibility_off : Icons.visibility,
              ),
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
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            suffixIcon: IconButton(
              icon: Icon(
                _confirmVisible ? Icons.visibility_off : Icons.visibility,
              ),
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
          onChanged: (value) => setState(() => _termsAccepted = value ?? false),
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
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await widget.store.signUp(
        fullName: _nameController.text,
        email: _emailController.text,
        mobile: _mobileController.text,
        password: _passwordController.text,
        confirmPassword: _confirmController.text,
      );
      if (mounted) widget.onRegistered(_emailController.text.trim());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error is StateError ? error.message : error.toString()),
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
    return Scaffold(
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
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
      ),
    );
  }

  void _selectTab(int index) => setState(() => _selectedIndex = index);
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store, required this.onSelectTab});

  final AppStore store;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_brandNight, Color(0xFF0E2D71), Color(0xFF1F2DCE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _brandBlue.withValues(alpha: 0.32),
                blurRadius: 26,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Center(child: SkillVerseBrand()),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${store.displayName}!',
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Learn | Practice | Interview | Succeed',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const CircleAvatar(
              backgroundColor: _paleBlue,
              child: Icon(Icons.person, color: _blue),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_blue, Color(0xFF547BE5)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Build your skills, one step at a time.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 7),
              Text(
                'Study a lesson, practice questions and track your progress.',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _SectionHeading(title: 'Your learning'),
        const SizedBox(height: 10),
        _ProgressSummary(store: store),
        const SizedBox(height: 22),
        const _SectionHeading(title: 'Explore'),
        const SizedBox(height: 10),
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
      ],
    ),
  );
}

class LearnPage extends StatefulWidget {
  const LearnPage({super.key, required this.store});

  final AppStore store;

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  String _query = '';
  String _category = 'All';

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
      final query = _query.trim().toLowerCase();
      final filteredCourses = courses.where((course) {
        final matchesSearch =
            course.title.toLowerCase().contains(query) ||
            course.description.toLowerCase().contains(query);
        final matchesCategory = switch (_category) {
          'Beginner' ||
          'Intermediate' ||
          'Advanced' => course.matchesLevel(_category),
          'Completed' => widget.store.isCourseComplete(course),
          'In progress' =>
            !widget.store.isCourseComplete(course) &&
                course.allLessons.any(
                  (lesson) => widget.store.completedLessons.contains(lesson.id),
                ),
          'Not started' =>
            !widget.store.isCourseComplete(course) &&
                course.allLessons.every(
                  (lesson) =>
                      !widget.store.completedLessons.contains(lesson.id),
                ),
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
          const SizedBox(height: 16),
          _ProgressSummary(store: widget.store),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search courses',
            ),
            onChanged: (value) => setState(() => _query = value),
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
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (filteredCourses.isEmpty)
            const _EmptyState(
              icon: Icons.search_off,
              title: 'No courses found',
              subtitle:
                  'Try another search term or select a different category.',
            )
          else
            for (final course in filteredCourses)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: _paleBlue,
                    child: Icon(_courseIcon(course.title), color: _blue),
                  ),
                  title: Text(
                    course.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${course.description}\n'
                    '${course.allLessons.length} lessons · '
                    '${course.allLessons.where((lesson) => widget.store.completedLessons.contains(lesson.id)).length} completed · '
                    '${(widget.store.progressFor(course) * 100).round()}%',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(
                    context,
                    CourseDetailPage(
                      course: course,
                      store: widget.store,
                      initialDifficulty:
                          const [
                            'Beginner',
                            'Intermediate',
                            'Advanced',
                          ].contains(_category)
                          ? _category
                          : 'All',
                    ),
                  ),
                ),
              ),
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

  void _showInfo(String title, String message) {
    showModalBottomSheet<void>(
      context: context,
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
                Text(message),
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
    appBar: AppBar(title: Text(widget.course.title)),
    body: ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final lessonCount = widget.course.allLessons.length;
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
                      '${widget.course.title} is designed for ${widget.course.level.toLowerCase()} learners. '
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
                      widget.course.allTopics.isEmpty
                          ? 'This course is still being expanded.'
                          : widget.course.allTopics.join(', '),
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
              if (widget.course.objectives.isNotEmpty) ...[
                const _SectionHeading(title: 'Learning objectives'),
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
                        Chip(label: Text(tool)),
                    ],
                  ),
                ),
              ],
              if (widget.course.capstoneProject.isNotEmpty) ...[
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
                    title: Text(
                      module.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(module.summary),
                    children: [
                      for (final lesson in module.lessons.where(
                        (lesson) => _visibleLessons.contains(lesson),
                      ))
                        ListTile(
                          leading: Icon(
                            widget.store.completedLessons.contains(lesson.id)
                                ? Icons.check_circle
                                : Icons.play_circle_outline,
                            color: _blue,
                          ),
                          title: Text(lesson.title),
                          subtitle: Text(
                            widget.store.completedLessons.contains(lesson.id)
                                ? '${lesson.difficulty.label} · Completed'
                                : lesson.difficulty.label,
                          ),
                          trailing: const Icon(Icons.chevron_right),
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
                          label: const Text(
                            'Practice questions and module quiz',
                          ),
                          onPressed: () =>
                              _push(context, ModuleQuizPage(module: module)),
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
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed:
                      widget.course.allLessons.every(
                        (lesson) =>
                            widget.store.completedLessons.contains(lesson.id),
                      )
                      ? () => _push(
                          context,
                          MockTestPage(
                            subject: widget.course.quizSubject!,
                            store: widget.store,
                            courseId: widget.course.id,
                            questions: widget.course.finalQuestions,
                            mode: TestMode.exam,
                          ),
                        )
                      : null,
                  icon: const Icon(Icons.fact_check),
                  label: Text(
                    widget.store.passedCourseAssessments.contains(
                          widget.course.id,
                        )
                        ? 'Retake final assessment'
                        : 'Start final assessment',
                  ),
                ),
                if (widget.store.certificateFor(widget.course) != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Download certificate'),
                    onPressed: () => _downloadCertificate(
                      context,
                      widget.store.certificateFor(widget.course)!,
                    ),
                  ),
                if (widget.store.isCourseComplete(widget.course))
                  const ListTile(
                    leading: Icon(Icons.verified, color: Colors.green),
                    title: Text('Course requirements completed'),
                    subtitle: Text(
                      'This is a Learning App progress record, not a vendor certification.',
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class LessonPage extends StatelessWidget {
  const LessonPage({
    super.key,
    required this.lesson,
    required this.store,
    this.courseLessons = const [],
  });

  final Lesson lesson;
  final AppStore store;
  final List<Lesson> courseLessons;

  @override
  Widget build(BuildContext context) {
    final lessonIndex = courseLessons.indexWhere(
      (item) => item.id == lesson.id,
    );
    final canNavigate = lessonIndex >= 0;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Chip(label: Text(lesson.difficulty.label)),
          const _SectionHeading(title: 'Topic introduction and explanation'),
          const SizedBox(height: 8),
          Text(lesson.summary, style: const TextStyle(fontSize: 16)),
          if (lesson.topics.isNotEmpty) ...[
            const SizedBox(height: 18),
            const _SectionHeading(title: 'Topics'),
            const SizedBox(height: 6),
            for (final topic in lesson.topics)
              ListTile(
                dense: true,
                leading: const Icon(Icons.circle, size: 8, color: _blue),
                title: Text(topic),
              ),
          ],
          const SizedBox(height: 20),
          const _SectionHeading(title: 'Example'),
          const SizedBox(height: 8),
          _CodeBlock(text: lesson.example),
          if (lesson.expectedOutput != null) ...[
            const SizedBox(height: 10),
            const _SectionHeading(title: 'Expected output'),
            const SizedBox(height: 6),
            Text(lesson.expectedOutput!),
          ],
          if (lesson.exercise != null) ...[
            const SizedBox(height: 18),
            const _SectionHeading(title: 'Practical exercise'),
            const SizedBox(height: 6),
            Text(lesson.exercise!),
          ],
          if (lesson.industryUse != null) ...[
            const SizedBox(height: 18),
            const _SectionHeading(title: 'Industry application'),
            const SizedBox(height: 6),
            Text(lesson.industryUse!),
          ],
          const SizedBox(height: 18),
          const _SectionHeading(title: 'Key points to remember'),
          const SizedBox(height: 6),
          Text(lesson.summary.split('. ').last),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              await store.markLessonComplete(lesson.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lesson marked complete.')),
                );
              }
            },
            icon: const Icon(Icons.check),
            label: const Text('Mark lesson complete'),
          ),
          if (canNavigate) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: lessonIndex == 0
                      ? null
                      : () => _push(
                          context,
                          LessonPage(
                            lesson: courseLessons[lessonIndex - 1],
                            store: store,
                            courseLessons: courseLessons,
                          ),
                        ),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous lesson'),
                ),
                FilledButton.icon(
                  onPressed: lessonIndex == courseLessons.length - 1
                      ? null
                      : () => _push(
                          context,
                          LessonPage(
                            lesson: courseLessons[lessonIndex + 1],
                            store: store,
                            courseLessons: courseLessons,
                          ),
                        ),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next lesson'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class ModuleQuizPage extends StatefulWidget {
  const ModuleQuizPage({super.key, required this.module});

  final CourseModule module;

  @override
  State<ModuleQuizPage> createState() => _ModuleQuizPageState();
}

class _ModuleQuizPageState extends State<ModuleQuizPage> {
  final Map<String, int> _answers = {};
  bool _submitted = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('${widget.module.title} quiz')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(widget.module.summary),
        const SizedBox(height: 16),
        for (final question in widget.module.questions) ...[
          Text(
            question.prompt,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          for (var i = 0; i < question.options.length; i++)
            ListTile(
              leading: Icon(
                _answers[question.id] == i
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
              ),
              title: Text(question.options[i]),
              onTap: _submitted
                  ? null
                  : () => setState(() => _answers[question.id] = i),
            ),
          if (_submitted) ...[
            Text(
              _answers[question.id] == question.answerIndex
                  ? 'Correct'
                  : 'Review this answer',
            ),
            Text(question.explanation),
          ],
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: _answers.length == widget.module.questions.length
              ? () => setState(() {
                  if (_submitted) _answers.clear();
                  _submitted = !_submitted;
                })
              : null,
          child: Text(_submitted ? 'Try again' : 'Check answers'),
        ),
        const SizedBox(height: 20),
        const _SectionHeading(title: 'Module assignment'),
        Text(widget.module.assignment),
      ],
    ),
  );
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
        icon: Icons.library_books,
        title: 'Interview questions',
        subtitle: '${interviewQuestions.length} questions across five topics',
        onTap: () => _push(context, InterviewQuestionsPage(store: store)),
      ),
      _FeatureTile(
        icon: Icons.record_voice_over,
        title: 'Mock interviews',
        subtitle: 'Answer prompts and get deterministic keyword feedback',
        onTap: () => _push(context, MockInterviewTopicsPage()),
      ),
      _FeatureTile(
        icon: Icons.timer,
        title: 'Mock tests',
        subtitle: '10 multiple-choice questions with a countdown',
        onTap: () => _push(context, MockTestTopicsPage(store: store)),
      ),
      _FeatureTile(
        icon: Icons.bookmark_outline,
        title: 'Saved questions',
        subtitle: '${store.bookmarks.length} bookmarked',
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.savedOnly ? 'Saved questions' : 'Question bank'),
    ),
    body: ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final categories = interviewQuestions
            .map((question) => question.category)
            .toSet()
            .toList();
        final questions = interviewQuestions.where((question) {
          final matchesText = question.question.toLowerCase().contains(
            _query.toLowerCase(),
          );
          final matchesCategory =
              _category == 'All' || question.category == _category;
          final matchesDifficulty =
              _difficulty == 'All' || question.difficulty == _difficulty;
          final matchesSaved =
              !widget.savedOnly || widget.store.bookmarks.contains(question.id);
          return matchesText &&
              matchesCategory &&
              matchesDifficulty &&
              matchesSaved;
        }).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search questions',
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _FilterChip(
                    label: _category,
                    options: ['All', ...categories],
                    onSelected: (value) => setState(() => _category = value),
                  ),
                  _FilterChip(
                    label: _difficulty,
                    options: const ['All', 'Basic', 'Intermediate', 'Advanced'],
                    onSelected: (value) => setState(() => _difficulty = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: questions.isEmpty
                  ? const _EmptyState(
                      icon: Icons.search_off,
                      title: 'No questions found',
                      subtitle: 'Try a different search or remove a filter.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: questions.length,
                      itemBuilder: (context, index) => Card(
                        child: ListTile(
                          title: Text(questions[index].question),
                          subtitle: Text(
                            '${questions[index].category} · ${questions[index].difficulty}',
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
  InterviewQuestion get _question => widget.questions[_index];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${_index + 1} of ${widget.questions.length}'),
      actions: [
        ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) => IconButton(
            tooltip: widget.store.bookmarks.contains(_question.id)
                ? 'Remove bookmark'
                : 'Save question',
            onPressed: () => widget.store.toggleBookmark(_question.id),
            icon: Icon(
              widget.store.bookmarks.contains(_question.id)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Chip(label: Text('${_question.category} · ${_question.difficulty}')),
        const SizedBox(height: 14),
        Text(
          _question.question,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        const _SectionHeading(title: 'Answer'),
        const SizedBox(height: 8),
        Text(_question.answer, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 18),
        const _SectionHeading(title: 'Explanation'),
        const SizedBox(height: 8),
        Text(_question.explanation),
        if (_question.code != null) ...[
          const SizedBox(height: 18),
          const _SectionHeading(title: 'Example'),
          const SizedBox(height: 8),
          _CodeBlock(text: _question.code!),
        ],
        if (_question.output != null) ...[
          const SizedBox(height: 10),
          Text('Expected output: ${_question.output}'),
        ],
        const SizedBox(height: 26),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _index == 0 ? null : () => setState(() => _index -= 1),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _index == widget.questions.length - 1
                  ? null
                  : () => setState(() => _index += 1),
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
        for (final subject in quizBankSubjects)
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
  String _difficulty = 'All levels';
  TestMode _mode = TestMode.exam;

  List<QuizQuestion> get _filteredQuestions {
    final subjectQuestions = _quizQuestionsForSubject(widget.subject);
    if (_difficulty == 'All levels') return subjectQuestions.toList();
    return subjectQuestions
        .where((question) => question.difficulty == _difficulty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final available = _filteredQuestions;
    final canStart = available.length >= _questionCount;
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
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _difficulty,
            decoration: const InputDecoration(labelText: 'Difficulty'),
            items: const ['All levels', 'Basic', 'Intermediate', 'Advanced']
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
            children: [10, 20, 30, 50].map((count) {
              final enabled = available.length >= count;
              return ChoiceChip(
                label: Text('$count Questions'),
                selected: _questionCount == count,
                onSelected: enabled
                    ? (_) => setState(() => _questionCount = count)
                    : null,
              );
            }).toList(),
          ),
          if (!canStart)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'This selection has ${available.length} unique questions. '
                'Add more questions to the bank before starting a $_questionCount-question test.',
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
            'Each question is worth one mark. The timer is two minutes per question. '
            'Practice mode reveals the answer and explanation after each response. '
            'Exam mode hides answers until submission. The exam submits automatically when time expires.',
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: canStart
                ? () {
                    final shuffled = List<QuizQuestion>.of(available)
                      ..shuffle(math.Random());
                    _push(
                      context,
                      MockTestPage(
                        subject: widget.subject,
                        questions: shuffled.take(_questionCount).toList(),
                        store: widget.store,
                        mode: _mode,
                        courseId: widget.courseId,
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(
              'Start ${_mode == TestMode.practice ? 'practice' : 'exam'}',
            ),
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
  });

  final String subject;
  final List<QuizQuestion> questions;
  final AppStore store;
  final TestMode mode;
  final String? courseId;

  @override
  State<MockTestPage> createState() => _MockTestPageState();
}

class _MockTestPageState extends State<MockTestPage> {
  Duration get _duration => Duration(minutes: widget.questions.length * 2);

  final Map<String, int> _answers = {};
  final Set<int> _marked = {};
  final Set<String> _revealed = {};
  late Duration _remaining = _duration;
  late final Timer _timer;
  int _index = 0;
  bool _submitting = false;

  QuizQuestion get _question => widget.questions[_index];
  bool get _isPractice => widget.mode == TestMode.practice;
  bool get _currentRevealed => _revealed.contains(_question.id);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= const Duration(seconds: 1)) {
        _remaining = Duration.zero;
        _timer.cancel();
        _submit();
      } else {
        setState(() => _remaining -= const Duration(seconds: 1));
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.subject),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Text(
              _formatDuration(_remaining.inSeconds),
              style: const TextStyle(color: _blue, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        LinearProgressIndicator(value: (_index + 1) / widget.questions.length),
        const SizedBox(height: 14),
        Row(
          children: [
            Text(
              'Question ${_index + 1} of ${widget.questions.length} · '
              '${_question.difficulty}',
            ),
            if (!_isPractice) ...[
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() {
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
              setState(() => _answers[_question.id] = value);
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
              return OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: index == _index
                      ? _paleBlue
                      : _marked.contains(index)
                      ? const Color(0xFFFFF3CD)
                      : answered
                      ? const Color(0xFFE6F4EA)
                      : null,
                  minimumSize: const Size(42, 42),
                  padding: EdgeInsets.zero,
                ),
                onPressed: () => setState(() => _index = index),
                child: Text('${index + 1}'),
              );
            }),
          ),
        const SizedBox(height: 22),
        Row(
          children: [
            OutlinedButton(
              onPressed: _isPractice || _index == 0
                  ? null
                  : () => setState(() => _index -= 1),
              child: const Text('Previous'),
            ),
            const Spacer(),
            if (_isPractice)
              FilledButton(
                onPressed: _currentRevealed
                    ? _index < widget.questions.length - 1
                          ? () => setState(() => _index += 1)
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
            else if (_index < widget.questions.length - 1)
              FilledButton(
                onPressed: () => setState(() => _index += 1),
                child: const Text('Next'),
              )
            else
              FilledButton(
                onPressed: _confirmSubmit,
                child: const Text('Submit exam'),
              ),
          ],
        ),
      ],
    ),
  );

  void _revealPracticeAnswer() {
    setState(() => _revealed.add(_question.id));
  }

  Future<void> _confirmSubmit() async {
    if (_isPractice) {
      await _submit();
      return;
    }
    final unanswered = widget.questions.length - _answers.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
    if (confirmed == true) await _submit();
  }

  Future<void> _submit() async {
    if (_submitting || !mounted) return;
    _submitting = true;
    _timer.cancel();
    final attempt = TestAttempt(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      subject: widget.subject,
      completedAt: DateTime.now(),
      selections: Map.of(_answers),
      questionIds: widget.questions.map((question) => question.id).toList(),
      durationSeconds: math.max(0, _duration.inSeconds - _remaining.inSeconds),
      mode: widget.mode.name,
      courseId: widget.courseId,
    );
    try {
      await widget.store.saveAttempt(attempt);
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
    } catch (error) {
      _submitting = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save your result: $error')),
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
              color: store.passedCourseAssessments.contains(courseId)
                  ? const Color(0xFFE6F4EA)
                  : _paleBlue,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  store.passedCourseAssessments.contains(courseId)
                      ? 'Final assessment passed (70% threshold). Course completion also requires all lessons.'
                      : 'Final assessment pass mark: 70%. Complete all course lessons to finish the course.',
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
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
            Text(
              '${index + 1}. ${question.prompt}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              selected == null
                  ? 'Unanswered'
                  : '${isCorrect ? 'Correct' : 'Your answer'}: ${question.options[selected!]}',
              style: TextStyle(color: isCorrect ? Colors.green : Colors.red),
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

class MockInterviewTopicsPage extends StatelessWidget {
  const MockInterviewTopicsPage({super.key});

  static const _topics = [
    'Python',
    'SQL',
    'Machine Learning',
    'Data Science',
    'Technical Interview',
    'HR Interview',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mock interviews')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Practice timed prompts. Feedback is based on relevant terms in your response, not generative AI.',
          ),
        ),
        for (final topic in _topics)
          Card(
            child: ListTile(
              leading: const Icon(Icons.record_voice_over, color: _blue),
              title: Text(topic),
              subtitle: const Text('3 prompts · 5 minutes each'),
              trailing: const Icon(Icons.play_arrow),
              onTap: () => _push(
                context,
                MockInterviewPage(
                  subject: topic,
                  questions: _interviewPromptsFor(topic),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class InterviewPrompt {
  const InterviewPrompt(this.question, this.answer, this.keywords);

  final String question;
  final String answer;
  final List<String> keywords;
}

List<InterviewPrompt> _interviewPromptsFor(String topic) {
  if (topic == 'Data Science') {
    return const [
      InterviewPrompt(
        'How do you investigate missing values in a dataset?',
        'Measure missingness by field and cohort, investigate how values became missing, then choose a documented strategy that fits the analysis and validate its impact.',
        ['missingness', 'cohort', 'strategy', 'validate'],
      ),
      InterviewPrompt(
        'How would you communicate a correlation to a non-technical audience?',
        'Explain the direction and strength of the observed association, identify plausible confounders, and state that correlation alone does not establish causation.',
        ['association', 'confounders', 'correlation', 'causation'],
      ),
      InterviewPrompt(
        'What checks do you perform before presenting an analysis?',
        'Validate source coverage and data types, check duplicates and outliers, reproduce key calculations, then summarize uncertainty and limitations.',
        ['coverage', 'duplicates', 'reproduce', 'limitations'],
      ),
    ];
  }
  final category = switch (topic) {
    'Python' => 'Python Programming',
    'SQL' => 'SQL',
    'Machine Learning' => 'Machine Learning',
    'HR Interview' => 'HR and Interview Questions',
    'Technical Interview' => 'Technical Questions',
    _ => 'Data Science',
  };
  final source = interviewQuestions
      .where((question) => question.category == category)
      .toList();
  final prompts = source
      .map(
        (question) => InterviewPrompt(
          question.question,
          question.answer,
          _keywordsFor(question),
        ),
      )
      .toList();
  if (prompts.length >= 3) return prompts.take(3).toList();
  return [
    ...prompts,
    const InterviewPrompt(
      'How would you approach a problem you have not seen before?',
      'Clarify the goal and constraints, break the problem into smaller parts, explain assumptions, test a simple solution and improve it using evidence.',
      ['goal', 'constraints', 'test', 'assumptions'],
    ),
    const InterviewPrompt(
      'How do you check that your solution is reliable?',
      'Use focused tests, cover edge cases, inspect failures and monitor the behavior against the requirements.',
      ['test', 'edge', 'requirements', 'failures'],
    ),
    const InterviewPrompt(
      'How do you explain a technical decision?',
      'Describe the requirements, options and trade-offs, explain why the chosen approach fits and note its limitations.',
      ['requirements', 'trade-offs', 'approach', 'limitations'],
    ),
  ].take(3).toList();
}

List<String> _keywordsFor(InterviewQuestion question) {
  final words = <String>[];
  for (final candidate in [
    'mutable',
    'immutable',
    'lazy',
    'memory',
    'identity',
    'equality',
    'resource',
    'exception',
    'training',
    'validation',
    'test',
    'regularization',
    'precision',
    'recall',
    'unknown',
    'rows',
    'groups',
    'index',
    'storage',
    'transaction',
    'authorization',
    'identity',
    'status',
    'cache',
    'feedback',
    'example',
    'action',
    'result',
    'priority',
    'stakeholder',
  ]) {
    if (question.answer.toLowerCase().contains(candidate)) words.add(candidate);
  }
  return words.take(4).toList();
}

class MockInterviewPage extends StatefulWidget {
  const MockInterviewPage({
    super.key,
    required this.subject,
    required this.questions,
  });

  final String subject;
  final List<InterviewPrompt> questions;

  @override
  State<MockInterviewPage> createState() => _MockInterviewPageState();
}

class _MockInterviewPageState extends State<MockInterviewPage> {
  static const _questionDuration = Duration(minutes: 5);
  final _answerController = TextEditingController();
  late final List<Duration> _elapsed = List.filled(
    widget.questions.length,
    Duration.zero,
  );
  late Duration _remaining = _questionDuration;
  Timer? _timer;
  int _index = 0;
  bool _showFeedback = false;

  InterviewPrompt get _prompt => widget.questions[_index];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= const Duration(seconds: 1)) {
        setState(() {
          _remaining = Duration.zero;
          _elapsed[_index] += const Duration(seconds: 1);
          _showFeedback = true;
        });
        timer.cancel();
        return;
      }
      setState(() {
        _remaining -= const Duration(seconds: 1);
        _elapsed[_index] += const Duration(seconds: 1);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('${widget.subject} interview'),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(child: Text(_formatDuration(_remaining.inSeconds))),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Question ${_index + 1} of ${widget.questions.length}'),
        const SizedBox(height: 12),
        Text(
          _prompt.question,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _answerController,
          minLines: 5,
          maxLines: 10,
          decoration: const InputDecoration(
            alignLabelWithHint: true,
            labelText: 'Your answer',
            hintText: 'Write your answer in your own words.',
          ),
          onChanged: (_) {
            if (_showFeedback) setState(() => _showFeedback = false);
          },
        ),
        const SizedBox(height: 12),
        if (_showFeedback) ...[
          _FeedbackCard(prompt: _prompt, response: _answerController.text),
          const SizedBox(height: 12),
          const _SectionHeading(title: 'Reference answer'),
          const SizedBox(height: 6),
          Text(_prompt.answer),
          const SizedBox(height: 12),
        ],
        FilledButton(
          onPressed: _showFeedback
              ? _next
              : () => setState(() => _showFeedback = true),
          child: Text(
            _showFeedback
                ? _index == widget.questions.length - 1
                      ? 'End interview'
                      : 'Next question'
                : 'Review my answer',
          ),
        ),
      ],
    ),
  );

  void _next() {
    if (_index == widget.questions.length - 1) {
      final averageSeconds =
          _elapsed.fold<int>(
            0,
            (total, duration) => total + duration.inSeconds,
          ) ~/
          widget.questions.length;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => InterviewSummaryPage(
            subject: widget.subject,
            questions: widget.questions,
            averageSeconds: averageSeconds,
          ),
        ),
      );
      return;
    }
    setState(() {
      _index++;
      _remaining = _questionDuration;
      _answerController.clear();
      _showFeedback = false;
    });
    _startTimer();
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.prompt, required this.response});

  final InterviewPrompt prompt;
  final String response;

  @override
  Widget build(BuildContext context) {
    final normalized = response.toLowerCase();
    final found = prompt.keywords
        .where((keyword) => normalized.contains(keyword.toLowerCase()))
        .toList();
    final missing = prompt.keywords
        .where((keyword) => !found.contains(keyword))
        .toList();
    return Card(
      color: _paleBlue,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              response.trim().isEmpty
                  ? 'No answer entered. Read the reference answer and try again.'
                  : 'Your answer included ${found.length} of ${prompt.keywords.length} key ideas.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (missing.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Consider covering: ${missing.join(', ')}.'),
              ),
            const SizedBox(height: 5),
            const Text(
              'This checklist is a deterministic study aid, not an assessment of answer quality.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class InterviewSummaryPage extends StatelessWidget {
  const InterviewSummaryPage({
    super.key,
    required this.subject,
    required this.questions,
    required this.averageSeconds,
  });

  final String subject;
  final List<InterviewPrompt> questions;
  final int averageSeconds;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Interview summary')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '$subject practice complete',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '${questions.length} prompts · average ${_formatDuration(averageSeconds)} per prompt',
        ),
        const SizedBox(height: 20),
        const _SectionHeading(title: 'Suggestions for next time'),
        const SizedBox(height: 8),
        const Text(
          'Structure each response with a clear point, supporting detail and an example. Compare your notes with the reference answers and revisit any concepts you missed.',
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < questions.length; index++)
          Card(
            child: ListTile(
              title: Text(questions[index].question),
              subtitle: Text(questions[index].answer),
            ),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
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
        if (_sort == 'Oldest') {
          attempts.sort((a, b) => a.completedAt.compareTo(b.completedAt));
        } else if (_sort == 'Highest score') {
          attempts.sort((a, b) => _score(b).compareTo(_score(a)));
        } else {
          attempts.sort((a, b) => b.completedAt.compareTo(a.completedAt));
        }
        if (attempts.isEmpty) {
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
                itemCount: attempts.length,
                itemBuilder: (context, index) {
                  final attempt = attempts[index];
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
                ('Overall accuracy', '${average.round()}%'),
              ],
            ),
            const SizedBox(height: 20),
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
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Global'),
            Tab(text: 'Weekly'),
            Tab(text: 'Monthly'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          _LeaderboardTab(entries: store.leaderboardFor('global')),
          _LeaderboardTab(entries: store.leaderboardFor('weekly')),
          _LeaderboardTab(entries: store.leaderboardFor('monthly')),
        ],
      ),
    ),
  );
}

class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(16),
    itemCount: entries.length,
    separatorBuilder: (_, _) => const SizedBox(height: 8),
    itemBuilder: (context, index) {
      final entry = entries[index];
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: index == 0 ? const Color(0xFFFFD54F) : _paleBlue,
            child: Text('${index + 1}'),
          ),
          title: Text(entry.name),
          subtitle: Text(entry.badge),
          trailing: Text(
            '${entry.score} pts',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    },
  );
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
                    leading: const CircleAvatar(
                      backgroundColor: _paleBlue,
                      child: Icon(Icons.workspace_premium, color: _blue),
                    ),
                    title: Text(course.title),
                    subtitle: Text(
                      '${store.certificateFor(course)?.studentName ?? store.displayName} · ${store.certificateFor(course)?.id ?? ''}',
                    ),
                    trailing: const Icon(Icons.download),
                    onTap: () => _downloadCertificate(
                      context,
                      store.certificateFor(course)!,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

Future<Uint8List> buildCertificatePdf(CourseCertificate certificate) async {
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  );
  final fallback = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf'),
  );
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: font,
      bold: font,
      fontFallback: [fallback],
    ),
    title: '${certificate.courseName} completion certificate',
    author: 'SkillVerse',
  );
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(32),
      build: (_) => pw.Container(
        padding: const pw.EdgeInsets.all(28),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.blue800, width: 2),
        ),
        child: pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'SkillVerse',
                style: pw.TextStyle(
                  fontSize: 28,
                  color: PdfColors.blue800,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'COURSE COMPLETION CERTIFICATE',
                style: const pw.TextStyle(fontSize: 15),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'This certifies that',
                style: const pw.TextStyle(fontSize: 15),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                certificate.studentName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Text(
                'completed all lessons and passed the final assessment in',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 13),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                certificate.courseName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 22,
                  color: PdfColors.blue900,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 22),
              pw.Text(
                '${certificate.completionDateKnown ? 'Completed on' : 'Completion recorded on'} ${certificate.completedAt.toLocal().toIso8601String().substring(0, 10)}',
                style: const pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Certificate ID  ${certificate.id}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return doc.save();
}

Future<void> _downloadCertificate(
  BuildContext context,
  CourseCertificate certificate,
) async {
  try {
    final bytes = await buildCertificatePdf(certificate);
    final filename = 'skillverse_${certificate.id}.pdf';
    final String? filePath;
    if (Platform.isAndroid) {
      filePath = await const MethodChannel(
        'skillverse/certificates',
      ).invokeMethod<String>('savePdf', {'bytes': bytes, 'filename': filename});
    } else {
      final directory =
          await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
      filePath = '${directory.path}/$filename';
      await File(filePath).writeAsBytes(bytes, flush: true);
    }
    if (filePath == null) return;
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Certificate saved to $filePath')));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save certificate: $error')),
      );
    }
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
                      onTap: () => _showProject(context, project),
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
        if (!store.isAuthenticated)
          _FeatureTile(
            icon: Icons.login,
            title: 'Login / Sign in',
            subtitle: 'Access your SkillVerse account',
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
            subtitle: 'Sign out of your SkillVerse account',
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
          subtitle: 'App data is stored locally',
          onTap: () => _showLocalStorageInfo(context),
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
    final completed = lessons
        .where((lesson) => store.completedLessons.contains(lesson.id))
        .length;
    final total = lessons.length;
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
      Text(
        title,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: Colors.black54)),
    ],
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      child: Chip(
        label: Text(label),
        avatar: const Icon(Icons.filter_list, size: 18),
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

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF182238),
      borderRadius: BorderRadius.circular(14),
    ),
    child: SelectableText(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'monospace',
        height: 1.5,
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
  final controller = TextEditingController(text: store.displayName);
  final name = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit profile name'),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 40,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || !context.mounted) return;
  try {
    await store.updateDisplayName(name);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update your profile: $error')),
      );
    }
  }
}

Future<void> _editProject(
  BuildContext context,
  AppStore store, {
  StudentProject? project,
}) async {
  final titleController = TextEditingController(text: project?.title ?? '');
  final descriptionController = TextEditingController(
    text: project?.description ?? '',
  );
  final technologiesController = TextEditingController(
    text: project?.technologies ?? '',
  );
  final githubController = TextEditingController(
    text: project?.githubUrl ?? '',
  );
  var category = project?.category ?? 'Python';
  final formKey = GlobalKey<FormState>();
  final saved = await showDialog<StudentProject>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(project == null ? 'Add project' : 'Edit project'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a project title.'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a description.'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items:
                        const [
                              'Python',
                              'SQL',
                              'Machine Learning',
                              'Data Science',
                              'AI',
                              'Flutter',
                              'Web Development',
                              'Other',
                            ]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => category = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: technologiesController,
                    decoration: const InputDecoration(
                      labelText: 'Technologies',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: githubController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'GitHub URL (optional)',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final uri = Uri.tryParse(value.trim());
                      return uri == null ||
                              !uri.hasScheme ||
                              !uri.host.contains('.')
                          ? 'Enter a valid URL.'
                          : null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                dialogContext,
                StudentProject(
                  id:
                      project?.id ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim(),
                  category: category,
                  technologies: technologiesController.text.trim(),
                  githubUrl: githubController.text.trim(),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  titleController.dispose();
  descriptionController.dispose();
  technologiesController.dispose();
  githubController.dispose();
  if (saved == null) return;
  try {
    await store.saveProject(saved);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save project: $error')));
    }
  }
}

Future<void> _confirmDelete(
  BuildContext context,
  AppStore store,
  StudentProject project,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete project?'),
      content: Text('Remove "${project.title}" from this device?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await store.deleteProject(project.id);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete project: $error')),
      );
    }
  }
}

void _showProject(BuildContext context, StudentProject project) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text(
            project.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(project.category),
          const SizedBox(height: 12),
          Text(project.description),
          if (project.technologies.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Technologies: ${project.technologies}'),
          ],
          if (project.githubUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            SelectableText('GitHub: ${project.githubUrl}'),
          ],
        ],
      ),
    ),
  );
}

void _showLocalStorageInfo(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: 'SkillVerse',
    applicationVersion: '1.0.0',
    children: const [
      Text(
        'Course progress, bookmarks, project details, profile name and test history are stored locally on this device.',
      ),
      SizedBox(height: 8),
      Text('Cloud sign-in and file uploads are not configured in this build.'),
    ],
  );
}

void _openSavedResult(
  BuildContext context,
  TestAttempt attempt,
  AppStore store,
) {
  final questionById = {
    for (final question in [...quizQuestions, ...courseAssessmentQuestions])
      question.id: question,
  };
  final questions = attempt.questionIds
      .map((id) => questionById[id])
      .whereType<QuizQuestion>()
      .toList();
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

int _score(TestAttempt attempt) {
  final questionById = {
    for (final question in [...quizQuestions, ...courseAssessmentQuestions])
      question.id: question,
  };
  if (attempt.total == 0) return 0;
  final correct = attempt.questionIds.where((id) {
    final question = questionById[id];
    return question != null && attempt.selections[id] == question.answerIndex;
  }).length;
  return (100 * correct / attempt.total).round();
}

double _average(List<int> values) =>
    values.reduce((a, b) => a + b) / values.length;

IconData _courseIcon(String title) => switch (title) {
  'Python' || 'Python Programming' => Icons.code,
  'SQL' => Icons.storage,
  'Machine Learning' => Icons.memory,
  'Data Science' => Icons.query_stats,
  'Artificial Intelligence' => Icons.psychology,
  'Data Structures and Algorithms' => Icons.account_tree,
  'Databricks' => Icons.dataset,
  'PySpark' => Icons.memory,
  'Azure DevOps' => Icons.cloud_sync,
  'Git and GitHub' => Icons.merge_type,
  _ => Icons.computer,
};

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
