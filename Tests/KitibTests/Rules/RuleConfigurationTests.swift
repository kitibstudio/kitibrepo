import XCTest

/// Failure-mode tests for RuleConfiguration (spec criterion 4: severity is
/// per-rule and configurable; a disabled rule produces nothing).
final class RuleConfigurationTests: XCTestCase {

    func testFreshConfigurationEnablesEveryRule() {
        let config = RuleConfiguration()
        XCTAssertTrue(config.isEnabled("anything"))
        XCTAssertTrue(config.isEnabled(""))
    }

    func testFreshConfigurationOverridesNothing() {
        let config = RuleConfiguration()
        XCTAssertEqual(config.severity(for: "x", default: .warning), .warning)
        XCTAssertEqual(config.severity(for: "x", default: .error), .error)
    }

    func testDisableRule() {
        var config = RuleConfiguration()
        config.disable("heading-jump")
        XCTAssertFalse(config.isEnabled("heading-jump"))
        XCTAssertTrue(config.isEnabled("other"))
    }

    func testReenableAfterDisable() {
        var config = RuleConfiguration()
        config.disable("heading-jump")
        config.enable("heading-jump")
        XCTAssertTrue(config.isEnabled("heading-jump"))
    }

    func testSeverityOverrideForOneRuleOnly() {
        var config = RuleConfiguration()
        config.setSeverity(.error, for: "heading-jump")
        XCTAssertEqual(config.severity(for: "heading-jump", default: .warning), .error)
        XCTAssertEqual(config.severity(for: "empty-section", default: .warning), .warning)
    }

    func testUnknownRuleIDDisableIsHarmless() {
        var config = RuleConfiguration()
        config.disable("no-such-rule")
        XCTAssertTrue(config.isEnabled("anything-else"))
        config.setSeverity(.info, for: "no-such-rule")
        XCTAssertEqual(config.severity(for: "no-such-rule", default: .error), .info)
    }

    func testEquality() {
        var a = RuleConfiguration()
        var b = RuleConfiguration()
        XCTAssertEqual(a, b)
        a.disable("x")
        XCTAssertNotEqual(a, b)
        b.disable("x")
        XCTAssertEqual(a, b)
        a.setSeverity(.error, for: "y")
        XCTAssertNotEqual(a, b)
    }
}
