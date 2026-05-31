import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/message_model.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  MediaStream? _localStream;

  final List<RTCIceCandidate> _pendingCandidates = [];

  final _messageController = StreamController<MessageModel>.broadcast();
  final _connectionStateController = StreamController<RTCPeerConnectionState>.broadcast();
  final _fileProgressController = StreamController<Map<String, dynamic>>.broadcast();
  final _iceCandidateController = StreamController<RTCIceCandidate>.broadcast();
  // Fires when a connection is lost — caller should reconnect if initiator
  final _reconnectController = StreamController<void>.broadcast();

  Stream<MessageModel> get messageStream => _messageController.stream;
  Stream<RTCPeerConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<Map<String, dynamic>> get fileProgressStream => _fileProgressController.stream;
  Stream<RTCIceCandidate> get iceCandidateStream => _iceCandidateController.stream;
  Stream<void> get reconnectStream => _reconnectController.stream;

  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun.relay.metered.ca:80'},
      {
        'urls': 'turn:global.relay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:global.relay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:global.relay.metered.ca:443?transport=tcp',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ],
  };

  // Creates a peer connection if one doesn't exist yet (idempotent).
  Future<void> initialize() async {
    if (_peerConnection != null) return;
    await _createPeerConnection();
  }

  // Tears down the current peer connection and creates a fresh one.
  // Call this before accepting a new offer so stale state never blocks it.
  Future<void> resetAndInitialize() async {
    await _teardown();
    await _createPeerConnection();
  }

  Future<void> _teardown() async {
    await _dataChannel?.close();
    await _peerConnection?.close();
    _peerConnection = null;
    _dataChannel = null;
    _pendingCandidates.clear();
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_configuration);

    _peerConnection!.onConnectionState = (state) {
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(state);
      }
      // DISCONNECTED is temporary and self-recovers; only FAILED is terminal
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _handleConnectionLost();
      }
    };

    _peerConnection!.onIceCandidate = (candidate) {
      if (!_iceCandidateController.isClosed) {
        _iceCandidateController.add(candidate);
      }
    };

    _peerConnection!.onDataChannel = (channel) {
      _dataChannel = channel;
      _setupDataChannel();
    };
  }

  void _handleConnectionLost() {
    if (!_reconnectController.isClosed) _reconnectController.add(null);
    _teardown();
  }

  Future<RTCSessionDescription> createOffer() async {
    _dataChannel = await _peerConnection!.createDataChannel(
      'messages',
      RTCDataChannelInit()
        ..ordered = true
        ..maxRetransmits = 30,
    );
    _setupDataChannel();

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> createAnswer(RTCSessionDescription offer) async {
    await _peerConnection!.setRemoteDescription(offer);
    await _applyPendingCandidates();
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection!.setRemoteDescription(description);
    await _applyPendingCandidates();
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    if (_peerConnection == null) {
      _pendingCandidates.add(candidate);
      return;
    }
    try {
      await _peerConnection!.addCandidate(candidate);
    } catch (_) {
      // Ignore stale candidates
    }
  }

  Future<void> _applyPendingCandidates() async {
    final candidates = List<RTCIceCandidate>.from(_pendingCandidates);
    _pendingCandidates.clear();
    for (final c in candidates) {
      try {
        await _peerConnection!.addCandidate(c);
      } catch (_) {}
    }
  }

  void _setupDataChannel() {
    _dataChannel!.onMessage = (data) {
      _handleIncomingMessage(data);
    };
  }

  void _handleIncomingMessage(RTCDataChannelMessage data) {
    if (data.isBinary) {
      _handleBinaryData(data.binary);
    } else {
      final json = jsonDecode(data.text);
      final message = MessageModel.fromJson(json);
      _messageController.add(message);
    }
  }

  void _handleBinaryData(Uint8List data) {
    final headerLength = data[0];
    final headerBytes = data.sublist(1, 1 + headerLength);
    final header = jsonDecode(utf8.decode(headerBytes));
    final fileData = data.sublist(1 + headerLength);

    _fileProgressController.add({
      'fileId': header['fileId'],
      'chunkIndex': header['chunkIndex'],
      'totalChunks': header['totalChunks'],
      'data': fileData,
      'isComplete': header['chunkIndex'] == header['totalChunks'] - 1,
    });
  }

  Future<void> sendMessage(MessageModel message) async {
    if (_dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw Exception('Data channel not open');
    }
    await _dataChannel!.send(RTCDataChannelMessage(jsonEncode(message.toJson())));
  }

  Future<void> sendFileChunk(String fileId, int chunkIndex, int totalChunks, Uint8List chunk) async {
    if (_dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw Exception('Data channel not open');
    }

    final header = jsonEncode({'fileId': fileId, 'chunkIndex': chunkIndex, 'totalChunks': totalChunks});
    final headerBytes = utf8.encode(header);
    final data = Uint8List(1 + headerBytes.length + chunk.length);
    data[0] = headerBytes.length;
    data.setRange(1, 1 + headerBytes.length, headerBytes);
    data.setRange(1 + headerBytes.length, data.length, chunk);

    await _dataChannel!.send(RTCDataChannelMessage.fromBinary(data));
  }

  Future<MediaStream> getUserMedia({bool video = true, bool audio = true}) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': audio,
      'video': video ? {'facingMode': 'user'} : false,
    });
    return _localStream!;
  }

  Future<void> dispose() async {
    await _teardown();
    await _localStream?.dispose();
    _messageController.close();
    _connectionStateController.close();
    _fileProgressController.close();
    _iceCandidateController.close();
    _reconnectController.close();
  }
}
