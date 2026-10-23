import Combine
import ServiceManagement

@MainActor
protocol LoginItemServicing {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

@MainActor
private struct MainAppLoginItemService: LoginItemServicing {
    var status: SMAppService.Status { SMAppService.mainApp.status }

    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}

@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var errorMessage: String?

    private let service: any LoginItemServicing

    init(service: (any LoginItemServicing)? = nil) {
        let service = service ?? MainAppLoginItemService()
        self.service = service
        status = service.status
    }

    // A pending registration stays cancellable with the same toggle.
    var isOn: Bool { status == .enabled || requiresApproval }
    var requiresApproval: Bool { status == .requiresApproval }

    func refresh() {
        status = service.status
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        refresh()
        guard enabled != isOn else { return }

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            errorMessage = "ログイン時起動を変更できませんでした: \(error.localizedDescription)"
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
