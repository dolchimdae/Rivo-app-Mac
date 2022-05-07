
import SwiftUI

struct ContentView: View {
    var bleManager = CBController()
    var body: some View {
        SettingList(bleManager: bleManager)
            .frame(width: 800, height: 500)
            //.fixedSize(horizontal: true, vertical: true)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
            //ContentView()
        }
    }
}
