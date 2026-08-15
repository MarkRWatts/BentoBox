import SwiftUI

/// Colored rounded-square glyph matching the system Settings app's row-icon style, so this
/// screen reads as considered rather than a flat list of plain text rows.
struct SettingsRowIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 7))
    }
}
