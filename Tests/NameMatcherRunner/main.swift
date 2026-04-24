import AirPodsFixLib
import Foundation

// Minimal test harness — runs without Xcode or xctest runner.
// Produces TAP-like output so CI can parse it.

var passed = 0
var failed = 0

func check(_ description: String, _ value: Bool) {
    if value {
        passed += 1
        print("ok \(passed + failed) - \(description)")
    } else {
        failed += 1
        print("not ok \(passed + failed) - \(description)")
    }
}

// testExactName
check("exact 'AirPods'", isAirPodsName("AirPods"))

// testFullProductName
check("full product name 'Yoel's AirPods Pro3 1'", isAirPodsName("Yoel's AirPods Pro3 1"))

// testCaseInsensitive
check("lowercase 'airpods pro'", isAirPodsName("airpods pro"))
check("uppercase 'AIRPODS'", isAirPodsName("AIRPODS"))

// testNonAirPods
check("non-AirPods 'Sony WH-1000XM5' is false", !isAirPodsName("Sony WH-1000XM5"))
check("non-AirPods 'MacBook Pro Speakers' is false", !isAirPodsName("MacBook Pro Speakers"))
check("empty string is false", !isAirPodsName(""))

let total = passed + failed
print("")
print("1..\(total)")
print("# \(passed)/\(total) passed")

if failed > 0 {
    print("# FAILED \(failed) test(s)")
    exit(1)
} else {
    print("# All tests passed")
    exit(0)
}
