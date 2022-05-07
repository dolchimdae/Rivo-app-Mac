//
//
//  Setting Contents.swift
//  Rivo
//

import WebKit
import SwiftUI

struct SettingContents: View {
    
    
    var menutitle: String
    @ObservedObject var bleManager : CBController
    
    var body: some View {
        switch menutitle {
        case "설정" :
            Set(bleManager: bleManager)
        case "업데이트":
            Update(bleManager: bleManager)
        case "My리보":
            MyRivo(bleManager: bleManager)
        case "도움말":
            Help(bleManager: bleManager)
        default:
            Set(bleManager: bleManager)
        }
    }
}

struct Set: View {
    
    // 날짜/시간 동기화 설정 저장용
    @AppStorage("dateAndTimeSyn") var isSync : Bool = UserDefaults.standard.bool(forKey: "dateAndTimeSyn")
    @ObservedObject var bleManager : CBController
    
    @State private var showingAlert = false
    
    @State var selectedfunc = 0
    @State var selectedL3L = 0
    @State var selectedL3I = 0
    @State var selectedL4L = 0
    @State var selectedL4I = 0
    
    let functions = ["iOS VoiceOver", "Android TalkBack", "WatchOS"]
    
    let L3 = ["영어"] //20
    let inputL3 = ["EWQ", "ABC"] //21, 22
    let L4 = ["한글", "숫자"] //30, 10
    let inputL4K = [" "]
    let inputL4N = ["리보", "나랏글", "천지인"] //31, 32, 33
    
    
    var body: some View {
        ScrollView {
            HStack{
                Text("설정")
                    .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
                    .padding(10)
                    .frame(width: 555 , height: 25, alignment: .leading)
            }
            .padding(10)
            Divider()
                .padding(-10)
            VStack(spacing: 15) {
                Group {
                    HStack {
                        Text("날짜/시간")
                            .font(.title2.bold())
                            .padding(15)
                        Spacer()
                    }
                    HStack {
                        Text("날짜/시간 동기화")
                            .padding(15)
                        Spacer()
                        SwiftUI.Toggle("", isOn: $isSync)
                            .toggleStyle(SwitchToggleStyle(tint: Color.blue))
                            .padding(15)
                            .onChange(of: isSync) { _ in
                                if(isSync){
                                    if (bleManager.isConnected) {
                                        Task{
                                            do{
                                                try await bleManager.device.setDateAndTime(type: 0, nowDate: Date())
                                            }
                                            catch{
                                                showingAlert = true
                                                print(error)
                                            }
                                        }
                                    }
                                }
                            }
                    }
                } //Group
                Divider()
                
                Group {
                    HStack {
                        Text("언어/입력")
                            .font(.title2.bold())
                            .padding(15)
                        Spacer()
                        Button(action: {
                            Task{
                                do{
                                    try await bleManager.device.setLanguage(language1: selectedL3L, input_method1: selectedL3I, language2: selectedL4L, input_method2: selectedL4I)
                                }catch{
                                    showingAlert = true
                                    print(error)
                                }
                            }
                        }) {
                            Text("저장")
                        }
                        .disabled(!bleManager.isConnected)
                        .padding(15)
                    }
                    HStack {
                        Picker (selection: $selectedL3L,label: Text("L3")){
                            ForEach(0 ..< L3.count) {
                                Text(self.L3[$0])
                            }
                        }
                        
                        Picker (selection: $selectedL3I,label: Text("입력방식")){
                            ForEach(0 ..< inputL3.count) {
                                Text(self.inputL3[$0])
                            }
                        }
                    }
                    HStack {
                        Picker (selection: $selectedL4L,label: Text("L4")){
                            ForEach(0 ..< L4.count) {
                                Text(self.L4[$0])
                            }
                        }
                        Picker (selection: $selectedL4I,label: Text("입력방식")){
                            if(selectedL4L == 0){
                                ForEach(0 ..< inputL4N.count) {
                                    Text(self.inputL4N[$0])
                                }
                            }
                            else{
                                ForEach(0 ..< inputL4K.count) {
                                    Text(self.inputL4K[$0])
                                }
                            }
                        }
                    }
                } // group
                Divider()
                
                Group {
                    HStack{
                        Text("OS/스크린리더")
                            .font(.title2.bold())
                            .padding(15)
                        Spacer()
                        Button(action:{
                            Task{
                                do{
                                    try await bleManager.device.setScreenReader(OS: selectedfunc)
                                }
                                catch{
                                    showingAlert = true
                                    print(error)
                                }
                            }
                        }){
                            Text("저장")
                        }
                        .disabled(!bleManager.isConnected)
                        .padding(15)
                    }
                    //Picker
                    Picker (selection: $selectedfunc,label: Text("")){
                        ForEach(0 ..< functions.count) {
                            Text(self.functions[$0])
                        }
                    }
                    .pickerStyle(InlinePickerStyle())
                }
                Spacer()
            } //VStack
            .alert("에러", isPresented: $showingAlert) {
                Button("예") {}
            } message: {
                Text("다시 시도하세요.")
            }
        }//ScrollView
        .task {
            // view 선택 시 task. 기기에서 정보 가져와 반영
            if(bleManager.isConnected){
                do{
                    if(isSync){
                        try await bleManager.device.setDateAndTime(type: 0, nowDate: Date())
                    }
                    let screenReaders = try await bleManager.device.getScreenReader()?.split(separator: ",")
                    let languages = try await bleManager.device.getLanguage()?.split(separator: ",")
                    
                    switch screenReaders![1] {
                    case "11":
                        selectedfunc = 0
                        break
                    case "21":
                        selectedfunc = 1
                        break
                    case "12":
                        selectedfunc = 2
                        break
                    default:
                        print("break")
                        break
                    }
                    
                    switch languages![1] {
                    case "21":
                        selectedL3I = 0
                        break
                    case "22":
                        selectedL3I = 1
                        break
                    default:
                        print("break")
                        break
                    }
                    
                    switch languages![2] {
                    case "30": //한글
                        selectedL4L = 0
                        break
                    case "10": //숫자
                        selectedL4L = 1
                        break
                    default:
                        print("break")
                        break
                    }
                    
                    if(languages![2] != "10"){
                        switch languages![3]{
                        case "31": //리보
                            selectedL4I = 0
                            break
                        case "32": //나랏글
                            selectedL4I = 1
                            break
                        case "33": //천지인
                            selectedL4I = 2
                            break
                        default:
                            print("break")
                            break
                        }
                    }
                }
                catch{
                    showingAlert = true
                    print(error)
                }
            }
        }
        .disabled(!bleManager.isConnected)
    }//Body
}


struct Update: View {
    
    @ObservedObject var bleManager : CBController
    
    @State private var showingAlert = false
    @State var updateBtn : Bool = false
    
    var body: some View{
        ScrollView {
            HStack{
                Text("업데이트")
                    .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
                    .padding(5)
                    .frame(width: 555 , height: 25, alignment: .leading)
            }
            .padding(10)
            Divider()
                .padding(-10)
            VStack(spacing: 15){
                Text("\(bleManager.peripheralVersion)")
                    .font(.title3)
                    .kerning(2)
                    .padding(10)
                
                Spacer()
                Button (action: {
                    Task{
                        do{
                            if let url = URL(string: "https://rivo.me/app/version.app") {
                                let content = try String(contentsOf: url)
                                bleManager.recentVersion = "최신 버전\n\(content)"
                                bleManager.peripheralVersion = try await bleManager.device.getFirmwareVersion()!
                                
                                if bleManager.peripheralVersion != content {
                                    updateBtn = true
                                }
                            }
                        }
                        catch{
                            showingAlert = true
                            print(error)
                        }
                    }
                }) {
                    Text("버전 확인")
                        .foregroundColor(.blue)
                }
                .disabled(!bleManager.isConnected)
                
                Text(bleManager.recentVersion)
                    .font(.title3)
                    .kerning(2)
                Text("\(bleManager.upgradeStatus)")
                    .font(.title)
                    .kerning(2)
                    .padding(5)
                    
                Button(action:{
                    Task{
                        do{
                            if let url = URL(string: "https://rivo.me/app/version.app") {
                                let content = try String(contentsOf: url)
                                let contents = content.split(separator: ",")
                                
                                let versions = bleManager.peripheralVersion.split(separator: ",")
                                
                                //for i in 0...2 {
                                if(contents[1] != versions[1]){
                                    try await bleManager.device.update(index: 1)
                                    //}
                                }
                            }
                        }
                        catch{
                            showingAlert = true
                            print(error)
                        }
                    }
                }){
                    Text("업데이트")
                }
                .padding(10)
                .disabled(!updateBtn)
            }
            .alert("에러", isPresented: $showingAlert) {
                Button("예") {}
            } message: {
                Text("다시 시도하세요.")
            }
            .disabled(!bleManager.isConnected)
        }//body
    }
}

struct MyRivo: View {
    
    @ObservedObject var bleManager : CBController
    
    @State private var showingAlert = false
    @State var rivoName: String = ""
    @State private var Toggle_vibration = false
    @State private var Toggle_sound = false
    
    var body: some View{
        ScrollView {
            HStack{
                Text("My리보")
                    .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
                    .padding(10)
                    .frame(width: 555 , height: 25, alignment: .leading)
            }
            .padding(10)
            Divider()
                .padding(-10)
            VStack(spacing: 15){
                Group {
                    HStack{
                        Text("리보3 등록")
                            .font(.title2.bold())
                            .padding(15)
                        Spacer()
                        Button (action: {
                            self.bleManager.startScanning()
                        }) {
                            Text("검색")
                                .foregroundColor(.black)
                        }
                        .padding(15)
                    }
                    List(bleManager.peripherals) { peripheral in
                        VStack {
                            HStack {
                                Text(peripheral.name)
                                Spacer()
                                Text(String(peripheral.rssi))
                                Button (action: {
                                    print("select \(peripheral)")
                                    Task {
                                        await bleManager.connect(peripheral)
                                    }
                                }) {
                                    Text("등록")
                                        .foregroundColor(.blue)
                                }
                            }
                            Divider()
                        }
                    }
                    .frame(width: 500, height: 200)
                }
                Divider()
                Group {
                    HStack{
                        Text("장치 정보")
                            .font(.title2.bold())
                            .padding(15)
                        Spacer()
                        Button (action: {
                            Task{
                                do{
                                    let temp = try await bleManager.device.getDeviceInfo()!
                                    let infos = temp.split(separator: ",")
                                    bleManager.deviceInfo = "\(String(infos[0]))\n\(String(infos[1]))\n\(String(infos[2]))"
                                    
                                    let temps = try await bleManager.device.getRivoStatus()?.split(separator: ",")
                                    bleManager.battery = String(temps![0])
                                }
                                catch{
                                    showingAlert = true
                                    print(error)
                                }
                            }
                        }) {
                            Text("Refresh")
                                .foregroundColor(.black)
                        }
                        .disabled(!bleManager.isConnected)
                        .padding(15)
                    }
                    if(bleManager.isConnected){
                        
                        Text(bleManager.deviceInfo)
                            .kerning(1)
                        Spacer()
                    }
                }
                Divider()
                
                Group {
                    HStack{
                        Text("이름 변경")
                            .font(.title2.bold())
                            .padding(15)
                        Spacer()
                    }
                    TextField("Enter device Name", text: $rivoName)
                        .frame(width: 300, height: 80, alignment: .center)
                    HStack{
                        Button{
                            Task {
                                do{
                                    if(bleManager.isConnected){
                                        try await bleManager.device.setRivoName(name: rivoName)
                                        bleManager.peripheralName = rivoName
                                        //장치정보 갱신
                                        let temp = try await bleManager.device.getDeviceInfo()!
                                        let infos = temp.split(separator: ",")
                                        bleManager.deviceInfo = "\(String(infos[0]))\n\(String(infos[1]))\n\(String(infos[2]))"
                                    }
                                }
                                catch{
                                    showingAlert = true
                                    print(error)
                                }
                            }
                        } label :
                        {
                            Text("저장")
                                .foregroundColor(.blue)
                        }
                        .disabled(!bleManager.isConnected)
                        Button (action: {
                            Task{
                                do{
                                    try await bleManager.device.deleteRivoName()
                                    //장치정보 갱신
                                    let temp = try await bleManager.device.getDeviceInfo()!
                                    let infos = temp.split(separator: ",")
                                    bleManager.deviceInfo = "\(String(infos[0]))\n\(String(infos[1]))\n\(String(infos[2]))"
                                }
                                catch{
                                    showingAlert = true
                                    print(error)
                                }
                            }
                        })
                        {
                            Text("이름 초기화")
                                .foregroundColor(.black)
                        }
                        .disabled(!bleManager.isConnected)
                    }
                }
                Divider()
                Group{
                    HStack{
                        Text("내 리보 찾기")
                            .font(.title2.bold())
                            .padding(15)
                        Spacer()
                        Button(action:{
                            
                            Task{
                                do{
                                    if(Toggle_vibration){
                                        if(Toggle_sound){
                                            try await bleManager.device.findMyRivo(action: 3)
                                        }
                                        else{
                                            try await bleManager.device.findMyRivo(action: 1)
                                        }
                                    }else{
                                        try await bleManager.device.findMyRivo(action: 2)
                                    }
                                }
                                catch{
                                    showingAlert = true
                                    print(error)
                                }
                            }
                        }){
                            Text("찾기")
                        }
                        .disabled(!bleManager.isConnected || (!Toggle_sound && !Toggle_vibration))
                        .padding(15)
                    }
                    HStack{
                        Text("진동")
                        SwiftUI.Toggle("", isOn: $Toggle_vibration)
                            .toggleStyle(SwitchToggleStyle(tint: Color.green))
                    }
                    HStack{
                        Text("소리")
                        SwiftUI.Toggle("", isOn: $Toggle_sound)
                            .toggleStyle(SwitchToggleStyle(tint: Color.green))
                    }
                    Spacer()
                }
                Spacer()
            }//Vstack
            .alert("에러", isPresented: $showingAlert) {
                Button("예") {}
            } message: {
                Text("다시 시도하세요.")
            }
        }//ScrollView
    }//Body
}

/* 도움말 */
struct WebView: NSViewRepresentable {
    let url: URL
    func makeNSView(context: NSViewRepresentableContext<WebView>) -> WKWebView { let webView: WKWebView = WKWebView()
        let request = URLRequest(url: self.url)
        webView.customUserAgent = "Safari/605"
        webView.load(request)
        return webView
    }
    func updateNSView(_ webView: WKWebView, context: NSViewRepresentableContext<WebView>) {}
}

struct Help: View {
    @ObservedObject var bleManager : CBController
    let url : String = "https://rivo.me/ko/quickmanual"
    var body: some View{
        GeometryReader { g in
            ScrollView {
                HStack{
                    Text("도움말")
                        .font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
                        .padding(10)
                        .frame(width: 555 , height: 25, alignment: .leading)
                }
                .padding(10)
                Divider()
                    .padding(-10)
                WebView(url: URL(string: url)!)
                    .frame(height: g.size.height)
                Spacer()
            } //Scroll
            .frame(height: g.size.height)
        } //Geometry
    } //Body
}


