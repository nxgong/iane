import Foundation
import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate {

    static let shared = LocationManager()

    private let locationManager = CLLocationManager()
    private let serverUrl = "https://erp.easisoft.co.kr/admin/userLocationInsert.do"

    private var latestLocation: CLLocation?
    private var lastSendTime = Date.distantPast

    override init() {
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false

        if #available(iOS 11.0, *) {
            locationManager.showsBackgroundLocationIndicator = false
        }
    }

    func start() {

        print("★★★★★ LocationManager Start")

        let status: CLAuthorizationStatus

        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        switch status {

        case .notDetermined:
            locationManager.requestAlwaysAuthorization()

        case .authorizedAlways,
             .authorizedWhenInUse:
            locationManager.startUpdatingLocation()

        default:
            print("★★★★★ 위치 권한이 허용되지 않았습니다.")
        }
    }

    func stop() {

        locationManager.stopUpdatingLocation()
        print("★★★★★ LocationManager Stop")
    }

    func locationManager(
        _ manager: CLLocationManager,
        didChangeAuthorization status: CLAuthorizationStatus
    ) {

        switch status {

        case .authorizedAlways:
            print("★★★★★ Always Permission")
            manager.startUpdatingLocation()

        case .authorizedWhenInUse:
            print("★★★★★ WhenInUse Permission")
            manager.startUpdatingLocation()

        default:
            print("★★★★★ Permission Denied")
        }
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {

        guard let location = locations.last else { return }

        // 가장 최근 위치 저장
        latestLocation = location

        let userId = UserDefaults.standard.string(forKey: "USER_ID") ?? ""
        let locationSendYn = UserDefaults.standard.string(forKey: "LOCATION_SEND_YN") ?? ""
        let locationSendMin = UserDefaults.standard.string(forKey: "LOCATION_SEND_MIN") ?? ""

        // USER_ID가 없으면 종료
        guard !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        // 위치전송 여부
        guard locationSendYn.uppercased() == "Y" else {
            return
        }

        // 전송주기 확인
        guard let min = Int(locationSendMin), min > 0 else {
            return
        }

        let interval = TimeInterval(min * 60)
        let now = Date()

        if now.timeIntervalSince(lastSendTime) >= interval {
            lastSendTime = now
            sendLocation(location)
        }
    }

    private func sendLocation(_ location: CLLocation) {

        print("★★★★★ sendLocation : \(Date())")

        guard let url = URL(string: serverUrl) else {
            return
        }

        let userId = UserDefaults.standard.string(forKey: "USER_ID") ?? ""
        let userNm = UserDefaults.standard.string(forKey: "USER_NM") ?? ""
        let userType = UserDefaults.standard.string(forKey: "USER_TYPE") ?? ""
        let companyCd = UserDefaults.standard.string(forKey: "COMPANY_CD") ?? ""

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body =
            "userId=\(userId)" +
            "&userNm=\(userNm)" +
            "&userType=\(userType)" +
            "&companyCd=\(companyCd)" +
            "&latitude=\(location.coordinate.latitude)" +
            "&longitude=\(location.coordinate.longitude)" +
            "&osType=IphoneApp"

        request.httpBody = body.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, response, error in

            if let error = error {
                print("★★★★★ 전송 실패 : \(error.localizedDescription)")
                return
            }

            print("★★★★★ 위치 전송 성공")

        }.resume()
    }

    func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {

        print("★★★★★ GPS Error : \(error.localizedDescription)")
    }
}
