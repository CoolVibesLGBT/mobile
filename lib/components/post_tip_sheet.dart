// Actions is this file's own API-action-name registry; Flutter's own
// Actions (intent/shortcuts) widget isn't used here.
import 'package:flutter/material.dart' hide Actions;
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/actions.dart';
import '../core/api.dart';
import '../core/app_failure.dart';
import '../core/session.dart';
import '../design/app_design.dart';
import '../l10n/l10n.dart';
import 'app_button.dart';
import 'app_field.dart';
import 'app_header.dart';
import 'app_lottie.dart';
import 'app_pressable.dart';
import 'app_scaffold.dart';
import 'avatar.dart';
import 'navigation.dart';

/// TipButton (web/src/components/ui/TipButton.tsx): the same 24-step amount
/// ladder, tiered gift Lottie art and quick-ratio custom amount, submitted
/// as `post.tip` {post_id, amount}. The response's only two real fields
/// (web only ever reads these) are `success` and `balance` — read exactly
/// those, nothing invented.
class PostTipSheet extends StatefulWidget {
  final Json post;
  const PostTipSheet({super.key, required this.post});
  @override
  State<PostTipSheet> createState() => _PostTipSheetState();
}

class _PostTipSheetState extends State<PostTipSheet> {
  static const List<double> amounts = [
    .1, .25, .5, .75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75,
    3, 3.5, 4, 4.5, 5, 10, 20, 30, 40, 50, 75, 100, //
  ];

  /// Original Telegram gift artwork, grouped by tip amount (not subscription
  /// duration) — the same three-tier mapping as web's giftAsset().
  static String giftAsset(num value) =>
      'assets/animations/Gift${value >= 10
          ? 12
          : value >= 2
          ? 6
          : 3}.json';

  final custom = TextEditingController();
  double? selected;
  bool customMode = false, busy = false;
  double? sentAmount;
  String? error;

  @override
  void dispose() {
    custom.dispose();
    super.dispose();
  }

  double get balance {
    final value = num.tryParse(
      string(AppScope.of(context).user['balance']),
    )?.toDouble();
    return value == null || value < 0 ? 0 : value;
  }

  double get amount =>
      customMode ? (double.tryParse(custom.text.trim()) ?? 0) : selected ?? 0;
  bool get validAmount => amount > 0;
  bool get insufficient => validAmount && amount > balance;
  bool get canSubmit =>
      validAmount && !insufficient && !busy && sentAmount == null;

  NumberFormat money(BuildContext context) => NumberFormat.currency(
    locale: Localizations.localeOf(context).toString(),
    name: 'USD',
  );

  void selectPreset(double value) {
    HapticFeedback.selectionClick();
    setState(() {
      selected = selected == value ? null : value;
      customMode = false;
      error = null;
    });
  }

  void openCustom() {
    HapticFeedback.selectionClick();
    setState(() {
      customMode = true;
      error = null;
    });
  }

  Future<void> submit() async {
    if (!canSubmit) return;
    setState(() {
      busy = true;
      error = null;
    });
    final value = amount;
    final failedMessage = context.l10n.tipFailed;
    try {
      final response = await AppScope.of(context).api.call(
        Actions.cmdPostTip,
        body: {'post_id': recordId(widget.post), 'amount': value},
      );
      if (response['success'] == false) {
        throw ApiException(failedMessage);
      }
      final nextBalance = num.tryParse(string(response['balance']));
      if (nextBalance != null && mounted) {
        AppScope.of(context).applyBalance(nextBalance);
      }
      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() => sentAmount = value);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = AppFailure.from(e).message(context.l10n));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final author = object(widget.post['user'] ?? widget.post['author']);
    final recipientName = personName(author);
    final recipientUsername = string(author['username']);
    final sent = sentAmount;
    return AppScaffold(
      appBar: AppHeader(
        title: Text(
          sent == null ? context.l10n.tipSendTitle : context.l10n.tipSent,
        ),
        actions: [
          if (sent != null)
            AppButton.text(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(context.l10n.close),
            )
          else
            AppButton.text(
              loading: busy,
              onPressed: canSubmit ? submit : null,
              child: Text(
                insufficient
                    ? context.l10n.tipInsufficientBalance
                    : '${context.l10n.tipSendTitle} · ${money(context).format(amount)}',
              ),
            ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.paddingOf(context).top +
              AppDesign.headerInset(context) +
              16,
          16,
          MediaQuery.paddingOf(context).bottom + 16,
        ),
        children: sent != null
            ? [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppLottie(asset: giftAsset(sent), size: 132, loop: false),
                      const SizedBox(height: 8),
                      Icon(Icons.check_circle, color: palette.accent, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        money(context).format(sent),
                        style: AppDesign.font(
                          22,
                          weight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recipientName,
                        style: AppDesign.font(
                          15,
                          color: palette.secondaryLabel,
                        ),
                      ),
                    ],
                  ),
                ),
              ]
            : [
                Row(
                  children: [
                    Avatar(author, radius: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppDesign.font(
                              16,
                              weight: FontWeight.w600,
                              color: palette.text,
                            ),
                          ),
                          if (recipientUsername.isNotEmpty)
                            Text(
                              '@$recipientUsername',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppDesign.font(
                                13,
                                color: palette.secondaryLabel,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: palette.input,
                    borderRadius: BorderRadius.circular(
                      AppDesign.controlCorner,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.walletAvailableBalance,
                        style: AppDesign.font(
                          14,
                          color: palette.secondaryLabel,
                        ),
                      ),
                      Text(
                        money(context).format(balance),
                        style: AppDesign.font(
                          15,
                          weight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  context.l10n.walletSelectAmount,
                  style: AppDesign.font(
                    13,
                    weight: FontWeight.w600,
                    color: palette.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final value in amounts)
                      _TipGiftCard(
                        amount: value,
                        label: money(context).format(value),
                        asset: giftAsset(value),
                        selected: !customMode && selected == value,
                        onTap: () => selectPreset(value),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                AppPressable(
                  label: context.l10n.walletCustomAmount,
                  style: AppPressStyle.touchable,
                  onPressed: openCustom,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: customMode ? palette.accent : palette.input,
                      borderRadius: BorderRadius.circular(
                        AppDesign.controlCorner,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add,
                          size: 18,
                          color: customMode ? Colors.white : palette.text,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.walletCustomAmount,
                          style: AppDesign.font(
                            15,
                            weight: FontWeight.w600,
                            color: customMode ? Colors.white : palette.text,
                          ),
                        ),
                        if (customMode) ...[
                          const Spacer(),
                          const Icon(
                            Icons.check,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (customMode) ...[
                  const SizedBox(height: 12),
                  AppField(
                    controller: custom,
                    label: '${context.l10n.walletCustomAmount} (USD)',
                    labelAbove: true,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() => error = null),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final ratio in const [.25, .5, .75, 1.0])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: AppButton(
                              emphasis: AppButtonEmphasis.secondary,
                              onPressed: balance <= 0
                                  ? null
                                  : () => setState(() {
                                      custom.text = (balance * ratio)
                                          .toStringAsFixed(2);
                                      error = null;
                                    }),
                              child: Text('${(ratio * 100).round()}%'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    error!,
                    style: AppDesign.font(13, color: palette.destructive),
                  ),
                ],
              ],
      ),
    );
  }
}

class _TipGiftCard extends StatelessWidget {
  final double amount;
  final String label, asset;
  final bool selected;
  final VoidCallback onTap;
  const _TipGiftCard({
    required this.amount,
    required this.label,
    required this.asset,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return AppPressable(
      label: label,
      selected: selected,
      style: AppPressStyle.touchable,
      onPressed: onTap,
      child: Container(
        width: 84,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? palette.accent.withValues(alpha: .12)
              : palette.input,
          borderRadius: BorderRadius.circular(AppDesign.controlCorner),
          border: Border.all(
            color: selected ? palette.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLottie(asset: asset, size: 56, autoplay: selected),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppDesign.font(
                    13,
                    weight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
              ],
            ),
            if (selected)
              PositionedDirectional(
                top: 4,
                end: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.accent,
                    border: Border.all(color: palette.row, width: 1.5),
                  ),
                  child: const Icon(Icons.check, size: 11, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
