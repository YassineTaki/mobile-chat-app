// lib/navigation/router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth_screen.dart';
import '../screens/contacts_screen.dart';
import '../screens/chat_screen.dart';
import '../services/auth_service.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/auth',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final onAuth     = state.matchedLocation == '/auth';

      if (!isLoggedIn && !onAuth) return '/auth';
      if (isLoggedIn  &&  onAuth) return '/contacts';
      return null;
    },
    refreshListenable: _AuthListenable(ref),
    routes: [
      GoRoute(
        path: '/auth',
        pageBuilder: (context, state) => _slide(const AuthScreen(), state),
      ),
      GoRoute(
        path: '/contacts',
        pageBuilder: (context, state) => _slide(const ContactsScreen(), state),
      ),
      GoRoute(
        path: '/chat/:convId/:contactName/:contactInitials/:contactColor',
        pageBuilder: (context, state) {
          final convId          = state.pathParameters['convId']!;
          final contactName     = state.pathParameters['contactName']!;
          final contactInitials = state.pathParameters['contactInitials']!;
          final contactColor    = int.parse(state.pathParameters['contactColor']!);
          final contactUserId   = state.uri.queryParameters['userId'] ?? '';
          return _slide(
            ChatScreen(
              convId: convId,
              contactName: contactName,
              contactInitials: contactInitials,
              contactColor: Color(contactColor),
              contactUserId: contactUserId,
            ),
            state,
          );
        },
      ),
    ],
  );
});

Page<void> _slide(Widget child, GoRouterState state) =>
    CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: animation.drive(
          Tween(begin: const Offset(1, 0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic)),
        ),
        child: child,
      ),
    );

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
  }
}
