import Testing
import Foundation
@testable import AIEnglishApp

// MARK: - AIResponse JSON 解析测试

struct AIResponseDecodeTests {

    @Test func decodesFullResponse() throws {
        let json = """
        {
            "reply": "The meeting has been postponed today.",
            "intent": {
                "language": "zh",
                "is_meaningful": true,
                "is_compliant": true,
                "has_clear_scene": true
            },
            "material": {
                "scene_tag": "work",
                "level": "sentence",
                "english": "The meeting has been postponed today."
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AIResponse.self, from: json)

        #expect(response.reply == "The meeting has been postponed today.")
        #expect(response.intent.language == "zh")
        #expect(response.intent.isMeaningful == true)
        #expect(response.intent.isCompliant == true)
        #expect(response.intent.hasClearScene == true)
        #expect(response.material.sceneTag == "work")
        #expect(response.material.level == "sentence")
        #expect(response.material.english == "The meeting has been postponed today.")
    }

    @Test func rejectsIncompleteJSON() {
        let json = #"{"reply":"Hello"}"#.data(using: .utf8)!
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AIResponse.self, from: json)
        }
    }
}

// MARK: - 测试用假服务（注入用，不发真实网络请求）

private struct SuccessMock: AIServicing {
    func generate(text: String) async throws -> AIResponse {
        AIResponse(
            reply: "Test reply",
            intent: .init(language: "zh", isMeaningful: true, isCompliant: true, hasClearScene: true),
            material: .init(sceneTag: "work", level: "sentence", english: "Test reply")
        )
    }
}

private struct FailingMock: AIServicing {
    func generate(text: String) async throws -> AIResponse {
        throw AIServiceError.requestFailed
    }
}

// MARK: - TodayViewModel 状态机测试

struct TodayViewModelTests {

    @Test func sendAppendsUserAndAIMessages() async {
        let vm = TodayViewModel(service: SuccessMock())
        await vm.send("今天会议推迟了")

        #expect(vm.messages.count == 2)
        #expect(vm.messages[0].role == .user)
        #expect(vm.messages[0].text == "今天会议推迟了")
        #expect(vm.messages[1].role == .ai)
        #expect(vm.messages[1].text == "Test reply")
        #expect(vm.isLoading == false)
        #expect(vm.errorMessage == nil)
    }

    @Test func sendSetsErrorMessageOnFailure() async {
        let vm = TodayViewModel(service: FailingMock())
        await vm.send("今天会议推迟了")

        #expect(vm.messages.count == 1)
        #expect(vm.messages[0].role == .user)
        #expect(vm.errorMessage == "生成失败，请重试")
        #expect(vm.isLoading == false)
    }

    @Test func sendIgnoresBlankInput() async {
        let vm = TodayViewModel(service: SuccessMock())
        await vm.send("   ")

        #expect(vm.messages.isEmpty)
        #expect(vm.isLoading == false)
    }
}
