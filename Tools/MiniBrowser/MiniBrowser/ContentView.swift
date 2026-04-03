import SwiftUI

struct ContentView: View {
    @State private var state = MiniBrowserHarnessState()

    var body: some View {
        MiniBrowserHarnessContainer(state: state)
            .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
