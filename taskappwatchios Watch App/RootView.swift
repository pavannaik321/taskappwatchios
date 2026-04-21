import SwiftUI

// MARK: - App route enum (mirrors Go Router routes in Wear OS)
enum AppRoute: Equatable {
    case splash
    case login
    case home
}

struct RootView: View {
    @State private var route: AppRoute = .splash

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            switch route {
            case .splash:
                SplashView { isLoggedIn in
                    withAnimation(.easeInOut(duration: 0.35)) {
                        route = isLoggedIn ? .home : .login
                    }
                }
                .transition(.opacity)
            case .login:
                PinLoginView(onLogin: {
                    withAnimation(.easeInOut(duration: 0.35)) { route = .home }
                })
                .transition(.opacity)
            case .home:
                HomeView(onLogout: {
                    withAnimation(.easeInOut(duration: 0.35)) { route = .login }
                })
                .transition(.opacity)
            }
        }
    }
}
