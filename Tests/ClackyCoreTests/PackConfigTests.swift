import Foundation
import ClackyCore

enum PackConfigTests {
    static func run() {
        TestKit.run("PackConfig loads the real single pack") {
            let config = try PackConfig.load(from: TestPaths.defaultPack.appendingPathComponent("config.json"))
            expectEqual(config.keyDefineType, .single)
            expectEqual(config.sound, "sound.ogg")
            expectEqual(config.name, "CherryMX Blue - PBT keycaps")
            expectEqual(config.defines.count, 114)
            guard case .span(let start, let duration)? = config.defines[57] else { return expect(false, "space missing") }
            expect(start >= 0)
            expect(duration > 0)
        }
        TestKit.run("PackConfig parses a multi pack") {
            let json = #"{"name":"m","key_define_type":"multi","defines":{"57":"space.wav","28":"enter.wav"}}"#
            let config = try PackConfig.parse(Data(json.utf8))
            expectEqual(config.keyDefineType, .multi)
            expectNil(config.sound)
            expectEqual(config.defines, [57: .file("space.wav"), 28: .file("enter.wav")])
        }
        TestKit.run("PackConfig skips null, non-integer and malformed defines") {
            let json = #"{"key_define_type":"single","sound":"s.ogg","defines":{"1":[0,100],"2":null,"KeyA":[5,5],"3":[7],"4":"x.wav"}}"#
            let config = try PackConfig.parse(Data(json.utf8))
            expectEqual(config.defines, [1: .span(startMs: 0, durationMs: 100), 4: .file("x.wav")])
        }
        TestKit.run("PackConfig single without sound throws") {
            expectThrows(try PackConfig.parse(Data(#"{"key_define_type":"single","defines":{"1":[0,1]}}"#.utf8)))
        }
        TestKit.run("PackConfig malformed JSON throws") {
            expectThrows(try PackConfig.parse(Data("{not json".utf8)))
        }
        TestKit.run("PackConfig name is nil when absent") {
            expectNil(try PackConfig.parse(Data(#"{"key_define_type":"multi","defines":{"1":"a.wav"}}"#.utf8)).name)
        }
    }
}
