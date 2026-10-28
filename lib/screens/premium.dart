import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../components/app_lottie.dart';
import '../components/components.dart';
import '../components/glass_surface.dart';
import '../core/api.dart';
import '../core/app_failure.dart';
import '../core/premium.dart';
import '../core/session.dart';
import '../design/app_design.dart';
import '../l10n/l10n.dart';
import 'legal.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool opening = false;
  Future<void> account() async {
    if (opening) return;
    setState(() => opening = true);
    try {
      if (!await launchUrl(
        Uri.https('coolvibes.lgbt', '/premium'),
        mode: LaunchMode.externalApplication,
      )) {
        throw ApiException('Premium account page could not be opened');
      }
    } catch (error) {
      if (mounted) await showErrorSheet(context, AppFailure.from(error));
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n, p = AppPalette.of(context);
    final active = hasPremiumAccess(AppScope.of(context).user);
    final benefits = [
      (
        l.premiumLiveTitle,
        l.premiumLiveBody,
        'video.fill',
        Icons.videocam,
        AppDesign.premiumColors[0],
      ),
      (
        l.premiumNearbyTitle,
        l.premiumNearbyBody,
        'location.circle.fill',
        Icons.explore,
        AppDesign.premiumColors[1],
      ),
      (
        l.premiumVisibilityTitle,
        l.premiumVisibilityBody,
        'sparkles',
        Icons.auto_awesome,
        AppDesign.premiumColors[2],
      ),
      (
        l.premiumBadgeTitle,
        l.premiumBadgeBody,
        'star.circle.fill',
        Icons.stars_rounded,
        AppDesign.premiumColors[3],
      ),
    ];
    return AppScaffold(
      appBar: AppHeader(title: const Text('Premium')),
      extendBody: true,
      body: ListView(
        key: const PageStorageKey('premium.scroll'),
        padding: EdgeInsets.only(
          top:
              MediaQuery.paddingOf(context).top +
              AppDesign.headerInset(context) +
              12,
          bottom: 180,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDesign.premiumContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _PremiumHero(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Coolvibes Premium',
                            textAlign: TextAlign.center,
                            style: AppDesign.font(
                              AppDesign.premiumTitleSize,
                              weight: FontWeight.w700,
                              color: p.text,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          active ? l.premiumActiveBody : l.premiumSubtitle,
                          textAlign: TextAlign.center,
                          style: AppDesign.font(
                            15,
                            color: p.secondaryLabel,
                            height: 1.4,
                          ),
                        ),
                        if (active)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                l.premiumActiveTitle,
                                key: const ValueKey('premium.active'),
                                style: AppDesign.font(
                                  15,
                                  weight: FontWeight.w600,
                                  color: p.accent,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  AppSection(
                    title: l.premiumBenefits,
                    children: [
                      for (final benefit in benefits)
                        AppRow(
                          disclosure: false,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          leading: AppSettingIcon(
                            benefit.$4,
                            color: benefit.$5,
                            symbol: benefit.$3,
                          ),
                          title: Text(
                            benefit.$1,
                            style: AppDesign.font(
                              17,
                              weight: FontWeight.w500,
                              color: p.text,
                            ),
                          ),
                          subtitle: Text(
                            benefit.$2,
                            style: AppDesign.font(
                              13,
                              color: p.secondaryLabel,
                              height: 1.35,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      l.premiumAccountNote,
                      textAlign: TextAlign.center,
                      style: AppDesign.font(
                        13,
                        color: p.secondaryLabel,
                        height: 1.4,
                      ),
                    ),
                  ),
                  Center(
                    child: AppButton.text(
                      key: const ValueKey('premium.legal'),
                      onPressed: () => open(context, const LegalScreen()),
                      child: Text(l.premiumTerms),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDesign.premiumContentWidth,
              ),
              child: GlassSurface(
                radius: AppDesign.groupCorner,
                role: GlassSurfaceRole.input,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AppButton.filled(
                    key: const ValueKey('premium.account'),
                    variant: AppButtonVariant.accent,
                    size: AppButtonSize.large,
                    loading: opening,
                    leadingIcon: active
                        ? Icons.manage_accounts_outlined
                        : Icons.star_rounded,
                    onPressed: opening ? null : account,
                    child: Text(active ? l.premiumManage : l.premiumExplore),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumHero extends StatelessWidget {
  const _PremiumHero();
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: AppDesign.premiumHeroSize,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppDesign.premiumColors[2].withValues(alpha: .12),
                Colors.transparent,
              ],
            ),
          ),
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: AppDesign.premiumGradient.createShader,
            child: const AppLottie(
              asset: 'assets/animations/premium_star.json',
              size: AppDesign.premiumHeroSize,
              loop: false,
              staticProgress: .85,
            ),
          ),
        ),
      ),
    ),
  );
}
