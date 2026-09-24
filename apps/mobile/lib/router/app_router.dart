import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth_controller.dart';
import '../core/page_chrome.dart';
import '../core/app_theme.dart';
import '../features/analysis/analysis_page.dart';
import '../features/ai/ai_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/discover/discover_page.dart';
import '../features/discover/style_catalog.dart';
import '../features/discover/style_page.dart';
import '../features/home/home_page.dart';
import '../features/me/account_pages.dart';
import '../features/me/me_page.dart';
import '../features/shell/app_shell.dart';
import '../features/chat/chat_page.dart';
import '../features/layouts/layouts_page.dart';
import '../features/profile/profile_page.dart';
import '../features/projects/new_project_page.dart';
import '../features/projects/project_detail_page.dart';
import '../features/projects/project_list_page.dart';
import '../features/projects/quick_create_page.dart';
import '../features/renders/renders_page.dart';
import '../features/scene/scene_page.dart';
import '../features/upload/upload_page.dart';
import '../features/versions/versions_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.read(authProvider);
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final publicPage = location == '/login' || location == '/register';
      if (!auth.ready) {
        return location == '/splash' ? null : '/splash';
      }
      if (!auth.isLoggedIn) {
        return publicPage ? null : '/login';
      }
      if (publicPage || location == '/splash') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterPage()),
      GoRoute(path: '/me/edit', builder: (context, state) => const EditProfilePage()),
      GoRoute(path: '/me/about', builder: (context, state) => const AboutPage()),
      GoRoute(path: '/me/feedback', builder: (context, state) => const FeedbackPage()),
      GoRoute(path: '/me/privacy', builder: (context, state) => const PrivacyPage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomePage()),
          GoRoute(path: '/projects', builder: (context, state) => const ProjectListPage()),
          GoRoute(path: '/discover', builder: (context, state) => const DiscoverPage()),
          GoRoute(path: '/ai', builder: (context, state) => const AiPage()),
          GoRoute(path: '/me', builder: (context, state) => const MePage()),
        ],
      ),
      GoRoute(
        path: '/projects/new',
        builder: (context, state) => const NewProjectPage(),
        routes: [
          GoRoute(
            path: 'quick',
            builder: (context, state) => QuickCreatePage(initialStyleId: state.uri.queryParameters['style']),
          ),
          GoRoute(
            path: 'guided',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
      GoRoute(
        path: '/styles/:styleId',
        builder: (context, state) {
          final style = styleById(state.pathParameters['styleId'] ?? '');
          if (style == null) return const DiscoverPage();
          return StylePage(style: style);
        },
      ),
      GoRoute(
        path: '/projects/:projectId',
        builder: (context, state) => ProjectDetailPage(projectId: state.pathParameters['projectId']!),
        routes: [
          GoRoute(path: 'profile', builder: (context, state) => ProfilePage(projectId: state.pathParameters['projectId']!)),
          GoRoute(
            path: 'upload',
            builder: (context, state) => UploadPage(
              projectId: state.pathParameters['projectId']!,
              styleName: state.uri.queryParameters['style'],
            ),
          ),
          GoRoute(
            path: 'analysis',
            builder: (context, state) => AnalysisPage(
              projectId: state.pathParameters['projectId']!,
              assetId: state.uri.queryParameters['assetId'],
            ),
          ),
          GoRoute(path: 'chat', builder: (context, state) => ChatPage(projectId: state.pathParameters['projectId']!)),
          GoRoute(
            path: 'layouts',
            builder: (context, state) {
              final extra = state.extra;
              final options = extra is List
                  ? extra.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
                  : const <Map<String, dynamic>>[];
              return LayoutsPage(projectId: state.pathParameters['projectId']!, options: options);
            },
          ),
          GoRoute(path: 'versions', builder: (context, state) => VersionsPage(projectId: state.pathParameters['projectId']!)),
          GoRoute(
            path: 'renders',
            builder: (context, state) => RendersPage(
              projectId: state.pathParameters['projectId']!,
              versionId: state.uri.queryParameters['versionId'],
            ),
          ),
          GoRoute(
            path: 'scene',
            builder: (context, state) => ScenePage(
              projectId: state.pathParameters['projectId']!,
              versionId: state.uri.queryParameters['versionId'],
              styleName: state.uri.queryParameters['style'],
              initialRoom: state.uri.queryParameters['room'],
              openImmersive: state.uri.queryParameters['immersive'] == '1',
            ),
          ),
        ],
      ),
    ],
  );
});

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.page,
      body: AppAtmosphere(
        child: AiBusy(
          message: 'AI 房屋设计',
          hint: '正在打开空间顾问…',
        ),
      ),
    );
  }
}
