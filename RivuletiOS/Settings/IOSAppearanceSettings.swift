// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0
// Copyright (C) 2026 Bain Gurley

import SwiftUI
import UIKit

enum IOSAppTheme: String, CaseIterable {
    case system, light, dark

    static let storageKey = "iosAppTheme"

    var title: LocalizedStringKey {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}

struct IOSAppearanceSettingsView: View {
    @State private var appIcon = AppIcon.current
    @AppStorage(IOSAppTheme.storageKey) private var appTheme: IOSAppTheme = .system

    var body: some View {
        Form {
            Section {
                Picker("App Icon", selection: $appIcon) {
                    ForEach(AppIcon.allCases) { icon in
                        Text(icon.title).tag(icon)
                    }
                }
                .onChange(of: appIcon) { _, icon in
                    icon.apply()
                }

                Picker("App Theme", selection: $appTheme) {
                    ForEach(IOSAppTheme.allCases, id: \.self) { theme in
                        Text(theme.title).tag(theme)
                    }
                }
            }
            .pickerStyle(.menu)
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}
