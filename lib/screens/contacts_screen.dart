import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/friend_request_model.dart';
import '../services/friend_service.dart';
import '../services/local_storage_service.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';

class ContactsScreen extends StatefulWidget {
  final LocalStorageService localStorage;
  final AuthService authService;

  const ContactsScreen({
    super.key,
    required this.localStorage,
    required this.authService,
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  late FriendService _friendService;
  List<UserModel> _friends = [];
  List<UserModel> _searchResults = [];
  List<FriendRequestModel> _pendingRequests = [];
  Map<String, UserModel> _requestSenders = {};
  bool _isLoading = true;
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _friendService = FriendService(
      widget.authService,
      widget.localStorage,
    );

    await _friendService.initialize();
    await _loadFriends();

    // Listen for incoming friend requests
    _friendService.requestStream.listen((request) {
      if (mounted) {
        _loadFriends();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('New friend request received!'),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                // Scroll to requests section
              },
            ),
          ),
        );
      }
    });
  }

  Future<void> _loadFriends() async {
    setState(() => _isLoading = true);

    final friends = await _friendService.getFriends();
    final requests = await _friendService.fetchPendingRequests();

    // Fetch sender info for each request to show names
    final senders = <String, UserModel>{};
    for (final request in requests) {
      final sender = await _friendService.getUserById(request.senderId);
      if (sender != null) senders[request.senderId] = sender;
    }

    setState(() {
      _friends = friends;
      _pendingRequests = requests;
      _requestSenders = senders;
      _isLoading = false;
    });
  }

  Future<void> _acceptRequest(String requestId) async {
    await _friendService.acceptFriendRequest(requestId);
    await _loadFriends();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request accepted!')),
      );
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    await _friendService.rejectFriendRequest(requestId);
    await _loadFriends();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request rejected')),
      );
    }
  }

  Future<void> _searchUser() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _searchResults = [];
    });

    final user = await _friendService.searchUser(query);

    setState(() {
      if (user != null) {
        _searchResults = [user];
      }
      _isSearching = false;
    });
  }

  Future<void> _sendFriendRequest(String userId) async {
    try {
      final request = await _friendService.sendFriendRequest(userId);

      if (request != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e.toString().contains('yourself')
            ? 'Cannot send request to yourself'
            : 'Failed to send request: ${e.toString()}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _startChat(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          peerId: user.uid,
          peerName: user.displayName ?? 'Unknown',
          localStorage: widget.localStorage,
          authService: widget.authService,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _friendService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by username or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchResults = [];
                              });
                            },
                          )
                        : null,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _searchUser(),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _searchResults.isNotEmpty
              ? _buildSearchResults()
              : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    if (_friends.isEmpty && _pendingRequests.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      children: [
        if (_pendingRequests.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Friend Requests (${_pendingRequests.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ..._pendingRequests.map((request) => _buildRequestTile(request)),
          const Divider(),
        ],
        if (_friends.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Friends',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ..._friends.map((friend) => _buildFriendTile(friend)),
        ],
      ],
    );
  }

  Widget _buildRequestTile(FriendRequestModel request) {
    final sender = _requestSenders[request.senderId];
    final name = sender?.displayName ?? sender?.username ?? 'Unknown';
    final subtitle = sender?.username != null ? '@${sender!.username}' : request.senderId.substring(0, 8);
    return ListTile(
      leading: CircleAvatar(
        radius: 28,
        backgroundImage: sender?.photoURL != null ? NetworkImage(sender!.photoURL!) : null,
        child: sender?.photoURL == null
            ? Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 18))
            : null,
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
            onPressed: () => _acceptRequest(request.id),
            tooltip: 'Accept',
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
            onPressed: () => _rejectRequest(request.id),
            tooltip: 'Reject',
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTile(UserModel friend) {
    return ListTile(
      leading: CircleAvatar(
        radius: 28,
        backgroundImage: friend.photoURL != null
            ? NetworkImage(friend.photoURL!)
            : null,
        child: friend.photoURL == null
            ? Text(
                (friend.displayName ?? '?')[0].toUpperCase(),
                style: const TextStyle(fontSize: 20),
              )
            : null,
      ),
      title: Text(
        friend.displayName ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (friend.username != null)
            Text(
              '@${friend.username}',
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (friend.phoneNumber != null)
            Text(
              friend.phoneNumber!,
              style: const TextStyle(color: Colors.grey),
            ),
        ],
      ),
      trailing: ElevatedButton(
        onPressed: () => _startChat(friend),
        child: const Text('Message'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          const Text(
            'No contacts yet',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Search by username or phone to find friends',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Show phone contacts picker
            },
            icon: const Icon(Icons.contacts),
            label: const Text('Import from Phone'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Search Results',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final user = _searchResults[index];
              final isFriend = _friends.any((f) => f.uid == user.uid);
              return _buildUserTile(user, isFriend: isFriend);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserTile(UserModel user, {required bool isFriend}) {
    return ListTile(
      leading: CircleAvatar(
        radius: 28,
        backgroundImage: user.photoURL != null
            ? NetworkImage(user.photoURL!)
            : null,
        child: user.photoURL == null
            ? Text(
                (user.displayName ?? '?')[0].toUpperCase(),
                style: const TextStyle(fontSize: 20),
              )
            : null,
      ),
      title: Text(
        user.displayName ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.username != null)
            Text(
              '@${user.username}',
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (user.phoneNumber != null)
            Text(
              user.phoneNumber!,
              style: const TextStyle(color: Colors.grey),
            ),
          if (user.username == null && user.phoneNumber == null)
            const Text(
              'No contact info',
              style: TextStyle(color: Colors.grey),
            ),
        ],
      ),
      trailing: isFriend
          ? ElevatedButton(
              onPressed: () => _startChat(user),
              child: const Text('Message'),
            )
          : ElevatedButton(
              onPressed: () => _sendFriendRequest(user.uid),
              child: const Text('Add Friend'),
            ),
    );
  }
}
