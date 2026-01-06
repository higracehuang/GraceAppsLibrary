import SwiftUI

struct DeveloperSignatureView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image("DeveloperProfilePicture", bundle: .module)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            Text("Grace")
                .font(.system(.subheadline, design: .serif))
                .italic()
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    DeveloperSignatureView()
        .background(Color(UIColor.systemGroupedBackground))
}
