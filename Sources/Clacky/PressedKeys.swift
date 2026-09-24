import Combine
import Foundation

/// The key codes currently held down, kept separate from AppState so only
/// the keyboard view re-renders on every keystroke.
final class PressedKeys: ObservableObject {
    @Published var codes: Set<Int64> = []
}
