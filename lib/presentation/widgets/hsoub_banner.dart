import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // 👈 REQUIRED: Add url_launcher to pubspec.yaml

class HsoubBanner extends StatefulWidget {
  const HsoubBanner({super.key});

  @override
  State<HsoubBanner> createState() => _HsoubBannerState();
}

class _HsoubBannerState extends State<HsoubBanner> {
  late final WebViewController _controller;
  bool _isLoading = true;

  // ⚠️ IMPORTANT: Change this to the website you registered in Hsoub
  final String _websiteDomain = 'https://YOUR-WEBSITE.com';

  final String _hsoubAdCode = '''
    <script type="text/javascript">
      hsoub_adplace = 2601760163254801;
      hsoub_adplace_size = '468x60';
    </script>
    <script src="https://ads2.hsoub.com/show.js" type="text/javascript"></script>
    ''';

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            // ✅ FIX: Open clicks in external browser, not inside the tiny banner
            if (request.url.startsWith('http')) {
              _launchURL(request.url);
              return NavigationDecision.prevent; // Stop WebView from loading it
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(
        '''
        <!DOCTYPE html>
        <html>
          <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
              body { 
                margin: 0; 
                padding: 0; 
                display: flex; 
                justify-content: center; 
                align-items: center; 
                background-color: transparent; 
              }
            </style>
          </head>
          <body>
            $_hsoubAdCode
          </body>
        </html>
        ''',
        baseUrl:
            _websiteDomain, // 👈 CRITICAL: This allows Hsoub to accept the ad request
      );
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      width: double.infinity,
      color: Colors.white,
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF2A9D8F),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
