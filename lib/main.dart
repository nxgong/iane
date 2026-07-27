import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'permission_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  await PermissionManager.requestAll();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? gUserId;
  String? gUserNm;
  String? gUserType;
  String? gCompanyCd;
  // 20260722 추가
  String? gLocationSendYn;
  String? gLocationSendMin;

  InAppWebViewController? webViewController;

  bool _showSplash = true;
  bool _pageLoaded = false;
  bool _minTimePassed = false;

  // Android Native Channel
  // location      -> 로그인 정보 전달용
  // location_service -> 위치 서비스 시작/중지
  static const MethodChannel loginChannel = MethodChannel("location");
  static const MethodChannel locationChannel = MethodChannel("location_service");

  @override
  void initState() {
    super.initState();
    // 위치 서비스는 여기서 시작하지 않음
    // 이유: 앱 실행 시점에는 USER_ID 없음 → 로그인 성공 후 시작
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      _minTimePassed = true;
      _hideSplashIfReady();
    });
  }

  Future<void> startLocationService() async {
    try {
      debugPrint("★★★★★ 위치 서비스 시작 요청");
      await locationChannel.invokeMethod(
        "startLocationService",
        {"userId": gUserId},
      );
      debugPrint("★★★★★ 위치 서비스 시작 완료");
    } catch (e) {
      debugPrint("★★★★★ 위치 서비스 오류 : $e");
    }
  }

  Future<void> stopLocationService() async {
    try {
      await locationChannel.invokeMethod("stopLocationService");
    } catch (e) {
      debugPrint("위치 서비스 종료 오류 : $e");
    }
  }

  void _hideSplashIfReady() {
    if (!_pageLoaded) return;
    if (!_minTimePassed) return;
    if (!_showSplash) return;
    setState(() {
      _showSplash = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  //url: WebUri("https://erp.easisoft.co.kr/"),
                  // 20260716_iane 별도 설정
                  url: WebUri("https://iane.iangrp.com/"),
                  //url: WebUri("http://192.168.0.70:80/"),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  supportZoom: false,
                  mediaPlaybackRequiresUserGesture: false,
                  javaScriptCanOpenWindowsAutomatically: true,
                  supportMultipleWindows: true,
                  preferredContentMode: UserPreferredContentMode.RECOMMENDED,
                  useWideViewPort: true,
                  loadWithOverviewMode: true,
                ),
                androidOnPermissionRequest: (controller, origin, resources) async {
                  return PermissionRequestResponse(
                    resources: resources,
                    action: PermissionRequestResponseAction.GRANT,
                  );
                },
                androidOnGeolocationPermissionsShowPrompt: (controller, origin) async {
                  return GeolocationPermissionShowPromptResponse(
                    origin: origin,
                    allow: true,
                    retain: true,
                  );
                },
                onPermissionRequest: (controller, request) async {
                  return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.GRANT,
                  );
                },
                onWebViewCreated: (controller) async {
                  webViewController = controller;

                  controller.addJavaScriptHandler(
                    handlerName: "loginSuccess",
                    callback: (args) async {
                      final user = args.first;
                      gUserId = user["userId"].toString();
                      gUserNm = user["userNm"].toString();
                      gUserType = user["userType"].toString();
                      gCompanyCd = user["companyCd"].toString();
                      // 20260722 추가
                      gLocationSendYn = user["locationSendYn"].toString();
                      gLocationSendMin = user["locationSendMin"].toString();

                      debugPrint("USER_ID : $gUserId");
                      debugPrint("USER_NM : $gUserNm");

                      print(gUserId);
                      print(gUserNm);
                      print(gUserType);
                      print(gCompanyCd);
                      // 20260722 추가
                      print(gLocationSendYn);
                      print(gLocationSendMin);

                      // 1. 로그인 정보 Native 전달
                      await loginChannel.invokeMethod(
                        "setLoginInfo",
                        {
                          "userId":           gUserId,
                          "userNm":           gUserNm,
                          "userType":         gUserType,
                          "companyCd":        gCompanyCd,
                          // 20260722 추가
                          "locationSendYn":   gLocationSendYn,
                          "locationSendMin":  gLocationSendMin,
                        },
                      );

                      // 2. 위치 서비스 시작 (기존: 앱 시작 시 / 변경: 로그인 완료 후)
                      await startLocationService();

                      return {};
                    },
                  );

                  await controller.setSettings(
                    settings: InAppWebViewSettings(
                      userAgent:
                      "Mozilla/5.0 (Linux; Android 14; ko-KR) "
                          "AppleWebKit/537.36 "
                          "(KHTML, like Gecko) "
                          "Chrome/137.0.0.0 "
                          "Mobile Safari/537.36",
                    ),
                  );
                },
                onLoadStop: (controller, url) async {
                  _pageLoaded = true;
                  _hideSplashIfReady();

                  await controller.evaluateJavascript(
                    source: """
                      console.log('===== WEBVIEW EVENT DEBUG START =====');

                      document.addEventListener('touchstart', function(e){
                        console.log('TOUCHSTART:', e.target.tagName, e.target.className);
                      }, true);

                      document.addEventListener('touchend', function(e){
                        console.log('TOUCHEND:', e.target.tagName, e.target.className);
                      }, true);

                      document.addEventListener('click', function(e){
                        console.log('CLICK:', e.target.tagName, e.target.className);
                      }, true);
                    """,
                  );
                },
                onCreateWindow: (controller, action) async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PopupPage(windowId: action.windowId),
                    ),
                  );
                  return true;
                },
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_showSplash,
                child: AnimatedOpacity(
                  opacity: _showSplash ? 1 : 0,
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    color: const Color(0xFF193E65),
                    alignment: Alignment.center,
                    child: const Text(
                      "IANE",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PopupPage extends StatefulWidget {
  final int? windowId;

  const PopupPage({super.key, required this.windowId});

  @override
  State<PopupPage> createState() => _PopupPageState();
}

class _PopupPageState extends State<PopupPage> {
  InAppWebViewController? controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: InAppWebView(
          windowId: widget.windowId,
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            javaScriptCanOpenWindowsAutomatically: true,
            supportMultipleWindows: true,
          ),
          onPermissionRequest: (controller, request) async {
            return PermissionResponse(
              resources: request.resources,
              action: PermissionResponseAction.GRANT,
            );
          },
          onWebViewCreated: (c) {
            controller = c;
          },
          onCloseWindow: (controller) {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}