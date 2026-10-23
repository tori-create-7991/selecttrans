import ServiceManagement
import Testing
@testable import SelectTrans

// Unit tests: the injected service never changes the user's actual login items.
@MainActor
struct LoginItemControllerTests {
    @Test func readsCurrentStatusWithoutRegisteringAtLaunch() {
        let service = LoginItemServiceStub(status: .notRegistered)
        let controller = LoginItemController(service: service)

        #expect(!controller.isOn)
        #expect(service.registerCalls == 0)
        #expect(service.unregisterCalls == 0)
    }

    @Test func showsAnExistingRegistrationAsOn() {
        let controller = LoginItemController(service: LoginItemServiceStub(status: .enabled))
        #expect(controller.isOn)
        #expect(!controller.requiresApproval)
    }

    @Test func enablingRegistersTheApp() {
        let service = LoginItemServiceStub(status: .notRegistered)
        let controller = LoginItemController(service: service)

        controller.setEnabled(true)

        #expect(service.registerCalls == 1)
        #expect(service.unregisterCalls == 0)
        #expect(controller.status == .enabled)
        #expect(controller.errorMessage == nil)
    }

    @Test func disablingUnregistersTheApp() {
        let service = LoginItemServiceStub(status: .enabled)
        let controller = LoginItemController(service: service)

        controller.setEnabled(false)

        #expect(service.unregisterCalls == 1)
        #expect(service.registerCalls == 0)
        #expect(!controller.isOn)
    }

    @Test func pendingApprovalIsDistinguishedFromEnabled() {
        let service = LoginItemServiceStub(status: .notRegistered)
        service.registrationStatus = .requiresApproval
        let controller = LoginItemController(service: service)

        controller.setEnabled(true)

        #expect(controller.status == .requiresApproval)
        #expect(controller.isOn)
        #expect(controller.requiresApproval)
        #expect(controller.errorMessage == nil)
    }

    @Test func pendingRegistrationCanBeCancelled() {
        let service = LoginItemServiceStub(status: .requiresApproval)
        let controller = LoginItemController(service: service)

        controller.setEnabled(false)

        #expect(service.unregisterCalls == 1)
        #expect(!controller.isOn)
        #expect(!controller.requiresApproval)
    }

    @Test func refreshReflectsChangesMadeInSystemSettings() {
        let service = LoginItemServiceStub(status: .enabled)
        let controller = LoginItemController(service: service)
        service.status = .requiresApproval

        controller.refresh()
        #expect(controller.requiresApproval)

        service.status = .notRegistered
        controller.refresh()
        #expect(!controller.isOn)
        #expect(service.registerCalls == 0)
        #expect(service.unregisterCalls == 0)
    }

    @Test func registrationFailureDoesNotShowSuccess() {
        let service = LoginItemServiceStub(status: .notRegistered)
        service.registerError = LoginItemTestError.failed
        let controller = LoginItemController(service: service)

        controller.setEnabled(true)

        #expect(!controller.isOn)
        #expect(controller.errorMessage != nil)
    }

    @Test func unregistrationFailureKeepsActualEnabledState() {
        let service = LoginItemServiceStub(status: .enabled)
        service.unregisterError = LoginItemTestError.failed
        let controller = LoginItemController(service: service)

        controller.setEnabled(false)

        #expect(controller.isOn)
        #expect(controller.errorMessage != nil)
    }

    @Test func successfulRetryClearsThePreviousError() {
        let service = LoginItemServiceStub(status: .notRegistered)
        service.registerError = LoginItemTestError.failed
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        service.registerError = nil

        controller.setEnabled(true)

        #expect(controller.isOn)
        #expect(controller.errorMessage == nil)
    }

    @Test func externalRecoveryClearsThePreviousError() {
        let service = LoginItemServiceStub(status: .notRegistered)
        service.registerError = LoginItemTestError.failed
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        #expect(controller.errorMessage != nil)

        service.status = .enabled
        controller.refresh()

        #expect(controller.isOn)
        #expect(controller.errorMessage == nil)
    }

    @Test func missingServiceDoesNotShowAnEnabledRegistration() {
        let service = LoginItemServiceStub(status: .notFound)
        service.registerError = LoginItemTestError.failed
        let controller = LoginItemController(service: service)
        #expect(!controller.isOn)

        controller.setEnabled(true)

        #expect(controller.status == .notFound)
        #expect(!controller.isOn)
        #expect(controller.errorMessage != nil)
    }

    @Test func changingToTheCurrentStateDoesNotReregister() {
        let service = LoginItemServiceStub(status: .enabled)
        let controller = LoginItemController(service: service)
        controller.setEnabled(true)
        service.status = .requiresApproval
        controller.setEnabled(true)
        service.status = .notRegistered
        controller.setEnabled(false)

        #expect(service.registerCalls == 0)
        #expect(service.unregisterCalls == 0)
    }
}

@MainActor
private final class LoginItemServiceStub: LoginItemServicing {
    var status: SMAppService.Status
    var registrationStatus: SMAppService.Status = .enabled
    var registerError: Error?
    var unregisterError: Error?
    var registerCalls = 0
    var unregisterCalls = 0

    init(status: SMAppService.Status) { self.status = status }

    func register() throws {
        registerCalls += 1
        if let registerError { throw registerError }
        status = registrationStatus
    }

    func unregister() throws {
        unregisterCalls += 1
        if let unregisterError { throw unregisterError }
        status = .notRegistered
    }
}

private enum LoginItemTestError: Error { case failed }
