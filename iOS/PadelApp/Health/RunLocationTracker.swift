import CoreLocation
import Combine
import WorkingOutKit

@MainActor
final class RunLocationTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorization = CLAuthorizationStatus.notDetermined
    @Published private(set) var waitingForSignal = false
    private let manager = CLLocationManager()
    private var last: CLLocation?
    private var recordingSince: Date?
    private var receive: ((CLLocation, Double, Bool) -> Bool)?

    override init() {
        super.init()
        authorization = manager.authorizationStatus
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 8
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
    }

    var authorized: Bool { authorization == .authorizedWhenInUse || authorization == .authorizedAlways }

    func requestPermission() { manager.requestWhenInUseAuthorization() }

    func begin(receive: @escaping (CLLocation, Double, Bool) -> Bool) {
        guard authorized else { return }
        if self.receive != nil { return }
        self.receive = receive
        last = nil
        recordingSince = .now
        waitingForSignal = true
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        receive = nil
        last = nil
        recordingSince = nil
        waitingForSignal = false
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if !authorized { stop() }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if receive != nil { waitingForSignal = true }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let receive, let recordingSince else { return }
        for point in locations where point.horizontalAccuracy >= 0 && point.horizontalAccuracy <= 30 && point.timestamp >= recordingSince {
            let elapsed = last.map { point.timestamp.timeIntervalSince($0.timestamp) }
            if let elapsed, elapsed <= 0 { continue }
            let newSegment = elapsed.map { $0 > 45 } ?? true
            let meters = newSegment ? 0 : last.map { point.distance(from: $0) } ?? 0
            if let elapsed, meters / elapsed > 12 { continue }
            guard receive(point, meters, newSegment) else { continue }
            last = point
            waitingForSignal = false
        }
    }
}
