import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai/ui/ai_studio_screen.dart';
import '../../features/home/ui/home_screen.dart';
import '../../features/questions/ui/question_screen.dart';
import '../../features/presentation/models/presentation_settings.dart';
import '../../features/presentation/ui/presentation_screen.dart';
import '../../features/scripts/models/script_enums.dart';
import '../../features/scripts/ui/editor_screen.dart';
import '../../features/scripts/ui/library_screen.dart';
import '../../features/settings/ui/settings_screen.dart';
import '../../features/wearables/ui/glasses_connection_screen.dart';
import 'app_shell.dart';

abstract final class Routes {
  static const home = '/';
  static const library = '/library';
  static const settings = '/settings';
  static const studio = '/studio';
  static const glasses = '/glasses';
  static const questions = '/questions';

  static String editor(String id) => '/editor/$id';

  static String newScript([ScriptKind kind = ScriptKind.script]) =>
      '/editor/new?kind=${kind.name}';

  static String present(String id, {PresentationMode? mode}) =>
      '/present/$id${mode == null ? '' : '?mode=${mode.name}'}';
}

GoRouter buildRouter() {
  final rootKey = GlobalKey<NavigatorState>();

  Page<void> fade(GoRouterState state, Widget child) => CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.library,
                builder: (_, _) => const LibraryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: Routes.questions,
        builder: (_, _) => const QuestionScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: Routes.studio,
        builder: (_, _) => const AiStudioScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/editor/:id',
        builder: (_, state) {
          final id = state.pathParameters['id']!;
          return EditorScreen(
            scriptId: id == 'new' ? null : id,
            newKind: ScriptKind.fromName(state.uri.queryParameters['kind']),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/present/:id',
        pageBuilder: (_, state) => fade(
          state,
          PresentationScreen(
            scriptId: state.pathParameters['id']!,
            mode: state.uri.queryParameters['mode'] == null
                ? null
                : PresentationMode.fromName(state.uri.queryParameters['mode']),
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: Routes.glasses,
        builder: (_, _) => const GlassesConnectionScreen(),
      ),
    ],
  );
}
