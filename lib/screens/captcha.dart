import '../l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../components/components.dart';
import '../core/constants.dart';

class CaptchaScreen extends StatefulWidget {
  const CaptchaScreen({super.key});
  @override
  State<CaptchaScreen> createState() => _CaptchaScreenState();
}

class _CaptchaScreenState extends State<CaptchaScreen> {
  static const siteKey = AppConstants.recaptchaSiteKey;
  WebViewController? controller;
  String? error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'Captcha',
        onMessageReceived: (message) {
          if (mounted && message.message.isNotEmpty) {
            Navigator.pop(context, message.message);
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => loading = false);
          },
          onWebResourceError: (event) {
            if (mounted && event.isForMainFrame == true) {
              setState(() {
                error = event.description;
                loading = false;
              });
            }
          },
        ),
      )
      ..loadHtmlString(
        '''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><script src="https://www.google.com/recaptcha/api.js" async defer></script></head><body style="margin:0;display:flex;align-items:center;justify-content:center;min-height:90vh;background:white"><div class="g-recaptcha" data-sitekey="$siteKey" data-callback="verified"></div><script>function verified(token){Captcha.postMessage(token)}</script></body></html>''',
        baseUrl: AppConstants.recaptchaOrigin,
      );
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppHeader(title: Text(context.l10n.verification)),
    body: error != null
        ? ScreenStatus(
            error: error,
            retry: () {
              setState(() {
                error = null;
                loading = true;
              });
              controller?.reload();
            },
          )
        : Stack(
            children: [
              WebViewWidget(controller: controller!),
              if (loading)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
  );
}
