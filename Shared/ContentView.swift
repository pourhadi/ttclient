//
//  ContentView.swift
//  socketclient
//
//  Created by Daniel Pourhadi on 2/15/21.
//

import SwiftUI
import Starscream

class PriceDetails: Identifiable {
    
    var id: Int { return self.price }
    
    internal init(price: Int, bidQuantity: Float = 0, askQuantity: Float = 0) {
        self.price = price
        self.bidQuantity = bidQuantity
        self.askQuantity = askQuantity
    }
    
    let price: Int
    var bidQuantity: Float
    var askQuantity: Float
    var isLastTrade = false
    
    func bidQuantityString() -> String {
        return bidQuantity > 0 ? "\(Int(bidQuantity))" : ""
    }
    
    func askQuantityString() -> String {
        return askQuantity > 0 ? "\(Int(askQuantity))" : ""
    }
    
    var bidExists: Bool {
        return bidQuantity > 0
    }
    
    var askExists: Bool {
        return askQuantity > 0
    }
}

extension Array where Element == PriceDetails {
    
    mutating func forPrice(_ price: Int) -> PriceDetails {
        if let details = self.first(where: { $0.price == price }) {
            return details
        }
        
        return PriceDetails(price: 0)
    }
}

class SocketClient: ObservableObject {
    let socket: WebSocket
    var isConnected = false
    
    @Published var prices = [PriceDetails]()
    @Published var lastTradedPrice = 0
    
    var levels = DepthLevels(Levels: [:], Command: nil, LastTradedPrice: 0, LastTradedQuantity: 0) {
        didSet {
            let price = levels.LastTradedPrice
            if price != self.lastTradedPrice {
                self.lastTradedPrice = price
            }
            var depthPrices = [PriceDetails]()
            
            for x in price-100..<price+100 {
                depthPrices.append(PriceDetails(price: x))
            }
            
            for (_, val) in levels.Levels {
                if val.BestAsk > 0 {
                    depthPrices.forPrice(val.BestAsk).askQuantity = val.AskQuantity
                }
                
                if val.BestBid > 0 {
                    depthPrices.forPrice(val.BestBid).bidQuantity = val.BidQuantity
                }
            }
            
            depthPrices.forPrice(levels.LastTradedPrice).isLastTrade = true
            self.prices = depthPrices.reversed()
        }
    }
    
    init() {
        var request = URLRequest(url: URL(string: "https://depth-ws-jpjpjr6wka-uc.a.run.app/ws")!)
//        var request = URLRequest(url: URL(string: "http://0.0.0.0:4649/ws")!)

        request.timeoutInterval = 5
        socket = WebSocket(request: request)
        
        socket.onEvent = { [unowned self] event in
            switch event {
                case .connected(let headers):
                    self.isConnected = true
                    self.socket.write(string: "hi")
                    print("websocket is connected: \(headers)")
                case .disconnected(let reason, let code):
                    self.isConnected = false
                    print("websocket is disconnected: \(reason) with code: \(code)")
                case .text(let string):
//                    print("Received text: \(string)")
                    
                    if let data = string.data(using: .utf8), let json = try? JSONDecoder().decode(DepthLevels.self, from: data) {
                        DispatchQueue.main.async {
                            self.levels = json
                        }
                      //  print(json)
                    }
                    self.socket.write(string: "hi")

                case .binary(let data):
                    print("Received data: \(data.count)")
                    self.socket.write(string: "hi")

                case .ping(_):
                    break
                case .pong(_):
                    break
                case .viabilityChanged(_):
                    break
                case .reconnectSuggested(_):
                    break
                case .cancelled:
                    self.isConnected = false
                case .error(let error):
                    print(error)
                    self.isConnected = false
                }
        }
        socket.connect()
    }
    
}

struct DepthLevels: Codable {
    let Levels: [Int: DepthLevel]
    let Command: String?
    let LastTradedPrice: Int
    let LastTradedQuantity: Float
}

struct DepthLevel: Codable {
    let BestBid: Int
    let BidQuantity: Float
    let BestAsk: Int
    let AskQuantity: Float
}

extension Int: Identifiable {
    public var id: Int {
        return self
    }
}

struct ContentView: View {
    
    @StateObject var client = SocketClient()
    var body: some View {
        GeometryReader { metrics in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack {
                        ForEach(client.prices) { x in
                            HStack {
                                Text(x.bidQuantityString())
                                    .frame(width: metrics.size.width / 3)
                                    .background(x.bidExists ? Color.blue.opacity(0.5) : Color.clear)
                                Text("\(x.price)".replacingOccurrences(of: ",", with: ""))
                                    .frame(width: metrics.size.width / 3)
                                    .background(x.isLastTrade ? Color.gray : Color.clear)
                                Text(x.askQuantityString())
                                    .frame(width: metrics.size.width / 3)
                                    .background(x.askExists ? Color.red.opacity(0.5) : Color.clear)
                                
                                
                            }
                            .id(x.isLastTrade ? "lastTradedPrice" : "others")
                            
                        }
                        
                    }.onChange(of: client.lastTradedPrice, perform: { value in
                        withAnimation(Animation.linear(duration: 5)) {
                            proxy.scrollTo("lastTradedPrice", anchor: .center)
                        }
                    })
                }
                .frame(height: metrics.size.height)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
