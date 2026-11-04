import Feedback
import SwiftUI

extension View {
    /// Tags the whole list cell as well, so a tap on the cell's padding selects the row instead of the screen.
    func feedbackCell<V: View>(_ view: V, file: String = #fileID, line: Int = #line) -> some View {
        #if canImport(UIKit)
        feedback(view, file: file, line: line)
            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground).feedback(view, file: file, line: line))
        #else
        self
        #endif
    }

    func feedbackCell(_ name: String, data: Any? = nil, file: String = #fileID, line: Int = #line) -> some View {
        #if canImport(UIKit)
        feedback(name, data: data, file: file, line: line)
            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground).feedback(name, data: data, file: file, line: line))
        #else
        self
        #endif
    }
}

// Feedback compiles to an empty module on macOS, so the Mac build gets no-op tags.
#if !canImport(UIKit)
extension View {
    func feedback(_ name: String, data: Any? = nil) -> some View { self }
    func feedback<V: View>(_ view: V) -> some View { self }
}
#endif
