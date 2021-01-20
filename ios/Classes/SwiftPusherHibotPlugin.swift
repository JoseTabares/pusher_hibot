import Flutter
import UIKit
import PusherSwift


public class SwiftPusherHibotPlugin: NSObject, FlutterPlugin, PusherDelegate {
    
    public static var eventSink: FlutterEventSink?
    public static var isLoggingEnabled: Bool = false;
    public static var bindedEvents = [String:String]()
    public static var channels = [String:PusherChannel]()
    public static var pusher: Pusher?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "pusher_hibot", binaryMessenger: registrar.messenger())
        let channelPusher = FlutterMethodChannel(name: "pusher", binaryMessenger: registrar.messenger())
        let instance = SwiftPusherHibotPlugin()
        let eventChannel = FlutterEventChannel(name: "pusherStream", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channelPusher)
        eventChannel.setStreamHandler(StreamHandler())
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "init":
            setup(call, result: result)
        case "connect":
            connect(call, result: result)
        case "disconnect":
            disconnect(call, result: result)
        case "subscribe":
            subscribe(call, result: result)
        case "unsubscribe":
            unsubscribe(call, result: result)
        case "bind":
            bind(call, result: result)
        case "unbind":
            unbind(call, result: result)
        case "getSocketId":
            getSocketId(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func setup(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let pusherObj = SwiftPusherHibotPlugin.pusher {
            pusherObj.unbindAll();
            pusherObj.unsubscribeAll()
        }
        
        for (_, pusherChannel) in SwiftPusherHibotPlugin.channels {
            pusherChannel.unbindAll()
        }
        
        SwiftPusherHibotPlugin.channels.removeAll();
        SwiftPusherHibotPlugin.bindedEvents.removeAll()
        
        do {
            let json = call.arguments as! String
            let jsonDecoder = JSONDecoder()
            let initArgs = try jsonDecoder.decode(InitArgs.self, from: json.data(using: .utf8)!)
            
            
            SwiftPusherHibotPlugin.isLoggingEnabled = initArgs.isLoggingEnabled
            
            let options = PusherClientOptions(
                authMethod: initArgs.options.auth != nil ? AuthMethod.authRequestBuilder(authRequestBuilder: AuthRequestBuilder(endpoint: initArgs.options.auth!.endpoint, headers: initArgs.options.auth!.headers)): .noMethod,
                host: initArgs.options.host != nil ? .host(initArgs.options.host!) : (initArgs.options.cluster != nil ? .cluster(initArgs.options.cluster!) : .host("ws.pusherapp.com")),
                port: initArgs.options.port ?? (initArgs.options.encrypted ?? true ? 443 : 80),
                useTLS: initArgs.options.encrypted ?? true,
                activityTimeout: Double(initArgs.options.activityTimeout ?? 30000) / 1000
            )
            
            SwiftPusherHibotPlugin.pusher = Pusher(
                key: initArgs.appKey,
                options: options
            )
            SwiftPusherHibotPlugin.pusher!.connection.delegate = self
            
            if (SwiftPusherHibotPlugin.isLoggingEnabled) {
                print("Pusher init")
            }
        } catch {
            if (SwiftPusherHibotPlugin.isLoggingEnabled) {
                print("Pusher init error:" + error.localizedDescription)
            }
        }
        result(nil);
    }
    
    public func connect(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let pusherObj = SwiftPusherHibotPlugin.pusher {
            pusherObj.connect();
            if (SwiftPusherHibotPlugin.isLoggingEnabled) {
                print("Pusher connect")
            }
        }
        result(nil);
    }
    
    public func disconnect(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let pusherObj = SwiftPusherHibotPlugin.pusher {
            pusherObj.disconnect();
            if (SwiftPusherHibotPlugin.isLoggingEnabled) {
                print("Pusher disconnect")
            }
        }
        result(nil);
    }
    
    public func subscribe(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let pusherObj = SwiftPusherHibotPlugin.pusher {
            let channelName = call.arguments as! String
            let channelType = channelName.components(separatedBy: "-")[0]
            var channel: PusherChannel
            
            switch channelType{
            case "private":
                channel = pusherObj.subscribe(channelName)
                if (SwiftPusherHibotPlugin.isLoggingEnabled) {
                    print("Pusher subscribe (private)")
                }
            case "presence":
                channel = pusherObj.subscribeToPresenceChannel(channelName: channelName)
                if (SwiftPusherHibotPlugin.isLoggingEnabled) {
                    print("Pusher subscribe (presence)")
                }
            default:
                channel = pusherObj.subscribe(channelName)
                if (SwiftPusherHibotPlugin.isLoggingEnabled) {
                    print("Pusher subscribe")
                }
            }
            
            SwiftPusherHibotPlugin.channels[channelName] = channel;
        }
        result(nil);
    }
    
    public func unsubscribe(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let pusherObj = SwiftPusherHibotPlugin.pusher {
            let channelName = call.arguments as! String
            pusherObj.unsubscribe(channelName)
            SwiftPusherHibotPlugin.channels.removeValue(forKey: "channelName")
            
            if (SwiftPusherHibotPlugin.isLoggingEnabled) {
                print("Pusher unsubscribe")
            }
        }
        result(nil);
    }
    
    public func bind(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        do {
            let json = call.arguments as! String
            let jsonDecoder = JSONDecoder()
            let bindArgs = try jsonDecoder.decode(BindArgs.self, from: json.data(using: .utf8)!)
            
            let channel = SwiftPusherHibotPlugin.channels[bindArgs.channelName]
            if let channelObj = channel {
                unbindIfBound(channelName: bindArgs.channelName, eventName: bindArgs.eventName)
                SwiftPusherHibotPlugin.bindedEvents[bindArgs.channelName + bindArgs.eventName] = channelObj.bind(eventName: bindArgs.eventName, eventCallback: { (pusherEvent: PusherEvent) -> Void in
                    do {
                        let event = Event(channel: pusherEvent.channelName ?? "", event: pusherEvent.eventName, data: (pusherEvent.data ?? "") as String)
                        let message = PusherEventStreamMessage(event: event, connectionStateChange:  nil)
                        let jsonEncoder = JSONEncoder()
                        let jsonData = try jsonEncoder.encode(message)
                        let jsonString = String(data: jsonData, encoding: .utf8)
                        if let eventSinkObj = SwiftPusherHibotPlugin.eventSink {
                            eventSinkObj(jsonString)
                            
                            if (SwiftPusherHibotPlugin.isLoggingEnabled) {
                                print(jsonData)
                            }
                        }
                        
                    } catch {
                        if (SwiftPusherHibotPlugin.isLoggingEnabled) {
                            print("Pusher bind error:" + error.localizedDescription)
                        }
                    }
                })
                if (SwiftPusherHibotPlugin.isLoggingEnabled) {
                    print("Pusher bind (\(bindArgs.eventName))")
                }
            }
        } catch {
            if (SwiftPusherHibotPlugin.isLoggingEnabled) {
                print("Pusher bind error:" + error.localizedDescription)
            }
        }
        result(nil);
    }
    
    public func unbind(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        do {
            let json = call.arguments as! String
            let jsonDecoder = JSONDecoder()
            let bindArgs = try jsonDecoder.decode(BindArgs.self, from: json.data(using: .utf8)!)
            unbindIfBound(channelName: bindArgs.channelName, eventName: bindArgs.eventName)
        } catch {
            if (SwiftPusherHibotPlugin.isLoggingEnabled) {
                print("Pusher unbind error:" + error.localizedDescription)
            }
        }
        result(nil);
    }
    
    private func unbindIfBound(channelName: String, eventName: String) {
        let channel = SwiftPusherHibotPlugin.channels[channelName]
        if let channelObj = channel {
            let callbackId = SwiftPusherHibotPlugin.bindedEvents[channelName + eventName]
            if let callbackIdObj = callbackId {
                channelObj.unbind(eventName: eventName, callbackId: callbackIdObj)
                SwiftPusherHibotPlugin.bindedEvents.removeValue(forKey: channelName + eventName)
                
                if (SwiftPusherHibotPlugin.isLoggingEnabled) {
                    print("Pusher unbind")
                }
            }
        }
    }
    
    public func getSocketId(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let pusherObj = SwiftPusherHibotPlugin.pusher {
            if (SwiftPusherHibotPlugin.isLoggingEnabled) {
                print("Pusher connect socketId")
            }
            result(pusherObj.connection.socketId);
            return;
        }
        result(nil);
    }
    
    public func changedConnectionState(from old: ConnectionState, to new: ConnectionState) {
        do {
            let stateChange = ConnectionStateChange(currentState: new.stringValue(), previousState: old.stringValue())
            let message = PusherEventStreamMessage(event: nil, connectionStateChange: stateChange)
            let jsonEncoder = JSONEncoder()
            let jsonData = try jsonEncoder.encode(message)
            let jsonString = String(data: jsonData, encoding: .utf8)
            if let eventSinkObj = SwiftPusherHibotPlugin.eventSink {
                eventSinkObj(jsonString)
            }
        } catch {
            if (SwiftPusherHibotPlugin.isLoggingEnabled) {
                print("Pusher changedConnectionState error:" + error.localizedDescription)
            }
        }
        
    }
}

class AuthRequestBuilder: AuthRequestBuilderProtocol {
    var endpoint: String
    var headers: [String: String]
    
    init(endpoint: String, headers: [String: String]) {
        self.endpoint = endpoint
        self.headers = headers
    }
    
    func requestFor(socketID: String, channelName: String) -> URLRequest? {
        do{
            var request = URLRequest(url: URL(string: endpoint)!)
            request.httpMethod = "POST"
            
            if(headers.values.contains("application/json")){
                let jsonEncoder = JSONEncoder()
                request.httpBody = try jsonEncoder.encode(["socket_id": socketID, "channel_name": channelName])
            }else{
                request.httpBody = "socket_id=\(socketID)&channel_name=\(channelName)".data(using: String.Encoding.utf8)
            }
            
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
            return request
        }catch {
            if (SwiftPusherHibotPlugin.isLoggingEnabled) {
                print("Authentication error:" + error.localizedDescription)
            }
            return nil
        }
        
    }
}

class StreamHandler: NSObject, FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        SwiftPusherHibotPlugin.eventSink = events
        return nil;
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil;
    }
}

struct InitArgs: Codable {
    var appKey: String
    var options: Options
    var isLoggingEnabled: Bool
}

struct Options: Codable {
    var cluster: String?
    var host: String?
    var port: Int?
    var encrypted: Bool?
    var auth: Auth?
    var activityTimeout: Int?
}

struct Auth: Codable{
    var endpoint: String
    var headers: [String: String]
}

struct PusherEventStreamMessage: Codable {
    var event: Event?
    var connectionStateChange: ConnectionStateChange?
}

struct ConnectionStateChange: Codable {
    var currentState: String
    var previousState: String
}

struct Event: Codable {
    var channel: String
    var event: String
    var data: String
}

struct BindArgs: Codable {
    var channelName: String
    var eventName: String
}
