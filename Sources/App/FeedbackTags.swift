import Feedback
import SwiftUI

extension View {
    /// Tags the whole list cell as well, so a tap on the cell's padding selects the row instead of the screen.
    func feedbackCell<V: View>(_ view: V, file: String = #fileID, line: Int = #line) -> some View {
        feedback(view, file: file, line: line)
            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground).feedback(view, file: file, line: line))
    }

    func feedbackCell(_ name: String, data: Any? = nil, file: String = #fileID, line: Int = #line) -> some View {
        feedback(name, data: data, file: file, line: line)
            .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground).feedback(name, data: data, file: file, line: line))
    }
}
