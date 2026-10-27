import '../l10n/l10n.dart';
import '../components/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'feed.dart';
import 'discover.dart';
import 'chat.dart';
import 'radar.dart';
import '../components/app_tab_bar.dart';

class Shell extends StatefulWidget {
  const Shell({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late int index = widget.initialTab.clamp(0, 4);
  final navigators = List.generate(5, (_) => GlobalKey<NavigatorState>());
  @override
  Widget build(BuildContext context) {
    final labels = [
      context.l10n.home,
      context.l10n.nearby,
      'Radar',
      'Check-in',
      context.l10n.chats,
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await navigators[index].currentState!.maybePop()) return;
        if (index != 0 && mounted) setState(() => index = 0);
      },
      child: AppScaffold(
        extendBody: true,
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: index,
                  children: List.generate(
                    5,
                    (i) => TickerMode(
                      enabled: index == i,
                      child: Navigator(
                        key: navigators[i],
                        onGenerateRoute: (_) => MaterialPageRoute<void>(
                          builder: (_) => [
                            const FeedScreen(),
                            const NearbyScreen(),
                            const RadarScreen(),
                            const CheckInsScreen(),
                            const ChatsScreen(),
                          ][i],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
            ? null
            : Padding(
                padding: AppTabBar.insets(context),
                child: AppTabBar(
                  selected: index,
                  labels: labels,
                  onSelected: (i) {
                    if (index == i) {
                      navigators[i].currentState?.popUntil(
                        (route) => route.isFirst,
                      );
                    } else {
                      setState(() => index = i);
                    }
                  },
                ),
              ),
      ),
    );
  }
}
