//
//  extras.swift
//  PureChat
//
//  Created by Lrdsnow on 10/19/23.
//
import SwiftUI
import WatchConnectivity
import SDWebImageSwiftUI
import Combine

struct MessageItem: View {
    var message: Message
    @State private var time: String = ""
    @State private var image: UIImage? = nil // watchOS 7
    @State private var isLoading = false // watchOS 7
    
    var body: some View {
        Section(header: EmptyView()) {
            HStack(alignment: .top) {
                VStack(alignment: .center) {
                    HStack(alignment: .center) {
                        WebImage(url: URL(string:"https://cdn.discordapp.com/avatars/\(message.author.id)/\(message.author.avatar).png"))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 36, height: 36)
                            .cornerRadius(4)
                            .padding(.vertical, 3)
                    }
                }
                VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        Text("\(message.author.global_name)")
                            .font(.system(size:12))
                            .fontWeight(.bold)
                            .truncationMode(.tail)
                            .padding(.leading, 1)
                        Text(formattedDate())
                            .font(.system(size:12))
                            .fontWeight(.thin)
                    }.padding(.vertical)
                    .frame(height: 12)
                    MessageContentView(content: message.content)
                    if !message.attachments.isEmpty { MessageAttachmentsView(attachments: message.attachments) }
                }
            }
            .scaleEffect(x: 1, y: -1, anchor: .center)
        }
    }
    
    func extractHexColor(_ input: String) -> String? {
        print(input)
        let regex = try! NSRegularExpression(pattern: "<c#([0-9a-fA-F]{6})>")
        if let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {
            let range = Range(match.range(at: 1), in: input)!
            print(String(input[range]))
            return String(input[range])
        }
        return nil
    }
    
    func formattedDate() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "hh:mm a"
        dateFormatter.timeZone = TimeZone.current
        let calendar = Calendar.current
        let localTimeZone = TimeZone.current
        let timeDifference = TimeInterval(localTimeZone.secondsFromGMT(for: message.timestamp))
        let localMessageTimestamp = message.timestamp.addingTimeInterval(timeDifference)
        if calendar.isDateInToday(localMessageTimestamp) {
            // Display time for today
            return dateFormatter.string(from: localMessageTimestamp)
        } else if calendar.isDateInYesterday(localMessageTimestamp) {
            // Display "Yesterday"
            dateFormatter.dateFormat = "hh:mm a"
            return "Yesterday, \(dateFormatter.string(from: localMessageTimestamp))"
        } else {
            // Display full date for other days
            dateFormatter.dateFormat = "yyyy-MM-dd hh:mm a"
            return dateFormatter.string(from: localMessageTimestamp)
        }
    }
}

struct MessageContentView: View {
    let content: String
    var body: some View {
        let emojiPattern = "(<:.*?:\\d+>)|(<.*?:.*?:\\d+>)"
        let pingPattern = "<@(\\d+)>"
        let colorPattern = "<c#([0-9a-fA-F]{6})>"
        let urlPattern = "https?://\\S+"
        let combinedPattern = "\(emojiPattern)|(\(urlPattern))|(\(pingPattern))|(@(?![C|c]lyde)\\w+)|(\(colorPattern))"

        let emojiRegex = try! NSRegularExpression(pattern: emojiPattern, options: [])
        let pingRegex = try! NSRegularExpression(pattern: pingPattern, options: [])
        let colorRegex = try! NSRegularExpression(pattern: colorPattern, options: [])
        let urlRegex = try! NSRegularExpression(pattern: urlPattern, options: [])
        
        let combinedRegex = try! NSRegularExpression(pattern: combinedPattern, options: [])
        let matches = combinedRegex.matches(in: content, options: [], range: NSRange(content.startIndex..<content.endIndex, in: content))

        var components: [String] = []

        var currentIndex = content.startIndex

        for match in matches {
            let matchRange = Range(match.range, in: content)!
            if currentIndex < matchRange.lowerBound {
                let textBeforeMatch = content[currentIndex..<matchRange.lowerBound]
                components.append(String(textBeforeMatch))
            }
            components.append(String(content[matchRange]))
            currentIndex = matchRange.upperBound
        }

        if currentIndex < content.endIndex {
            let textAfterMatches = content[currentIndex..<content.endIndex]
            components.append(String(textAfterMatches))
        }
        
        if #available(iOS 16.0, *) {
            return WrappingHStack(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                ForEach(components, id: \.self) { component in
                    if emojiRegex.firstMatch(in: String(component), options: [], range: NSRange(component.startIndex..<component.endIndex, in: component)) != nil {
                        let emoji = component.replacingOccurrences(of: "<", with: "").replacingOccurrences(of: ">", with: "").components(separatedBy: ":")
                        let emojiName = emoji[1]
                        let emojiID = emoji[2]
                        if emojiID != "",
                           let imageURL = URL(string: "https://cdn.discordapp.com/emojis/\(emojiID).png") {
                            WebImage(url: imageURL)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: components.count == 1 ? 24 : 12, height: components.count == 1 ? 24 : 12)
                                .accessibility(label: Text(emojiName))
                        }
                    } else if urlRegex.firstMatch(in: String(component), options: [], range: NSRange(component.startIndex..<component.endIndex, in: component)) != nil {
                        if isValidImage(content) {
                            WebImage(url: URL(string: content))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: components.count == 1 ? 24 : 12, height: components.count == 1 ? 24 : 12)
                        } else {
                            Text(LocalizedStringKey(stringLiteral: String(component)))
                                .font(.system(size: 12))
                        }
                    } else if pingRegex.firstMatch(in: String(component), options: [], range: NSRange(component.startIndex..<component.endIndex, in: component)) != nil {
                        PingView(id: component.replacingOccurrences(of: "<@", with: "").replacingOccurrences(of: ">", with: ""))
                    } else if content.lowercased() == "@clyde" {
                        PingView(id: "", username: "Clyde", color: "#15c243")
                    } else if colorRegex.firstMatch(in: String(component), options: [], range: NSRange(component.startIndex..<component.endIndex, in: component)) != nil {
                        EmptyView()
                    } else {
                        Text(LocalizedStringKey(stringLiteral: String(component)))
                            .font(.system(size: 12))
                    }
                }
            }
        } else {
            return HStack(spacing: 0) {
                ForEach(components, id: \.self) { component in
                    if emojiRegex.firstMatch(in: String(component), options: [], range: NSRange(component.startIndex..<component.endIndex, in: component)) != nil {
                        let emoji = component.replacingOccurrences(of: "<", with: "").replacingOccurrences(of: ">", with: "").components(separatedBy: ":")
                        let emojiName = emoji[1]
                        let emojiID = emoji[2]
                        if emojiID != "",
                           let imageURL = URL(string: "https://cdn.discordapp.com/emojis/\(emojiID).png") {
                            WebImage(url: imageURL)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: components.count == 1 ? 24 : 12, height: components.count == 1 ? 24 : 12)
                                .accessibility(label: Text(emojiName))
                        }
                    } else if urlRegex.firstMatch(in: String(component), options: [], range: NSRange(component.startIndex..<component.endIndex, in: component)) != nil {
                        if isValidImage(content) {
                            if let imageURL = URL(string: content) {
                                WebImage(url: imageURL)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: components.count == 1 ? 24 : 12, height: components.count == 1 ? 24 : 12)
                            }
                        } else {
                            Text(LocalizedStringKey(stringLiteral: String(component)))
                                .font(.system(size: 12))
                        }
                    } else if pingRegex.firstMatch(in: String(component), options: [], range: NSRange(component.startIndex..<component.endIndex, in: component)) != nil {
                        PingView(id: component.replacingOccurrences(of: "<@", with: "").replacingOccurrences(of: ">", with: ""))
                    } else if content.lowercased() == "@clyde" {
                        PingView(id: "", username: "Clyde", color: "#15c243")
                    } else {
                        Text(LocalizedStringKey(stringLiteral: String(component)))
                            .font(.system(size: 12))
                    }
                }
            }
        }
    }
}

struct PingView: View {
    let id: String
    @State var username = "pingy"
    @State var color = "#787eff"

    var body: some View {
        Button(action: {}) {
            ZStack {
                Text("@\(username)")
                    .font(.system(size: 12))
                    .padding(.horizontal, 3)
                    .padding(.vertical, 10)
            }
            .frame(height: 14)
            .background(
                Rectangle()
                    .foregroundColor(Color(UIColor(hex: color) ?? UIColor.white).opacity(0.3))
                    .cornerRadius(3)
            )
        }
        .onAppear() {
            if id != "" {
                Discord.getUser(userId: id) { user in
                    DispatchQueue.main.async {
                        if user.global_name != "" {
                            self.username = user.global_name
                        } else {
                            self.username = user.username
                        }
                    }
                }
            }
        }
    }
}

struct MessageAttachmentsView: View {
    let attachments: [Attachment]
    
    var body: some View {
        HStack {
            ForEach(attachments, id: \.id) { attachment in
                if let imageUrl = URL(string: attachment.url) {
                    WebImage(url: imageUrl)
                        .resizable()
                        .scaledToFill()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(Rectangle())
                        .padding()
                        .cornerRadius(5)
                }
            }
        }
    }
}

func isValidImage(_ url: String) -> Bool {
    print("imageurl: '\(url)'")
    if let url = URL(string: url) {
        let request = URLRequest(url: url)
        var result = false
        
        let semaphore = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let data = data, let response = response as? HTTPURLResponse {
                if response.statusCode == 200 {
                    if let contentType = response.allHeaderFields["Content-Type"] as? String {
                        if contentType.hasPrefix("image") {
                            result = true
                        }
                    }
                }
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .distantFuture)
        return result
    }
    
    return false
}

struct MessageItem_Previews: PreviewProvider {
    static var previews: some View {
        MessageItem(message: Message(
            id: "1136144263479054526",
            type: 0,
            content: "hi guys",
            channel_id: "775347652224352258",
            timestamp: DefaultMessage.dateFormatter.date(from: "2023-08-03T03:35:30.187000+00:00")!,
            author: User(
                id: "305243321784336384",
                username: "circular",
                global_name: "the circlest of them all",
                avatar: "fc0914ced252a9754e6ffd3c64823b9b",
                bio: "",
                banner: "",
                banner_color: "",
                accent_color: "",
                discriminator: "0000"
            ),
            attachments: []
        ))
        .scaleEffect(x: 1, y: -1, anchor: .center) // revert the scale effect only for previews, the scale is reverted again in the actual file
    }
}

