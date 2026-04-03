import Foundation
import Testing

struct MiniBrowserTests {
    @Test
    func viewportFixtureExistsInSourceTree() {
        let fileURL = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "MiniBrowser/ViewportFixture.html")

        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }
}
