import Testing
import Foundation
@testable import SelectTrans

@MainActor
struct TranslationStreamCoordinatorTests {
    @Test func fastModeStreamsLiteralBeforeDetails() async throws {
        var prompts: [String] = []
        var emitted = ""
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let preferences = TranslationPreferenceStore(defaults: defaults)
        preferences.isFastLiteralDisplayEnabled = true
        let coordinator = TranslationStreamCoordinator { prompt, _, onDelta in
            prompts.append(prompt)
            onDelta(prompts.count == 1 ? "明示されていない" : "【つまり】\nはっきり述べられていない")
        }

        let output = try await coordinator.run(
            text: "not explicitly mentioned",
            direction: .enToJa,
            mode: .translate,
            model: "test-model",
            preferences: preferences.current
        ) { emitted += $0 }

        #expect(prompts.count == 2)
        #expect(output == "【直訳】\n明示されていない\n\n【つまり】\nはっきり述べられていない")
        #expect(emitted == output)
    }

    @Test func standardModeUsesOneCompletePrompt() async throws {
        var prompts: [String] = []
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let coordinator = TranslationStreamCoordinator { prompt, _, onDelta in
            prompts.append(prompt)
            onDelta("complete")
        }

        _ = try await coordinator.run(
            text: "hello",
            direction: .enToJa,
            mode: .translate,
            model: "test-model",
            preferences: TranslationPreferenceStore(defaults: defaults).current
        ) { _ in }

        #expect(prompts.count == 1)
        #expect(prompts[0].contains("【直訳】"))
    }

    @Test func detailFailureKeepsEmittedLiteral() async {
        struct DetailError: Error {}
        var requestCount = 0
        var emitted = ""
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let preferences = TranslationPreferenceStore(defaults: defaults)
        preferences.isFastLiteralDisplayEnabled = true
        let coordinator = TranslationStreamCoordinator { _, _, onDelta in
            requestCount += 1
            if requestCount == 2 { throw DetailError() }
            onDelta("literal")
        }

        do {
            _ = try await coordinator.run(
                text: "hello",
                direction: .enToJa,
                mode: .translate,
                model: "test-model",
                preferences: preferences.current
            ) { emitted += $0 }
            Issue.record("Expected detail request to fail")
        } catch is DetailError {
            #expect(emitted == "【直訳】\nliteral\n\n")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func proofreadModeIgnoresEnabledFastPreference() async throws {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let preferences = TranslationPreferenceStore(defaults: defaults)
        preferences.isFastLiteralDisplayEnabled = true
        var requestCount = 0
        let coordinator = TranslationStreamCoordinator { _, _, onDelta in
            requestCount += 1
            onDelta("proofread")
        }

        _ = try await coordinator.run(
            text: "helo",
            direction: .enToJa,
            mode: .proofread,
            model: "test-model",
            preferences: preferences.current
        ) { _ in }

        #expect(requestCount == 1)
    }
}
