import SwiftUI
import UIKit

/// The signed-in user's photo — a locally-chosen override when set, otherwise the Google account
/// photo, falling back to a plain SF Symbol placeholder. Shared between the Home Screen header
/// button and the larger Settings account row so both stay in sync automatically.
struct AvatarView: View {
    @Environment(AuthManager.self) private var authManager
    var size: CGFloat = 38

    var body: some View {
        Group {
            if let customPhotoData = authManager.customPhotoData, let uiImage = UIImage(data: customPhotoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let url = authManager.googlePhotoURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .background(Color.dashboardCard, in: Circle())
    }

    private var placeholder: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: size))
            .foregroundStyle(Color.dashboardInkSecondary)
    }
}

/// Small circular avatar button, sized and styled to match `WeekStripView`'s calendar button.
struct AvatarButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            AvatarView(size: 38)
        }
        .accessibilityLabel("Account & Settings")
    }
}
