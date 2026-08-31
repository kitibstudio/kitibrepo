import XCTest

/// Proves the test harness itself builds and runs.
///
/// This exists so `gauntlet.sh` preflight has something real to execute. Before
/// it, `gate_tests` ran `swift test` against a project with no package and no
/// test target, so preflight was a hard stop and the loop could never start.
///
/// This is NOT a feature test. The first of those arrives with paste healing —
/// see `specs/paste-healing.md`, which is awaiting human approval.
final class HarnessSmokeTests: XCTestCase {

    func testHarnessRuns() {
        XCTAssertTrue(true, "If this does not run, the harness is broken.")
    }
}
