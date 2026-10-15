import SwiftUI

struct ErrorStateView: View {
    let error: Error
    let retry: () -> Void

    private var icon: String {
        switch error as? MTDServiceError {
        case .noNetwork: return "wifi.slash"
        case .rateLimited: return "clock.badge.exclamationmark"
        case .apiError: return "exclamationmark.triangle"
        default: return "exclamationmark.circle"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text((error as? MTDServiceError)?.errorDescription ?? error.localizedDescription)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Try Again", action: retry)
                .buttonStyle(.bordered)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

struct LoadingStateView: View {
    var body: some View {
        VStack {
            ProgressView()
            Text("Loading…").font(.caption).foregroundStyle(.secondary).padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}
