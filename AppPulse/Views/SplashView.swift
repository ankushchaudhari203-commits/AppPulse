import SwiftUI

struct SplashView: View {
    @Binding var isVisible: Bool

    @State private var iconScale: CGFloat = 0.4
    @State private var iconOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 16
    @State private var ringScale: CGFloat = 1.0
    @State private var ringOpacity: Double = 0.6

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    // Expanding pulse ring
                    Circle()
                        .stroke(Color.accentColor.opacity(ringOpacity), lineWidth: 2)
                        .frame(width: 90, height: 90)
                        .scaleEffect(ringScale)

                    // Icon backing circle
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 88, height: 88)

                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 38, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .scaleEffect(iconScale)
                .opacity(iconOpacity)

                VStack(spacing: 5) {
                    Text("AppPulse")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("QE Dashboard")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(textOpacity)
                .offset(y: textOffset)
            }
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        // Icon scales in
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
            iconScale = 1
            iconOpacity = 1
        }

        // Text slides up
        withAnimation(.easeOut(duration: 0.35).delay(0.3)) {
            textOpacity = 1
            textOffset = 0
        }

        // Pulse ring expands and fades — twice
        animatePulse(delay: 0.5)
        animatePulse(delay: 1.2)

        // Dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation(.easeIn(duration: 0.35)) {
                isVisible = false
            }
        }
    }

    private func animatePulse(delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            ringScale = 1.0
            ringOpacity = 0.6
            withAnimation(.easeOut(duration: 0.65)) {
                ringScale = 1.9
                ringOpacity = 0
            }
        }
    }
}

#Preview {
    SplashView(isVisible: .constant(true))
        .frame(width: 400, height: 300)
}
