import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/message_model.dart';

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  MediaStream? _localStream;
  
  final _messageController = StreamController<MessageModel>.broadcast();
  final _connectionStateController = StreamController<RTCPeerConnectionState>.broadcast();
  final _fileProgressController = StreamController<Map<String, dynamic>>.broadcast();
  
  Stream<MessageModel> get messageStream => _messageController.stream;
  Stream<RTCPeerConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<Map<String, dynamic>> get fileProgressStream => _fileProgressController.stream;
  
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };
  
  final Map<String, dynamic> _dataChannelConstraints = {
    'ordered': true,
    'maxRetransmits': 30,
  };

  Future<void> initialize() async {
    await _createPeerConnection();
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_configuration);
    
    _peerConnection!.onConnectionState = (state) {
      _connectionStateController.add(state);
    };
    
    _peerConnection!.onIceCandidate = (candidate) {
      // ICE candidates will be sent via signaling
    };
    
    _peerConnection!.onDataChannel = (channel) {
      _dataChannel = channel;
      _setupDataChannel();
    };
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
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection!.setRemoteDescription(description);
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
  }

  void _setupDataChannel() {
    _dataChannel!.onMessage = (data) {
      _handleIncomingMessage(data);
    };
    
    _dataChannel!.onDataChannelState = (state) {
      print('Data channel state: $state');
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
    // Handle file chunks
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
    
    final data = RTCDataChannelMessage(jsonEncode(message.toJson()));
    await _dataChannel!.send(data);
  }

  Future<void> sendFileChunk(String fileId, int chunkIndex, int totalChunks, Uint8List chunk) async {
    if (_dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw Exception('Data channel not open');
    }
    
    final header = jsonEncode({
      'fileId': fileId,
      'chunkIndex': chunkIndex,
      'totalChunks': totalChunks,
    });
    
    final headerBytes = utf8.encode(header);
    final data = Uint8List(1 + headerBytes.length + chunk.length);
    
    data[0] = headerBytes.length;
    data.setRange(1, 1 + headerBytes.length, headerBytes);
    data.setRange(1 + headerBytes.length, data.length, chunk);
    
    final message = RTCDataChannelMessage.fromBinary(data);
    await _dataChannel!.send(message);
  }

  Future<MediaStream> getUserMedia({bool video = true, bool audio = true}) async {
    final mediaConstraints = <String, dynamic>{
      'audio': audio,
      'video': video
          ? {'facingMode': 'user'}
          : false,
    };
    
    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    return _localStream!;
  }

  Future<void> startCall(String peerId, {bool video = true}) async {
    final stream = await getUserMedia(video: video);
    
    for (final track in stream.getTracks()) {
      _peerConnection!.addTrack(track, stream);
    }
    
    _peerConnection!.onTrack = (event) {
      // Handle remote track - emit to UI
    };
  }

  Future<void> dispose() async {
    await _dataChannel?.close();
    await _peerConnection?.close();
    await _localStream?.dispose();
    
    _messageController.close();
    _connectionStateController.close();
    _fileProgressController.close();
  }
}
