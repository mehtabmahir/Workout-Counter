import SwiftUI

#if os(iOS)

private enum AppTab: Hashable {
    case home
    case settings
}

private enum AppTheme {
    static let background = Color(red: 0.025, green: 0.035, blue: 0.055)
    static let surface = Color.white.opacity(0.075)
    static let elevatedSurface = Color.white.opacity(0.11)
    static let border = Color.white.opacity(0.10)
    static let secondaryText = Color.white.opacity(0.62)
    static let accent = Color(red: 0.48, green: 0.94, blue: 0.42)
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tag(AppTab.home)
            .tabItem {
                Label("Workouts", systemImage: "figure.run")
            }

            NavigationStack {
                SettingsView()
            }
            .tag(AppTab.settings)
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .tint(AppTheme.accent)
        .toolbarBackground(AppTheme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
    }
}

private struct HomeView: View {
    var body: some View {
        ZStack {
            appBackground

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    brandHeader
                    heroCard
                    exerciseSection
                    privacyCard
                    AppFooter()
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var appBackground: some View {
        ZStack {
            AppTheme.background

            RadialGradient(
                colors: [AppTheme.accent.opacity(0.15), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 390
            )
        }
        .ignoresSafeArea()
    }

    private var brandHeader: some View {
        HStack(spacing: 13) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: 46, height: 46)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("WORKOUT COUNTER")
                    .font(.caption.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(AppTheme.secondaryText)

                Text("Train with focus.")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            Text("ON DEVICE")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AppTheme.accent.opacity(0.11))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(AppTheme.accent.opacity(0.25), lineWidth: 1)
                }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR CAMERA.\nYOUR REPS.")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .tracking(-1.2)
                    .foregroundStyle(.white)

                Text("Real-time exercise tracking designed to let you concentrate on your form—not the count.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Label("Private", systemImage: "lock.fill")
                dividerDot
                Label("No account", systemImage: "person.crop.circle.badge.xmark")
                dividerDot
                Label("No uploads", systemImage: "icloud.slash.fill")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.78))
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.11, green: 0.17, blue: 0.16),
                    Color(red: 0.055, green: 0.075, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.18), lineWidth: 1)
        }
    }

    private var dividerDot: some View {
        Circle()
            .fill(Color.white.opacity(0.25))
            .frame(width: 3, height: 3)
    }

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Exercises")
                    .font(.title2.weight(.bold))

                Spacer()

                Text("MORE COMING SOON")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.9)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            NavigationLink {
                WorkoutView()
            } label: {
                AvailableExerciseCard()
            }
            .buttonStyle(.plain)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ComingSoonExerciseCard(
                    title: "Squats",
                    icon: "figure.squat"
                )
                ComingSoonExerciseCard(
                    title: "Push-Ups",
                    icon: "figure.strengthtraining.functional"
                )
                ComingSoonExerciseCard(
                    title: "Shoulder Press",
                    icon: "dumbbell.fill"
                )
                ComingSoonExerciseCard(
                    title: "Lunges",
                    icon: "figure.step.training"
                )
            }
        }
    }

    private var privacyCard: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: "lock.shield.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 42, height: 42)
                .background(AppTheme.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("Built for privacy")
                    .font(.headline)

                Text("Pose detection happens on your iPhone. Workout Counter does not save or upload your camera video.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }
}

private struct AvailableExerciseCard: View {
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "dumbbell.fill")
                .font(.title2)
                .foregroundStyle(.black)
                .frame(width: 54, height: 54)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text("Bicep Curls")
                    .font(.title3.weight(.bold))

                Text("Single-arm rep tracking")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.black)
                .frame(width: 36, height: 36)
                .background(AppTheme.accent)
                .clipShape(Circle())
        }
        .foregroundStyle(.white)
        .padding(17)
        .background(AppTheme.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.accent.opacity(0.22), lineWidth: 1)
        }
        .accessibilityHint("Opens the bicep curl counter")
    }
}

private struct ComingSoonExerciseCard: View {
    let title: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))

                Text("COMING SOON")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsView: View {
    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Settings")
                            .font(.system(size: 36, weight: .bold, design: .rounded))

                        Text("Workout experience, privacy, and app information.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    SettingsSection(title: "WORKOUT EXPERIENCE") {
                        SettingsRow(
                            icon: "camera.fill",
                            title: "Camera",
                            detail: "Front camera · Mirrored preview"
                        )

                        SettingsDivider()

                        SettingsRow(
                            icon: "figure.arms.open",
                            title: "Tracking mode",
                            detail: "Single arm"
                        )
                    }

                    SettingsSection(title: "PRIVACY") {
                        SettingsRow(
                            icon: "iphone.gen3",
                            title: "Pose processing",
                            detail: "Runs on this iPhone"
                        )

                        SettingsDivider()

                        SettingsRow(
                            icon: "video.slash.fill",
                            title: "Camera video",
                            detail: "Never saved or uploaded"
                        )

                        SettingsDivider()

                        SettingsRow(
                            icon: "person.crop.circle.badge.xmark",
                            title: "Account",
                            detail: "Not required"
                        )
                    }

                    SettingsSection(title: "ABOUT") {
                        SettingsRow(
                            icon: "app.badge.fill",
                            title: "Workout Counter",
                            detail: versionDescription
                        )

                        SettingsDivider()

                        SettingsRow(
                            icon: "heart.fill",
                            title: "Designed for",
                            detail: "Focused, private workouts"
                        )
                    }

                    legalNotice
                    AppFooter()
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var versionDescription: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "1"

        return "Version \(version) (\(build))"
    }

    private var legalNotice: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Important information")
                .font(.headline)

            Text("Workout Counter provides automated rep estimates for general fitness use. It is not medical advice and does not replace professional coaching. Always exercise within your abilities and surroundings.")
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 1)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 17)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            }
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 36, height: 36)
                .background(AppTheme.accent.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.border)
            .frame(height: 1)
            .padding(.leading, 50)
    }
}

private struct AppFooter: View {
    var body: some View {
        VStack(spacing: 5) {
            Text("WORKOUT COUNTER")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(.white.opacity(0.5))

            Text("© 2026 Workout Counter. All rights reserved.")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.34))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

#endif
