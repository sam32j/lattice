import SwiftUI
import EventKit

extension NotchSettings {
    @ViewBuilder var notificationsModuleOptions: some View {
        let notifications = FeatureStrings.notchNotifications(l10n.language)
        SettingsRow(symbol: "bell.slash", title: notifications.hideSystemBanner, caption: notifications.hideSystemBannerHint) {
            PermissionGatedToggle(notifications.hideSystemBanner, isOn: $dismissNativeNotifications).labelsHidden()
        }
        if notificationsEnabled, !permissions.accessibility { PermissionRow(kind: .accessibility) }
    }
    @ViewBuilder var calendarModuleOptions: some View {
        let calendar = FeatureStrings.notchCalendar(l10n.language)
        Text(calendar.permission).font(.callout).foregroundStyle(.secondary)
        if permissions.calendarAccess == .fullAccess {
            Label(l10n.s.permissionGranted, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        } else {
            Button(calendar.allow, action: permissions.requestCalendar).disabled(permissions.requestingCalendar)
            Button(calendar.settings, action: permissions.openCalendarSettings)
        }
        Divider()
        switchRow("calendar.badge.clock", calendar.countdown, caption: calendar.countdownHint,
                  isOn: $calendarCountdown)
        switchRow("hourglass", calendar.timeLeft, caption: calendar.timeLeftHint, isOn: $calendarTimeLeft)
        switchRow("number", calendar.weekNumbers, isOn: $calendarWeekNumbers)
        if permissions.calendarAccess == .fullAccess { NotchCalendarSelection() }
    }
}
