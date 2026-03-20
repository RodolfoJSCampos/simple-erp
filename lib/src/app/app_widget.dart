import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/dashboard/presentation/pages/dashboard_page.dart';
import 'dependencies.dart';

class AppWidget extends StatefulWidget {
  const AppWidget({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {
  bool _showBootSplash = true;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showBootSplash = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Simple ERP',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: colorScheme.onSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: colorScheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          late final Widget currentScreen;

          if (_showBootSplash ||
              snapshot.connectionState == ConnectionState.waiting) {
            currentScreen = const _EntrySplashScreen(
              key: ValueKey('entry-splash'),
            );
          } else if (snapshot.data == null) {
            currentScreen = const LoginPage(key: ValueKey('login-screen'));
          } else {
            currentScreen = _PostLoginSplashGate(
              key: ValueKey('post-login-${snapshot.data!.uid}'),
              userId: snapshot.data!.uid,
              child: DashboardPage(
                productController: widget.dependencies.productController,
                orderController: widget.dependencies.orderController,
                usingFirebase: widget.dependencies.usingFirebase,
              ),
            );
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 520),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final fade = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              );
              final slide =
                  Tween<Offset>(
                    begin: const Offset(0, 0.03),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  );
              return FadeTransition(
                opacity: fade,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: currentScreen,
          );
        },
      ),
    );
  }
}

class _PostLoginSplashGate extends StatefulWidget {
  const _PostLoginSplashGate({
    super.key,
    required this.userId,
    required this.child,
  });

  final String userId;
  final Widget child;

  @override
  State<_PostLoginSplashGate> createState() => _PostLoginSplashGateState();
}

class _PostLoginSplashGateState extends State<_PostLoginSplashGate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _ready = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return widget.child;
    }
    return const _PostLoginSplashScreen(key: ValueKey('post-login-splash'));
  }
}

class _EntrySplashScreen extends StatelessWidget {
  const _EntrySplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SplashFrame(
      backgroundColor: const Color(0xFFF8FAFC),
      accentColor: const Color(0xFF2563EB),
      title: 'Simple ERP',
      subtitle: 'Organize estoque e pedidos com simplicidade.',
      icon: Icons.inventory_2_rounded,
    );
  }
}

class _PostLoginSplashScreen extends StatelessWidget {
  const _PostLoginSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _SplashFrame(
      backgroundColor: const Color(0xFFF8FAFC),
      accentColor: const Color(0xFF0EA5A4),
      title: 'Tudo pronto',
      subtitle: 'Carregando seu painel.',
      icon: Icons.dashboard_customize_rounded,
    );
  }
}

class _SplashFrame extends StatefulWidget {
  const _SplashFrame({
    required this.backgroundColor,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final Color backgroundColor;
  final Color accentColor;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  State<_SplashFrame> createState() => _SplashFrameState();
}

class _SplashFrameState extends State<_SplashFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentSlide;
  late final Animation<double> _markScale;
  late final Animation<double> _markGlow;
  late final Animation<double> _orbitTurns;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..forward();

    _contentOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.05, 0.42, curve: Curves.easeOutCubic),
    );
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.05, 0.42, curve: Curves.easeOutCubic),
          ),
        );
    _markScale = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.20, 0.88, curve: Curves.easeOutBack),
      ),
    );
    _markGlow = Tween<double>(begin: 0.02, end: 0.20).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _orbitTurns = Tween<double>(begin: 0, end: 0.65).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.95, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value.clamp(0.0, 1.0);
          final scheme = Theme.of(context).colorScheme;

          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: widget.backgroundColor),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.0, -0.22),
                      radius: 1.1,
                      colors: [
                        widget.accentColor.withValues(alpha: 0.12),
                        widget.backgroundColor,
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: FadeTransition(
                    opacity: _contentOpacity,
                    child: SlideTransition(
                      position: _contentSlide,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 128,
                            height: 128,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Transform.scale(
                                  scale: _markScale.value,
                                  child: Container(
                                    width: 112,
                                    height: 112,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: widget.accentColor.withValues(
                                          alpha: 0.24,
                                        ),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: widget.accentColor.withValues(
                                            alpha: _markGlow.value,
                                          ),
                                          blurRadius: 24,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                RotationTransition(
                                  turns: _orbitTurns,
                                  child: SizedBox(
                                    width: 118,
                                    height: 118,
                                    child: Stack(
                                      children: [
                                        Align(
                                          alignment: Alignment.topCenter,
                                          child: _OrbitDot(
                                            color: widget.accentColor,
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: _OrbitDot(
                                            color: widget.accentColor
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.bottomCenter,
                                          child: _OrbitDot(
                                            color: widget.accentColor
                                                .withValues(alpha: 0.45),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                _BrandBadge(
                                  icon: widget.icon,
                                  color: widget.accentColor,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 120,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 3,
                                value: progress,
                                backgroundColor: widget.accentColor.withValues(
                                  alpha: 0.12,
                                ),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  widget.accentColor,
                                ),
                              ),
                            ),
                          ),
                        ],
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
}

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 1),
      ),
      child: Icon(icon, color: color, size: 36),
    );
  }
}

class _OrbitDot extends StatelessWidget {
  const _OrbitDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
