import Foundation
import Testing
@testable import MiniBrowser

struct MiniBrowserTests {
    @Test
    func viewportFixtureExistsInSourceTree() {
        let fileURL = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "MiniBrowser/ViewportFixture.html")

        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test
    func harnessCommandsUseStableNotificationNames() {
        let sessionID = "session.id"
        #expect(
            MiniBrowserHarnessCommand.setScenario(.standard).notificationName(for: sessionID)
                == "wkviewport.minibrowser.command.session%2Eid.setScenario.standard"
        )
        #expect(
            MiniBrowserHarnessCommand.setChromeMode(.navigationBarVisible).notificationName(for: sessionID)
                == "wkviewport.minibrowser.command.session%2Eid.setChromeMode.navigationBarVisible"
        )
        #expect(
            MiniBrowserHarnessCommand.setAttachment(.detached).notificationName(for: sessionID)
                == "wkviewport.minibrowser.command.session%2Eid.setAttachment.detached"
        )
    }

    @Test
    func harnessCommandsDecodeStableNotificationNames() {
        let sessionID = "session.id"
        #expect(
            MiniBrowserHarnessCommand.parse(
                notificationName: "wkviewport.minibrowser.command.session%2Eid.setScenario.excludeTopSafeArea"
            )?.sessionID == sessionID
        )
        #expect(
            MiniBrowserHarnessCommand.parse(
                notificationName: "wkviewport.minibrowser.command.session%2Eid.setScenario.excludeTopSafeArea"
            )?.command == .setScenario(.excludeTopSafeArea)
        )
        #expect(
            MiniBrowserHarnessCommand.parse(
                notificationName: "wkviewport.minibrowser.command.session%2Eid.setChromeMode.navigationBarHidden"
            )?.command == .setChromeMode(.navigationBarHidden)
        )
        #expect(
            MiniBrowserHarnessCommand.parse(
                notificationName: "wkviewport.minibrowser.command.session%2Eid.setAttachment.attached"
            )?.command == .setAttachment(.attached)
        )
        #expect(
            MiniBrowserHarnessCommand.parse(notificationName: "wkviewport.minibrowser.command.unknown") == nil
        )
    }
}
