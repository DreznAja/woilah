import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/chat_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/room_list_widget.dart';
import '../../widgets/connection_status_widget.dart';
import '../auth/login_screen.dart';
import '../chat/chat_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTab = 'all';

  @override
  void initState() {
    super.initState();
    
    // Load initial data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatProvider.notifier).loadRooms();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _handleSearch(String query) {
    final filters = _getFiltersForTab(_selectedTab);
    ref.read(chatProvider.notifier).loadRooms(
      search: query.isNotEmpty ? query : null,
      filters: filters,
    );
  }

  Map<String, dynamic> _getFiltersForTab(String tab) {
    switch (tab) {
      case 'unassigned':
        return {'St': [1]};
      case 'assigned':
        return {'St': [2]};
      case 'resolved':
        return {'St': [3]};
      default:
        return {'St': [1, 2, 3]};
    }
  }

  void _selectTab(String tab) {
    setState(() {
      _selectedTab = tab;
    });
    
    final filters = _getFiltersForTab(tab);
    ref.read(chatProvider.notifier).loadRooms(filters: filters);
  }

  void _navigateToChat(room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(room: room),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Nobox Chat'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 12),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryColor,
                child: Text(
                  authState.userData?.displayName.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // User info and connection status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome, ${authState.userData?.displayName ?? 'User'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const ConnectionStatusWidget(),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Search Bar
                TextFormField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search conversations...',
                    prefixIcon: Icon(Icons.search),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: _handleSearch,
                ),
              ],
            ),
          ),
          
          // Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Row(
              children: [
                _buildTab('all', 'All'),
                _buildTab('unassigned', 'Unassigned'),
                _buildTab('assigned', 'Assigned'),
                _buildTab('resolved', 'Resolved'),
              ],
            ),
          ),
          
          // Room List
          Expanded(
            child: RoomListWidget(
              rooms: chatState.rooms,
              isLoading: chatState.isLoading,
              selectedRoomId: null, // No selection needed in full page mode
              onRoomTap: _navigateToChat,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String value, String label) {
    final isSelected = _selectedTab == value;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectTab(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}