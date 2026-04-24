import Testing
@testable import AirPodsFixLib

@Suite("NameMatcher")
struct NameMatcherTests {
    @Test func testExactName() {
        #expect(isAirPodsName("AirPods"))
    }

    @Test func testFullProductName() {
        #expect(isAirPodsName("Yoel's AirPods Pro3 1"))
    }

    @Test func testCaseInsensitive() {
        #expect(isAirPodsName("airpods pro"))
        #expect(isAirPodsName("AIRPODS"))
    }

    @Test func testNonAirPods() {
        #expect(!isAirPodsName("Sony WH-1000XM5"))
        #expect(!isAirPodsName("MacBook Pro Speakers"))
        #expect(!isAirPodsName(""))
    }
}
