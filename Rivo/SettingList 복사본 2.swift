//
//
//  SettingList.swift
//  Rivo
//

import Foundation
import SwiftUI
import WebKit


struct Menu: Hashable {
    let title : String
}
struct SettingList: View {
    @ObservedObject var bleManager : CBController
    
    var body: some View {
        let Menu: [Menu] = [
            .init(title: "설정"),
            .init(title: "업데이트"),
            .init(title: "My리보"),
            .init(title: "도움말")
        ]
        NavigationView {
            List {
                HStack { // 현재 리보 상태 표시창
                    if(bleManager.isConnected){
                        Text("연결")
                            .bold()
                        Spacer()
                        if(bleManager.battery.count>1){
                            Text("\(bleManager.battery)%")
                                .bold()
                        }else{
                            Text("\(bleManager.battery)")
                                .bold()
                        }
                    }
                    else {
                        Text("미연결")
                            .bold()
                    }
                }
                Divider()
                ForEach(Menu, id:\.self) {Menu in
                    NavigationLink (destination: SettingContents(menutitle: Menu.title, bleManager: bleManager)){
                        HStack {
                            Text(Menu.title)
                                .font(.title2)
                            Spacer() // 메뉴 타이틀 leading으로 정렬
                        }
                        .padding(10) // 메뉴 간의 간격
                    }
                }
                Spacer() // 메뉴 top으로 정렬
            }
        }
    }
}
