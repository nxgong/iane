import Flutter
import UIKit
import CoreLocation

@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        GeneratedPluginRegistrant.register(with: self)

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(
                application,
                didFinishLaunchingWithOptions: launchOptions
            )
        }

        // 로그인 정보 저장
        let locationChannel = FlutterMethodChannel(
            name: "location",
            binaryMessenger: controller.binaryMessenger
        )

        locationChannel.setMethodCallHandler { call, result in

            switch call.method {
                case "setLoginInfo":
                    if let args = call.arguments as? [String: Any] {
                        UserDefaults.standard.set(args["userId"], forKey: "USER_ID")
                        UserDefaults.standard.set(args["userNm"], forKey: "USER_NM")
                        UserDefaults.standard.set(args["userType"], forKey: "USER_TYPE")
                        UserDefaults.standard.set(args["companyCd"], forKey: "COMPANY_CD")
                        // 20260722 추가
                        UserDefaults.standard.set(args["locationSendYn"], forKey: "LOCATION_SEND_YN")
                        UserDefaults.standard.set(args["locationSendMin"], forKey: "LOCATION_SEND_MIN")

                        // 20260722 추가
                        print("""
                        ★★★★★ 로그인 정보 저장 완료
                        USER_ID=\(UserDefaults.standard.string(forKey: "USER_ID") ?? "")
                        USER_NM=\(UserDefaults.standard.string(forKey: "USER_NM") ?? "")
                        USER_TYPE=\(UserDefaults.standard.string(forKey: "USER_TYPE") ?? "")
                        COMPANY_CD=\(UserDefaults.standard.string(forKey: "COMPANY_CD") ?? "")
                        LOCATION_SEND_YN=\(UserDefaults.standard.string(forKey: "LOCATION_SEND_YN") ?? "")
                        LOCATION_SEND_MIN=\(UserDefaults.standard.object(forKey: "LOCATION_SEND_MIN") ?? "")
                        """)
                    }
                    result(nil)
                default:
                    result(FlutterMethodNotImplemented)
            }
        }

        // 위치 서비스 시작/종료
        let serviceChannel = FlutterMethodChannel(
            name: "location_service",
            binaryMessenger: controller.binaryMessenger
        )

        serviceChannel.setMethodCallHandler { call, result in
            switch call.method {
                case "startLocationService":
                    print("★★★★★ 위치서비스 시작")
                    LocationManager.shared.start()
                    result(nil)
                case "stopLocationService":
                    print("★★★★★ 위치서비스 종료")
                    LocationManager.shared.stop()
                    result(nil)
                default:
                    result(FlutterMethodNotImplemented)
            }
        }

        return super.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
    }
}
