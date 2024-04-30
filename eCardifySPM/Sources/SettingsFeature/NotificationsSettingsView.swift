import SwiftUI
import FoundationExtension
import ComposableArchitecture

struct NotificationsSettingsView: View {

  @Perception.Bindable var store: StoreOf<Settings>

    var body: some View {
        WithPerceptionTracking {
            SettingsForm {
                SettingsRow {
                    Toggle(
                        "Enable notifications", isOn: $store.enableNotifications
                    )
                    .font(.system(size: 16, design: .rounded))
                    Text("*** Please don't turn off notification then whole function will be turn off")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.red)
                        .padding(.top, -20)
                }
            }
            .navigationTitle("Notifications")
        }
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

