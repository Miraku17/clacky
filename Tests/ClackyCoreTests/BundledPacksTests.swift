import Foundation
import ClackyCore

enum BundledPacksTests {
    static func run() {
        TestKit.run("every bundled pack loads and plays the A key") {
            let lib = PackLibrary(packsDirectory: TestPaths.packsRoot, bundledPacksDirectory: nil)
            let packs = lib.availablePacks()
            expect(packs.count >= 18, "expected the full Mechvibes set, found \(packs.count)")
            for folder in packs {
                do {
                    let pack = try SoundPack(folder: folder)
                    expect(pack.keyCount > 0 || pack.hasGenericPool, "\(folder.lastPathComponent) has neither defined keys nor a generic pool")
                    expect(pack.buffer(for: 30).frameLength > 0, "\(folder.lastPathComponent) A key is silent")
                } catch {
                    expect(false, "\(folder.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }
    }
}
