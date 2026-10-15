import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

enum GoogleOAuthError: Error, LocalizedError {
    case missingClientID
    case userCancelled
    case noAuthorizationCode
    case tokenExchangeFailed(String)
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "No Google client ID is configured. Add one in Secrets.xcconfig."
        case .userCancelled:
            return "Sign-in was cancelled."
        case .noAuthorizationCode:
            return "Google didn't return an authorization code."
        case .tokenExchangeFailed(let message):
            return "Google sign-in failed: \(message)"
        case .notSignedIn:
            return "Not signed in to Google."
        }
    }
}

/// Manual OAuth 2.0 (Authorization Code + PKCE) flow for "installed apps", per Google's own
/// docs for this client type — no GoogleSignIn SDK dependency, just ASWebAuthenticationSession
/// and URLSession. Read-only Calendar scope only; nothing is ever written back to the user's
/// calendar.
@MainActor
final class GoogleOAuthManager: NSObject, ObservableObject {
    static let shared = GoogleOAuthManager()

    @Published private(set) var isSignedIn: Bool

    private static let refreshTokenKey = "google_refresh_token"
    private static let scope = "https://www.googleapis.com/auth/calendar.readonly"
    private static let authEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    private static let tokenEndpoint = "https://oauth2.googleapis.com/token"

    private var accessToken: String?
    private var accessTokenExpiry: Date = .distantPast
    private var webSession: ASWebAuthenticationSession?

    private var clientID: String {
        Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String ?? ""
    }
    private var redirectScheme: String {
        Bundle.main.object(forInfoDictionaryKey: "GOOGLE_REVERSED_CLIENT_ID") as? String ?? ""
    }
    private var redirectURI: String { "\(redirectScheme):/oauth2redirect/google" }

    override init() {
        isSignedIn = KeychainStore.get(Self.refreshTokenKey) != nil
        super.init()
    }

    func signIn() async throws {
        guard !clientID.isEmpty, !redirectScheme.isEmpty else { throw GoogleOAuthError.missingClientID }

        let verifier = Self.makeCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)

        var components = URLComponents(string: Self.authEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scope),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            // Forces a fresh consent screen so Google always hands back a refresh_token —
            // without this, re-signing in after a token was already issued once silently
            // omits it.
            URLQueryItem(name: "prompt", value: "consent")
        ]

        let callbackURL = try await presentWebAuth(url: components.url!)
        guard let code = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "code" })?.value else {
            throw GoogleOAuthError.noAuthorizationCode
        }

        try await exchangeCodeForTokens(code: code, verifier: verifier)
        isSignedIn = true
    }

    func signOut() {
        KeychainStore.remove(Self.refreshTokenKey)
        accessToken = nil
        accessTokenExpiry = .distantPast
        isSignedIn = false
    }

    /// Returns a valid access token, refreshing it first if it's expired or about to expire.
    func validAccessToken() async throws -> String {
        if let accessToken, Date() < accessTokenExpiry.addingTimeInterval(-60) {
            return accessToken
        }
        guard let refreshToken = KeychainStore.get(Self.refreshTokenKey) else {
            throw GoogleOAuthError.notSignedIn
        }
        return try await refresh(refreshToken: refreshToken)
    }

    // MARK: - Token exchange

    private func exchangeCodeForTokens(code: String, verifier: String) async throws {
        var request = URLRequest(url: URL(string: Self.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        request.httpBody = Self.formEncode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, data: data)

        struct TokenResponse: Decodable {
            let access_token: String
            let expires_in: Int
            let refresh_token: String?
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        accessToken = decoded.access_token
        accessTokenExpiry = Date().addingTimeInterval(TimeInterval(decoded.expires_in))
        if let refreshToken = decoded.refresh_token {
            KeychainStore.set(refreshToken, forKey: Self.refreshTokenKey)
        }
    }

    private func refresh(refreshToken: String) async throws -> String {
        var request = URLRequest(url: URL(string: Self.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "client_id": clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        request.httpBody = Self.formEncode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        do {
            try Self.validate(response: response, data: data)
        } catch {
            // A refresh_token can be revoked (user removed app access in their Google
            // account) — treat that as signed-out rather than surfacing a raw network error
            // every time the app tries to plan alerts.
            signOut()
            throw error
        }

        struct TokenResponse: Decodable {
            let access_token: String
            let expires_in: Int
        }
        let decoded = try JSONDecoder().decode(TokenResponse.self, from: data)
        accessToken = decoded.access_token
        accessTokenExpiry = Date().addingTimeInterval(TimeInterval(decoded.expires_in))
        return decoded.access_token
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP error"
            throw GoogleOAuthError.tokenExchangeFailed(message)
        }
    }

    private static func formEncode(_ body: [String: String]) -> Data {
        body.map { key, value in
            let allowed = CharacterSet.urlQueryAllowed.subtracting(.init(charactersIn: "&=+"))
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(key)=\(encodedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8)!
    }

    // MARK: - PKCE

    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URLEncode(Data(bytes))
    }

    private static func codeChallenge(for verifier: String) -> String {
        let hashed = SHA256.hash(data: Data(verifier.utf8))
        return base64URLEncode(Data(hashed))
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    // MARK: - Web auth presentation

    private func presentWebAuth(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: redirectScheme) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                    continuation.resume(throwing: GoogleOAuthError.userCancelled)
                } else {
                    continuation.resume(throwing: error ?? GoogleOAuthError.noAuthorizationCode)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.webSession = session
            session.start()
        }
    }
}

extension GoogleOAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        return scene?.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}
