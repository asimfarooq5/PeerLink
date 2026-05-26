import 'package:flutter/material.dart';
import '../models/chat_session_model.dart';
import '../models/user_model.dart';
import '../services/local_storage_service.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';
import 'contacts_screen.dart';
import 'settings_screen.dart';

class ChatListScreen extends StatefulWidget {
  final LocalStorageService localStorage;
  final AuthService authService;

  const ChatListScreen({
    super.key,
    required this.localStorage,
    required this.authService,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<ChatSessionModel> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  void _loadSessions() {
    setState(() {
      _sessions = widget.localStorage.getAllSessions();
      _isLoading = false;
    });
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);
    
    if (messageDate == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Search functionality
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(
                      authService: widget.authService,
                      localStorage: widget.localStorage,
                    ),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    return _buildChatTile(session);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContactsScreen(
                localStorage: widget.localStorage,
                authService: widget.authService,
              ),
            ),
          );
        },
        child: const Icon(Icons.chat),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the button below to start a chat',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ContactsScreen(
                    localStorage: widget.localStorage,
                    authService: widget.authService,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Find Contacts'),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(ChatSessionModel session) {
    final peer = widget.localStorage.getUser(session.peerId);
    
    return ListTile(
      leading: CircleAvatar(
        radius: 28,
        backgroundImage: peer?.photoURL != null
            ? NetworkImage(peer!.photoURL!)
            : null,
        child: peer?.photoURL == null
            ? Text(
                (peer?.displayName ?? session.peerName ?? '?')[0].toUpperCase(),
                style: const TextStyle(fontSize: 20),
              )
            : null,
      ),
      title: Text(
        peer?.displayName ?? session.peerName ?? 'Unknown',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Row(
        children: [
          if (session.isP2PConnected)
            const Icon(
              Icons.circle,
              size: 8,
              color: Colors.green,
            ),
          if (session.isP2PConnected)
            const SizedBox(width: 4),
          Expanded(
            child: Text(
              session.lastMessage ?? 'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: session.unreadCount > 0
                    ? Colors.black
                    : Colors.grey,
                fontWeight: session.unreadCount > 0
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(session.lastMessageTime),
            style: TextStyle(
              fontSize: 12,
              color: session.unreadCount > 0
                  ? Theme.of(context).primaryColor
                  : Colors.grey,
            ),
          ),
          if (session.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                session.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              peerId: session.peerId,
              peerName: peer?.displayName ?? session.peerName ?? 'Unknown',
              localStorage: widget.localStorage,
              authService: widget.authService,
            ),
          ),
        );
      },
    );
  }
}
