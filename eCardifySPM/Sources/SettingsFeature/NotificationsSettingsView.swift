import SwiftUI
import L10nResources
import FoundationExtension
import ComposableArchitecture

struct NotificationsSettingsView: View {

  @Bindable var store: StoreOf<Settings>

    var body: some View {
        SettingsForm {
            SettingsRow {
                Toggle(
                    L("Enable notifications"), isOn: $store.enableNotifications
                )
                .font(.system(size: 16, design: .rounded))
                Text(L("Notification warning"))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.red)
                    .padding(.top, -20)
            }
        }
        .navigationTitle(L("Notifications"))
    }
}

public struct SettingsForm<Content>: View where Content: View {
  @Environment(\.colorScheme) var colorScheme
  let content: () -> Content

  public init(@ViewBuilder content: @escaping () -> Content) {
    self.content = content
  }

  public var body: some View {
    ScrollView {
      self.content()
        .font(.system(size: 15, design: .rounded))
//        .toggleStyle(SwitchToggleStyle(tint: .isowordsOrange))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

