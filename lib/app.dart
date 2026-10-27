import 'vendor/liquid_glass_widgets/liquid_glass_widgets.dart' as liquid;
import 'l10n/l10n.dart';
import 'components/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'core/session.dart';
import 'core/appearance.dart';
import 'screens/auth.dart';
import 'screens/shell.dart';
import 'design/app_design.dart';
import 'debug/gallery.dart';

class CoolvibesApp extends StatelessWidget {
  final Session session;
  final Widget? home;
  const CoolvibesApp({super.key, required this.session, this.home});
  @override
  Widget build(BuildContext context) => AppScope(
    session: session,
    child: ListenableBuilder(
      listenable: session,
      builder: (context, _) => MaterialApp(
        // Account changes also dismiss old private routes and context previews.
        key: ValueKey(
          session.api.token == null
              ? 'anonymous'
              : 'account-${session.user['public_id'] ?? session.user['id'] ?? 'restoring'}',
        ),
        title: 'Coolvibes',
        builder: (context, child) => liquid.LiquidGlassWidgets.wrap(
          brightnessResolver: Theme.maybeBrightnessOf,
          respectSystemAccessibility: true,
          child: child ?? const SizedBox.shrink(),
        ),
        debugShowCheckedModeBanner: false,
        locale: session.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        themeMode: session.themeMode,
        // The appearance model resolves both system variants; a fixed base
        // theme resolves to itself in either slot.
        theme: AppDesign.theme(
          Brightness.light,
          pixelRatio: View.of(context).devicePixelRatio,
          resolved: resolveAppearance(session.appearanceModel, false),
        ),
        darkTheme: AppDesign.theme(
          Brightness.dark,
          pixelRatio: View.of(context).devicePixelRatio,
          resolved: resolveAppearance(session.appearanceModel, true),
        ),
        routes: {if (kDebugMode) '/debug': (_) => const DebugGallery()},
        home:
            home ??
            (kDebugMode && const bool.fromEnvironment('DEBUG_GALLERY')
                ? const DebugGallery()
                : !session.ready
                ? const AppScaffold(
                    body: Center(child: CircularProgressIndicator.adaptive()),
                  )
                : session.api.token == null
                ? const AuthScreen()
                : session.startupError != null && session.user.isEmpty
                // Strings need the app's Localizations, below MaterialApp.
                ? Builder(
                    builder: (context) => AppScaffold(
                      appBar: AppHeader(
                        title: Text(context.l10n.connection),
                        actions: [
                          Builder(
                            builder: (context) => AppButton.text(
                              onPressed: () => perform(context, session.logout),
                              child: Text(context.l10n.logOut),
                            ),
                          ),
                        ],
                      ),
                      body: ScreenStatus(
                        error: context.l10n.yourAccountCouldNotBeLoaded,
                        message: context.l10n.checkYourConnectionAndTryAgain,
                        retry: session.retryStartup,
                      ),
                    ),
                  )
                : const Shell()),
      ),
    ),
  );
}
