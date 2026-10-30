import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:webview_flutter/webview_flutter.dart';

class YybGoPage extends StatefulWidget {
  final String? url;
  const YybGoPage({Key? key, this.url}) : super(key: key);

  @override
  State<YybGoPage> createState() => _YybGoPageState();
}

class _YybGoPageState extends State<YybGoPage> {
  WebViewController? _controller;
  String _currentUrl = "";

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WebView.platform = SurfaceAndroidWebView();
    }
    _currentUrl = widget.url ?? "http://127.0.0.1:8000";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("YYB-Go 管理"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller?.reload();
            },
          ),
        ],
      ),
      body: WebView(
        initialUrl: _currentUrl,
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (controller) {
          _controller = controller;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            EasyLoading.show(status: "加载中...");
          });
        },
        onPageFinished: (url) {
          EasyLoading.dismiss();
          setState(() {
            _currentUrl = url;
          });
        },
        onPageStarted: (url) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            EasyLoading.show(status: "加载中...");
          });
        },
      ),
    );
  }
}
