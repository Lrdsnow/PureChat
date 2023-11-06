//
//  ContentView.swift
//  PureChat
//
//  Created by Lrdsnow on 10/19/23.
//

import SwiftUI
import Combine
import SDWebImageSwiftUI
import UIKit

@main
struct PureChatApp: App {
    init(){
        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(Color.accentColor.opacity(0.7))
        UISegmentedControl.appearance().backgroundColor =  UIColor(Color.accentColor.opacity(0.2))
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
    }
    @State private var token_input = ""
    @State private var have_token = false
    
    var body: some Scene {
        WindowGroup {
            if have_token {
                MainView()
            } else {
                VStack {
                    TextField("Token", text: $token_input)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.7))
                                .shadow(radius: 10)
                        )
                        .foregroundColor(.white)
                    Button(action: {ksave(token_input.data(using: .utf8)!, service: "watchcord", account: "token"); have_token = true}, label: {Text("Submit")}).buttonStyle(.borderedProminent)
                }.onAppear() {
                    if kread(service: "watchcord", account: "token") != nil,
                       kread(service: "watchcord", account: "token") != Data() {
                        have_token = true
                    }
                }
            }
        }
    }
}

struct MainView: View {
    @State var dms: [DM] = []
    @State var guildfolders: [GuildFolder] = []
    @State var guilds: [Guild] = []

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Servers")) {
                    ForEach(guildfolders, id: \.id2) { folder in
                        if folder.guildIDs.count == 1 {
                            if let guild = guilds.first(where: { $0.id == folder.guildIDs[0] }) {
                                Button(action: {}, label: {
                                    HStack {
                                        WebImage(url: URL(string: guild.icon))
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxWidth: 40, maxHeight: 40)
                                            .cornerRadius(8)
                                        //Text(guild.name)
                                    }
                                })
                            }
                        } else {
                            DisclosureGroup {
                                ForEach(folder.guildIDs, id: \.self) { id in
                                    Button(action: {}, label: {
                                        HStack {
                                            WebImage(url: URL(string: guilds.first(where: { $0.id == id })!.icon))
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(maxWidth: 40, maxHeight: 40)
                                                .cornerRadius(8)
                                        }
                                    })
                                    .padding(.vertical, 10)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: 40, maxHeight: 40)
                                        .cornerRadius(8)
                                        .padding(.vertical, 10)
                                }
                            }.accentColor(.clear)
                        }
                    }
                }
                Section(header: Text("Direct Messages")) {
                    ForEach(dms, id: \.id) { dm in
                        DMItem(dm: dm)
                    }
                }
            }.frame(width: 100)
            .onAppear() {
                Discord.getDMs(completion: { dms in
                    self.dms = dms
                })
                Discord.getGuilds(completion: { guilds in
                    self.guilds = guilds
                    Discord.getFolders(completion: { folders in
                        self.guildfolders = folders
                    })
                })
            }
            .navigationTitle("WatchCordIOS")
            .navigationBarItems(trailing: NavigationLink(destination: {
                Section {
                    Button(action: {
                        ksave(Data(), service: "watchcord", account: "token")
                    }, label: {
                        Text("Clear Token")
                    }).buttonStyle(.borderedProminent)
                }
            }) {
                Image(systemName: "gearshape")
            })
        }
    }
}

struct DMItem: View {
    let dm: DM
    @State private var icon = ""
    @State private var name = ""
    var body: some View {
        NavigationLink(destination: MessageView(dm: dm, channel: nil), label: {
            HStack {
                AsyncImage(url: URL(string: icon)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 40, height: 40)
                    case .success(let image):
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 40, maxHeight: 40)
                            .cornerRadius(8)
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundColor(Color(UIColor(hex: "#787eff") ?? UIColor.white))
                            .frame(width: 40, height: 40)
                    @unknown default:
                        EmptyView()
                    }
                }
                VStack(alignment: .leading) {
                    Text(dm.owner_id != nil ? name : dm.recipients[0].global_name)
                    if (dm.owner_id != nil) {
                        Text("\(dm.recipients.count) Members")
                            .fontWeight(.ultraLight)
                            .font(.caption)
                    }
                }
            }.onAppear {
                if let dmname = dm.name {
                    name = dmname
                } else {
                    for recipient in dm.recipients {
                        name += recipient.username + " "
                    }
                }
                if ((dm.owner_id) != nil) {
                    guard let iconhash = dm.icon else {
                        icon = ""
                        return
                    }
                    icon = "https://cdn.discordapp.com/channel-icons/\(dm.id)/\(iconhash).png"
                } else {
                    icon = "https://cdn.discordapp.com/avatars/\(dm.recipients[0].id)/\(dm.recipients[0].avatar).png"
                }
            }
        })
    }
}

struct GuildView: View {
    var guild: Guild
    @State private var channels: [Channel] = []

    var body: some View {
        List {
            // Filter channels with type 4
            let sectionChannels = channels.filter { $0.type == 4 }

            ForEach(sectionChannels) { channel in
                Section(header: Text(channel.name)) {
                    ForEach(channels.filter { $0.parent == channel.id }) { childChannel in
                        NavigationLink {
                            MessageView(dm: nil, channel: childChannel)
                        } label: {
                            switch (channel.type) {
                            case 5:
                                Image(systemName: "book.closed.fill").foregroundColor(Color.accentColor)
                            case 4:
                                Image(systemName: "list.bullet").foregroundColor(Color.accentColor)
                            default:
                                Image(systemName: "number.square.fill").foregroundColor(Color.accentColor)
                            }
                            Text(childChannel.name)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(guild.name)
        .onAppear {
            Discord.getChannels(guild: self.guild) { channels in
                self.channels = channels
            }
        }
    }
}

struct MessageView: View {
    let dm: DM?
    let channel: Channel?
    @State var messages: [Message] = []
    @State var emojis: [String:[Emoji]] = [:]
    @State var message_text = ""
    @State private var cancellable: AnyCancellable?
    @State private var timer: Timer?
    @State private var popup = false
    @State private var selectedPopupSegment = 0
    @State private var showCamera = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage? = nil
    @State private var searchQuery = ""
    @FocusState private var msgFocused: Bool
    var body: some View {
        VStack {
            List(messages) { msg in
                MessageItem(message: msg).listRowSpacing(25)
            }.scaleEffect(x: 1, y: -1, anchor: .center).onAppear() {
                Discord.getMessages(dm?.id ?? channel?.id ?? "") { messages in
                    self.messages = messages
                }
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    Discord.getMessages(dm?.id ?? channel?.id ?? "") {
                        messages in
                        self.messages = messages
                    }
                    //print("fetched messages via timer")
                }
            }.onDisappear {
                self.cancellable?.cancel()
                timer?.invalidate()
            }.listRowSpacing(25)
            HStack {
                Button(action: {
                    popup.toggle()
                    msgFocused = false
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.7))
                                .shadow(radius: 10)
                        )
                }
                if selectedImage != nil {
                    Button(action: {
                        selectedImage = nil
                    }) {
                        Image(systemName: "photo")
                            .foregroundColor(.white)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.accentColor.opacity(0.7))
                                    .shadow(radius: 10)
                            )
                    }
                }
                TextField("Send Message...", text: $message_text)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.7))
                            .shadow(radius: 10)
                    )
                    .foregroundColor(.white)
                    .focused($msgFocused).onChange(of: msgFocused, perform: { newValue in
                        if newValue == true {
                            popup = false
                        }
                    })
                #if targetEnvironment(simulator)
                    .onSubmit() {
                        sendMessage()
                    }
                #endif
                Button(action: {
                    sendMessage()
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.white)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.7))
                                .shadow(radius: 10)
                        )
                }
            }.padding()
            if popup {
                Picker("", selection: $selectedPopupSegment) {
                    ForEach(0..<["Emojis", "Images"].count, id: \.self) { index in
                        Text(["Emojis", "Images"][index])
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if selectedPopupSegment == 0 {
                    TextField("Search Emojis", text: $searchQuery)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.7))
                                .shadow(radius: 10)
                                .padding(.horizontal, 10)
                        )
                        .foregroundColor(.white)
                    List {
                        ForEach(emojis.sorted(by: { $0.key < $1.key }), id: \.key) { sectionTitle, emoji in
                            let filteredEmoji = (searchQuery != "") ? (emoji.filter { $0.name.lowercased().contains(searchQuery.lowercased()) }) : emoji
                            
                            if !filteredEmoji.isEmpty {
                                Section(header: Text(sectionTitle)) {
                                    LazyVGrid(columns: Array(repeating: GridItem(), count: 8)) {
                                        ForEach(filteredEmoji, id: \.self) { emoji in
                                            Button(action: {
                                                message_text += "<:\(emoji.name):\(emoji.id)>"
                                            }, label: {
                                                WebImage(url: URL(string: "https://cdn.discordapp.com/emojis/\(emoji.id).png"))
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(height: 32)
                                                    .cornerRadius(8)
                                                    .padding(4)
                                            }).buttonStyle(.plain)
                                        }
                                    }.listRowBackground(Color.clear)
                                }
                            }
                        }
                    }.onAppear() {
                        Discord.getSortedEmojis(completion: { sortedEmojis in
                            self.emojis = sortedEmojis ?? [:]
                        })
                    }
                }
                
                if selectedPopupSegment == 1 {
                    HStack {
                        Spacer()
                        Button(action: {
                            showCamera = true
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Use Camera")
                            }
                                .foregroundColor(.white)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.accentColor.opacity(0.7))
                                        .shadow(radius: 10)
                                )
                        }.sheet(isPresented: $showCamera) {
                            ImagePicker(sourceType: .camera, selectedImage: $selectedImage, isPresented: $showCamera)
                        }
                        Spacer()
                        Button(action: {
                            showImagePicker = true
                        }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text("Pick Photo")
                            }
                                .foregroundColor(.white)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.accentColor.opacity(0.7))
                                        .shadow(radius: 10)
                                )
                        }.sheet(isPresented: $showImagePicker) {
                            ImagePicker(sourceType: .photoLibrary, selectedImage: $selectedImage, isPresented: $showImagePicker)
                        }
                        Spacer()
                    }
                }
            }
        }
    }
    
    func sendMessage() {
        if selectedImage != nil {
            Discord.sendMessage(message: processMessage(message_text), image: selectedImage!.jpegData(compressionQuality: 1.0), id: dm?.id ?? channel?.id ?? "")
        } else {
            Discord.sendMessage(message: processMessage(message_text), id: dm?.id ?? channel?.id ?? "")
        }
        message_text = ""
        selectedImage = nil
    }
    
    func processMessage(_ message: String) -> String {
        var temp_message = message

//        do {
//            let regex = try NSRegularExpression(pattern: ":[A-Za-z0-9]+:", options: [.caseInsensitive])
//            let range = NSRange(location: 0, length: message.utf16.count)
//            let matches = regex.matches(in: message, options: [], range: range)
//
//            let serialQueue = DispatchQueue(label: "com.example.serialQueue")
//
//            for match in matches.reversed() {
//                let range = Range(match.range, in: message)!
//                let capturedText = String(message[range])
//
//                serialQueue.sync {
//                    Discord.getAllEmojis { emojis in
//                        print(emojis)
//                        if let matchingEmoji = emojis?.first(where: { emoji in
//                            return ":"+emoji.name+":" == capturedText
//                        }) {
//                            let replacementText = "<\(capturedText)\(matchingEmoji.id)>"
//                            temp_message = temp_message.replacingOccurrences(of: capturedText, with: replacementText)
//                        } else {
//                            print("Not a valid emoji")
//                        }
//                    }
//                }
//            }
//        } catch {
//            print("Error in regular expression: \(error)")
//            return message
//        }

        return temp_message
    }
}

struct KeyboardAdaptive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .edgesIgnoringSafeArea(keyboardHeight > 0 ? .bottom : [])
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                if let keyboardRect = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    keyboardHeight = keyboardRect.height
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
            }
    }
}

extension View {
    func keyboardAdaptive() -> some View {
        modifier(KeyboardAdaptive())
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}
