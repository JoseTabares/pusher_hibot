import 'dart:convert';

import 'package:flutter/services.dart';

class PusherHibot {
  PusherHibot._();

  static const MethodChannel _channel = const MethodChannel('pusher');
  static const _eventChannel = const EventChannel('pusherStream');

  static void Function(ConnectionStateChange) _onConnectionStateChange;
  static void Function(ConnectionError) _onError;

  static String _socketId;

  static Map<String, void Function(Event)> eventCallbacks =
      Map<String, void Function(Event)>();

  /// Setup app key and options
  static Future init(
    String appKey,
    PusherOptions options, {
    bool enableLogging = false,
  }) async {
    assert(appKey != null);
    assert(options != null);

    _eventChannel.receiveBroadcastStream().listen(_handleEvent);

    final initArgs = jsonEncode(InitArgs(
      appKey,
      options,
      isLoggingEnabled: enableLogging,
    ).toJson());

    await _channel.invokeMethod('init', initArgs);
  }

  /// Connect the client to pusher
  static Future connect({
    void Function(ConnectionStateChange) onConnectionStateChange,
    void Function(ConnectionError) onError,
  }) async {
    _onConnectionStateChange = onConnectionStateChange;
    _onError = onError;
    await _channel.invokeMethod('connect');
  }

  /// Disconnect the client from pusher
  static Future disconnect() async {
    await _channel.invokeMethod('disconnect');
  }

  /// Subscribe to a channel
  /// Use the returned [Channel] to bind events
  static Future<Channel> subscribe(String channelName) async {
    await _channel.invokeMethod('subscribe', channelName);
    return Channel(name: channelName);
  }

  /// Unsubscribe from a channel
  static Future unsubscribe(String channelName) async {
    await _channel.invokeMethod('unsubscribe', channelName);
  }

  static Future _bind(
    String channelName,
    String eventName, {
    void Function(Event) onEvent,
  }) async {
    final bindArgs = jsonEncode(BindArgs(
      channelName: channelName,
      eventName: eventName,
    ).toJson());

    eventCallbacks[channelName + eventName] = onEvent;
    await _channel.invokeMethod('bind', bindArgs);
  }

  static Future _unbind(String channelName, String eventName) async {
    final bindArgs = jsonEncode(BindArgs(
      channelName: channelName,
      eventName: eventName,
    ).toJson());

    eventCallbacks.remove(channelName + eventName);
    await _channel.invokeMethod('unbind', bindArgs);
  }

  static void _handleEvent([dynamic arguments]) async {
    if (arguments == null || !(arguments is String)) {
      //TODO log
    }

    var message = PusherEventStreamMessage.fromJson(jsonDecode(arguments));

    if (message.isEvent) {
      var callback =
          eventCallbacks[message.event.channel + message.event.event];
      if (callback != null) {
        callback(message.event);
      } else {
        //TODO log
      }
    } else if (message.isConnectionStateChange) {
      if (_onConnectionStateChange != null) {
        _onConnectionStateChange(message.connectionStateChange);
        _socketId = await _channel.invokeMethod('getSocketId');
      }
    } else if (message.isConnectionError) {
      if (_onError != null) {
        _onError(message.connectionError);
      }
    }
  }
}

class PusherOptions {
  final PusherAuth auth;
  final String cluster;
  final String host;
  final int port;
  final bool encrypted;
  final int activityTimeout;

  PusherOptions({
    this.auth,
    this.cluster,
    this.host,
    this.port = 443,
    this.encrypted = true,
    this.activityTimeout = 30000,
  });

  factory PusherOptions.fromJson(Map<String, dynamic> json) => PusherOptions(
        auth: json['auth'] == null
            ? null
            : PusherAuth.fromJson(json['auth'] as Map<String, dynamic>),
        cluster: json['cluster'] as String,
        host: json['host'] as String,
        port: json['port'] as int,
        encrypted: json['encrypted'] as bool,
        activityTimeout: json['activityTimeout'] as int,
      );

  Map<String, dynamic> toJson() {
    final val = <String, dynamic>{};

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('auth', auth);
    writeNotNull('cluster', cluster);
    writeNotNull('host', host);
    writeNotNull('port', port);
    writeNotNull('encrypted', encrypted);
    writeNotNull('activityTimeout', activityTimeout);
    return val;
  }
}

class PusherAuth {
  final String endpoint;
  final Map<String, String> headers;

  PusherAuth(
    this.endpoint, {
    this.headers = const {'Content-Type': 'application/x-www-form-urlencoded'},
  });

  factory PusherAuth.fromJson(Map<String, dynamic> json) => PusherAuth(
        json['endpoint'] as String,
        headers: (json['headers'] as Map<String, dynamic>)?.map(
          (k, e) => MapEntry(k, e as String),
        ),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'endpoint': endpoint,
        'headers': headers,
      };
}

class InitArgs {
  final String appKey;
  final PusherOptions options;
  final bool isLoggingEnabled;

  InitArgs(this.appKey, this.options, {this.isLoggingEnabled = false});

  factory InitArgs.fromJson(Map<String, dynamic> json) => InitArgs(
        json['appKey'] as String,
        json['options'] == null
            ? null
            : PusherOptions.fromJson(json['options'] as Map<String, dynamic>),
        isLoggingEnabled: json['isLoggingEnabled'] as bool,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'appKey': appKey,
        'options': options,
        'isLoggingEnabled': isLoggingEnabled,
      };
}

class ConnectionStateChange {
  final String currentState;
  final String previousState;

  ConnectionStateChange({this.currentState, this.previousState});

  factory ConnectionStateChange.fromJson(Map<String, dynamic> json) =>
      ConnectionStateChange(
        currentState: json['currentState'] as String,
        previousState: json['previousState'] as String,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'currentState': currentState,
        'previousState': previousState,
      };
}

class ConnectionError {
  final String message;
  final String code;
  final String exception;

  ConnectionError({this.message, this.code, this.exception});

  factory ConnectionError.fromJson(Map<String, dynamic> json) =>
      ConnectionError(
        message: json['message'] as String,
        code: json['code'] as String,
        exception: json['exception'] as String,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'message': message,
        'code': code,
        'exception': exception,
      };
}

class Channel {
  final String name;

  Channel({this.name});

  /// Bind to listen for events sent on the given channel
  Future bind(String eventName, void Function(Event) onEvent) async {
    await PusherHibot._bind(name, eventName, onEvent: onEvent);
  }

  Future unbind(String eventName) async {
    await PusherHibot._unbind(name, eventName);
  }
}

class Event {
  final String channel;
  final String event;
  final String data;

  Event({this.channel, this.event, this.data});

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        channel: json['channel'] as String,
        event: json['event'] as String,
        data: json['data'] as String,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'channel': channel,
        'event': event,
        'data': data,
      };
}

class BindArgs {
  final String channelName;
  final String eventName;

  BindArgs({this.channelName, this.eventName});

  factory BindArgs.fromJson(Map<String, dynamic> json) => BindArgs(
        channelName: json['channelName'] as String,
        eventName: json['eventName'] as String,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'channelName': channelName,
        'eventName': eventName,
      };
}

class PusherEventStreamMessage {
  final Event event;
  final ConnectionStateChange connectionStateChange;
  final ConnectionError connectionError;

  bool get isEvent => event != null;

  bool get isConnectionStateChange => connectionStateChange != null;

  bool get isConnectionError => connectionError != null;

  PusherEventStreamMessage(
      {this.event, this.connectionStateChange, this.connectionError});

  factory PusherEventStreamMessage.fromJson(Map<String, dynamic> json) =>
      PusherEventStreamMessage(
        event: json['event'] == null
            ? null
            : Event.fromJson(json['event'] as Map<String, dynamic>),
        connectionStateChange: json['connectionStateChange'] == null
            ? null
            : ConnectionStateChange.fromJson(
                json['connectionStateChange'] as Map<String, dynamic>),
        connectionError: json['connectionError'] == null
            ? null
            : ConnectionError.fromJson(
                json['connectionError'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'event': event,
        'connectionStateChange': connectionStateChange,
        'connectionError': connectionError,
      };
}
