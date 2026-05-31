import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:intl/intl.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../services/local_storage_service.dart';
import '../services/auth_service.dart';
import '../services/webrtc_service.dart';
import '../services/signaling_service.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String peerId;
  final String peerName;
  final LocalStorageService localStorage;
  final AuthService authService;

  const ChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    required this.localStorage,
    required this.authService,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ChatService _chatService;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  List<MessageModel> _messages = [];
  bool _isConnected = false;
  bool _isTyping = false;
  Timer? _typingResetTimer;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    final webRTCService = WebRTCService();
    final signalingService = SignalingService(widget.authService);
    
    _chatService = ChatService(
      widget.authService,
      webRTCService,
      signalingService,
      widget.localStorage,
    );
    
    await _chatService.initialize();
    await signalingService.initialize();
    
    // Load existing messages
    _messages = _chatService.getChatHistory(widget.peerId);
    if (mounted) setState(() {});
    _scrollToBottom();

    // Connect to peer
    await _chatService.connectToPeer(widget.peerId);

    // Listen for new messages
    webRTCService.messageStream.listen((message) {
      if (mounted) {
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();
      }
    });
    
    // Listen for connection state
    webRTCService.connectionStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isConnected = state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      });
      // Reload messages when reconnected so nothing is missed
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        setState(() => _messages = _chatService.getChatHistory(widget.peerId));
        _scrollToBottom();
      }
    });

    // On disconnect: mark offline and reload from local storage so any
    // messages saved before the drop are still visible
    webRTCService.reconnectStream.listen((_) {
      if (!mounted) return;
      setState(() {
        _isConnected = false;
        _messages = _chatService.getChatHistory(widget.peerId);
      });
    });
    
    // Listen for typing indicators
    _chatService.typingStream.listen((typingData) {
      if (typingData['peerId'] == widget.peerId && mounted) {
        final isTyping = (typingData['isTyping'] as bool?) ?? false;
        _typingResetTimer?.cancel();
        if (isTyping) {
          setState(() => _isTyping = true);
          // Auto-clear after 3 s in case the "stopped typing" signal is lost
          _typingResetTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _isTyping = false);
          });
        } else {
          setState(() => _isTyping = false);
        }
      }
    });
    
    setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    _messageController.clear();
    
    final message = await _chatService.sendTextMessage(widget.peerId, text);
    
    setState(() {
      _messages.add(message);
    });
    
    _scrollToBottom();
  }

  Future<void> _sendImage() async {
    final message = await _chatService.sendImage(widget.peerId);
    if (message != null) {
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendVideo() async {
    final message = await _chatService.sendVideo(widget.peerId);
    if (message != null) {
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
    }
  }

  Future<void> _sendFile() async {
    final message = await _chatService.sendFile(widget.peerId);
    if (message != null) {
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(context);
                _sendImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(context);
                _sendVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
              title: const Text('File'),
              onTap: () {
                Navigator.pop(context);
                _sendFile();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _typingResetTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _chatService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.peerName),
            if (_isTyping)
              const Text(
                'typing...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              )
            else if (_isConnected)
              const Text(
                'Connected',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.green,
                  fontWeight: FontWeight.normal,
                ),
              )
            else
              const Text(
                'Connecting...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              // Video call
            },
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              // Voice call
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                // Clear chat
              } else if (value == 'block') {
                // Block user
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text('Clear Chat'),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Text('Block User'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet.\nStart the conversation!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message.senderId ==
                          widget.authService.currentUser?.uid;
                      
                      return MessageBubble(
                        message: message,
                        isMe: isMe,
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    onPressed: _showAttachmentOptions,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      onChanged: (text) {
                        _chatService.setTypingStatus(
                          widget.peerId,
                          text.isNotEmpty,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
