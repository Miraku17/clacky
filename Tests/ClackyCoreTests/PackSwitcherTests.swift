import ClackyCore

enum PackSwitcherTests {
    static func run() {
        TestKit.run("PackSwitcher first request starts a load and applies on success") {
            var s = PackSwitcher()
            expect(s.request("a"), "should start load")
            expectEqual(s.selected, "a")
            expectEqual(s.finished("a", success: true), .apply)
            expectEqual(s.loaded, "a")
        }
        TestKit.run("PackSwitcher ignores a stale load that finishes after a newer request") {
            var s = PackSwitcher()
            expect(s.request("a"))
            expect(s.request("b"))
            expectEqual(s.selected, "b")
            expectEqual(s.finished("a", success: true), .ignore)
            expectNil(s.loaded)
            expectEqual(s.finished("b", success: true), .apply)
            expectEqual(s.loaded, "b")
        }
        TestKit.run("PackSwitcher does not re-dispatch a load already in flight") {
            var s = PackSwitcher()
            expect(s.request("a"))
            expect(!s.request("a"), "second request for the in-flight pack must not start another load")
        }
        TestKit.run("PackSwitcher does not reload the pack that is already loaded") {
            var s = PackSwitcher()
            _ = s.request("a"); _ = s.finished("a", success: true)
            expect(!s.request("a"))
        }
        TestKit.run("PackSwitcher reverts the selection to the loaded pack on failure") {
            var s = PackSwitcher()
            _ = s.request("a"); _ = s.finished("a", success: true)
            expect(s.request("broken"))
            expectEqual(s.finished("broken", success: false), .revert(to: "a"))
            expectEqual(s.selected, "a")
            expectEqual(s.loaded, "a")
        }
        TestKit.run("PackSwitcher failure with nothing loaded reverts to empty") {
            var s = PackSwitcher()
            _ = s.request("broken")
            expectEqual(s.finished("broken", success: false), .revert(to: nil))
            expectEqual(s.selected, "")
        }
        TestKit.run("PackSwitcher ignores empty names") {
            var s = PackSwitcher()
            expect(!s.request(""))
        }
    }
}
