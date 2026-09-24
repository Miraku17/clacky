import Foundation
import ClackyCore

enum PackConfigReleaseTests {
    static func run() {
        TestKit.run("PackConfig separates -up defines into keyUpDefines") {
            let json = #"{"key_define_type":"multi","sound":"press/G{0-1}.mp3","soundup":"release/GENERIC.mp3","defines":{"14":"press/B.mp3","14-up":"release/B.mp3","57-up":"release/S.mp3"}}"#
            let config = try PackConfig.parse(Data(json.utf8))
            expectEqual(config.defines, [14: .file("press/B.mp3")])
            expectEqual(config.keyUpDefines, [14: .file("release/B.mp3"), 57: .file("release/S.mp3")])
            expectEqual(config.soundUp, "release/GENERIC.mp3")
        }
        TestKit.run("PackConfig soundup plain name yields one generic release file") {
            let json = #"{"key_define_type":"multi","soundup":"release/GENERIC.mp3","defines":{"1":"a.wav"}}"#
            expectEqual(try PackConfig.parse(Data(json.utf8)).genericReleaseFiles, ["release/GENERIC.mp3"])
        }
        TestKit.run("PackConfig soundup pattern expands") {
            let json = #"{"key_define_type":"multi","soundup":"release/G{0-2}.mp3","defines":{"1":"a.wav"}}"#
            expectEqual(try PackConfig.parse(Data(json.utf8)).genericReleaseFiles, ["release/G0.mp3", "release/G1.mp3", "release/G2.mp3"])
        }
        TestKit.run("PackConfig without soundup has no generic release files") {
            let json = #"{"key_define_type":"multi","defines":{"1":"a.wav"}}"#
            let config = try PackConfig.parse(Data(json.utf8))
            expectEqual(config.genericReleaseFiles, [])
            expectNil(config.soundUp)
            expectEqual(config.keyUpDefines, [:])
        }
        TestKit.run("PackConfig single pack ignores soundup") {
            let json = #"{"key_define_type":"single","sound":"s.ogg","soundup":"r.ogg","defines":{"1":[0,10]}}"#
            expectEqual(try PackConfig.parse(Data(json.utf8)).genericReleaseFiles, [])
        }
    }
}
