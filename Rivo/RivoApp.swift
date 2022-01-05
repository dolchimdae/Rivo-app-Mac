
/* cw UI 내 변수 공유 에러 수정, protocol 연결위한 read 함수 구현 필요 */
import SwiftUI

@main
struct RivoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            MenuCommands()
        }
    }
}
