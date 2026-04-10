import SwiftUI

struct StationRowView: View {
    let station: RadioStation
    let isPlaying: Bool

    @AppStorage("themeColor") private var themeColorName = "blue"
    private var accentColor: Color { AppTheme.color(for: themeColorName) }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                if let data = station.customImageData,
                   let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholderIcon
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isPlaying ? accentColor : Color.clear, lineWidth: 2)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(station.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var placeholderIcon: some View {
        ZStack {
            Color.secondary.opacity(0.2)
            Image(systemName: "radio")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}
