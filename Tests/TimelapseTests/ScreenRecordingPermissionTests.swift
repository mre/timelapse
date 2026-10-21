import XCTest
@testable import Timelapse

final class ScreenRecordingPermissionTests: XCTestCase {
    @MainActor
    func testCheckingAccessNeverRequestsPermission() {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        var requests = 0
        let permission = ScreenRecordingPermission(
            defaults: defaults, preflight: { false },
            request: {
                requests += 1
                return false
            })
        permission.checkAccess()
        permission.checkAccess()
        XCTAssertFalse(permission.isGranted)
        XCTAssertFalse(permission.hasRequested)
        XCTAssertEqual(requests, 0)
    }

    @MainActor
    func testExplicitRequestIsRememberedAcrossLaunches() {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        var requests = 0
        let permission = ScreenRecordingPermission(
            defaults: defaults, preflight: { false },
            request: {
                requests += 1
                return false
            })
        permission.requestAccess()
        XCTAssertTrue(permission.hasRequested)
        XCTAssertFalse(permission.isGranted)
        XCTAssertEqual(requests, 1)
        let relaunched = ScreenRecordingPermission(defaults: defaults, preflight: { false }, request: { false })
        XCTAssertTrue(relaunched.hasRequested)
    }

    @MainActor
    func testDetectsApprovalAndRevocationWithoutPrompting() {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        var granted = false
        let permission = ScreenRecordingPermission(
            defaults: defaults, preflight: { granted },
            request: {
                XCTFail("Checking status must not request access")
                return false
            })
        granted = true
        permission.checkAccess()
        XCTAssertTrue(permission.isGranted)
        permission.requestAccess()
        granted = false
        permission.checkAccess()
        XCTAssertFalse(permission.isGranted)
    }

    @MainActor
    func testSuccessfulRequestContinuesWithoutRestart() {
        let (defaults, suite) = isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let permission = ScreenRecordingPermission(defaults: defaults, preflight: { false }, request: { true })
        permission.requestAccess()
        XCTAssertTrue(permission.isGranted)
    }

    private func isolatedDefaults() -> (UserDefaults, String) {
        let suite = "TimelapsePermissionTests-\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }
}
