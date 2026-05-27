import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:devler_ligi/features/auth/welcome_dashboard.dart';
import 'package:devler_ligi/features/auth/register_page.dart';
import 'package:devler_ligi/features/home/home_page.dart';
import 'package:devler_ligi/features/admin/admin_panel.dart';
import 'package:devler_ligi/features/home/contact_page.dart';
import 'package:devler_ligi/features/home/my_team_page.dart';
import 'package:devler_ligi/features/profile/profile_page.dart';
import 'package:devler_ligi/features/profile/edit_profile_page.dart';
import 'package:devler_ligi/features/home/team_detail_page.dart';
import 'package:devler_ligi/features/profile/player_detail_page.dart';
import 'package:devler_ligi/features/admin/add_match_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  redirect: (BuildContext context, GoRouterState state) {
    final supabase = Supabase.instance.client;
    final bool isAuth = supabase.auth.currentUser != null;
    final String path = state.uri.path;

    final bool isAuthRoute = path == '/' || path == '/register';

    if (!isAuth && !isAuthRoute) {
      return '/'; 
    }

    
    if (isAuth && isAuthRoute) {
      return '/home';
    }

    return null; 
  },
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const WelcomeDashboard();
      },
      routes: <RouteBase>[
        GoRoute(
          path: 'register',
          builder: (BuildContext context, GoRouterState state) {
            return const RegisterPage();
          },
        ),
        GoRoute(
          path: 'home',
          builder: (BuildContext context, GoRouterState state) {
            return const HomePage();
          },
        ),
        GoRoute(
          path: 'admin',
          builder: (BuildContext context, GoRouterState state) {
            return const AdminPanel();
          },
          routes: <RouteBase>[
            GoRoute(
              path: 'add-match',
              builder: (BuildContext context, GoRouterState state) {
                return const AddMatchPage();
              },
            ),
          ],
        ),
        GoRoute(
          path: 'contact',
          builder: (BuildContext context, GoRouterState state) {
            return const ContactPage();
          },
        ),
        GoRoute(
          path: 'my-team',
          builder: (BuildContext context, GoRouterState state) {
            return const MyTeamPage();
          },
        ),
        GoRoute(
          path: 'profile',
          builder: (BuildContext context, GoRouterState state) {
            return const ProfilePage();
          },
        ),
        GoRoute(
          path: 'edit-profile',
          builder: (BuildContext context, GoRouterState state) {
            return const EditProfilePage();
          },
        ),
        GoRoute(
          path: 'team/:teamId',
          builder: (BuildContext context, GoRouterState state) {
            final teamId = state.pathParameters['teamId']!;
            return TeamDetailPage(teamId: teamId);
          },
        ),
        GoRoute(
          path: 'player/:playerId',
          builder: (BuildContext context, GoRouterState state) {
            final playerId = state.pathParameters['playerId']!;
            return PlayerDetailPage(playerId: playerId);
          },
        ),
      ],
    ),
  ],
);
