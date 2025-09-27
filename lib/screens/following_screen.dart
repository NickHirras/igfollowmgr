import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../providers/instagram_provider.dart';
import '../models/instagram_user.dart';

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InstagramProvider>(
      builder: (context, provider, child) {
        final following = provider.searchFollowing(_searchQuery);
        
        return Scaffold(
          appBar: AppBar(
            title: Text('Following (${following.length})'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search following...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
            ),
          ),
          body: _buildBody(context, provider, following),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, InstagramProvider provider, List<InstagramUser> following) {
    if (provider.isLoading && following.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (following.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'Not following anyone yet' : 'No following found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Start following people to see them here.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: following.length,
      itemBuilder: (context, index) {
        final user = following[index];
        return _buildFollowingCard(context, provider, user);
      },
    );
  }

  Widget _buildFollowingCard(BuildContext context, InstagramProvider provider, InstagramUser user) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          backgroundImage: user.profilePictureUrl != null
              ? CachedNetworkImageProvider(user.profilePictureUrl!)
              : null,
          child: user.profilePictureUrl == null
              ? Text(
                  user.username[0].toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.username,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user.isVerified)
              const Icon(
                Icons.verified,
                size: 16,
                color: Colors.blue,
              ),
            if (user.isPrivate)
              const Icon(
                Icons.lock,
                size: 16,
                color: Colors.grey,
              ),
            if (user.isBusiness)
              const Icon(
                Icons.business,
                size: 16,
                color: Colors.orange,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.fullName != null && user.fullName!.isNotEmpty)
              Text(
                user.fullName!,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            if (user.biography != null && user.biography!.isNotEmpty)
              Text(
                user.biography!,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (user.followersCount != null)
                  _buildStatChip('${_formatNumber(user.followersCount!)} followers'),
                if (user.followingCount != null) ...[
                  const SizedBox(width: 8),
                  _buildStatChip('${_formatNumber(user.followingCount!)} following'),
                ],
                if (user.postsCount != null) ...[
                  const SizedBox(width: 8),
                  _buildStatChip('${_formatNumber(user.postsCount!)} posts'),
                ],
              ],
            ),
            if (user.followingAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Following since ${_formatDate(user.followingAt!)}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, provider, user, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view_profile',
              child: Row(
                children: [
                  Icon(Icons.person),
                  SizedBox(width: 8),
                  Text('View Profile'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'unfollow',
              child: Row(
                children: [
                  Icon(Icons.person_remove, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Unfollow', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showUserDetails(context, user),
      ),
    );
  }

  Widget _buildStatChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, InstagramProvider provider, InstagramUser user, String action) {
    switch (action) {
      case 'view_profile':
        _showUserDetails(context, user);
        break;
      case 'unfollow':
        _showUnfollowDialog(context, provider, user);
        break;
    }
  }

  void _showUserDetails(BuildContext context, InstagramUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              backgroundImage: user.profilePictureUrl != null
                  ? CachedNetworkImageProvider(user.profilePictureUrl!)
                  : null,
              child: user.profilePictureUrl == null
                  ? Text(
                      user.username[0].toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.username,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (user.isVerified)
                        const Icon(
                          Icons.verified,
                          size: 16,
                          color: Colors.blue,
                        ),
                      if (user.isPrivate)
                        const Icon(
                          Icons.lock,
                          size: 16,
                          color: Colors.grey,
                        ),
                      if (user.isBusiness)
                        const Icon(
                          Icons.business,
                          size: 16,
                          color: Colors.orange,
                        ),
                    ],
                  ),
                  if (user.fullName != null && user.fullName!.isNotEmpty)
                    Text(
                      user.fullName!,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user.biography != null && user.biography!.isNotEmpty) ...[
                Text(
                  'Bio',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(user.biography!),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('Followers', user.followersCount),
                  _buildStatColumn('Following', user.followingCount),
                  _buildStatColumn('Posts', user.postsCount),
                ],
              ),
              if (user.followingAt != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Following since ${_formatFullDate(user.followingAt!)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
              if (user.externalUrl != null && user.externalUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Website',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  user.externalUrl!,
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showUnfollowDialog(context, context.read<InstagramProvider>(), user);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, int? value) {
    return Column(
      children: [
        Text(
          value != null ? _formatNumber(value) : '-',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  void _showUnfollowDialog(BuildContext context, InstagramProvider provider, InstagramUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unfollow User'),
        content: Text('Are you sure you want to unfollow @${user.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.removeFollowing(user.username);
              provider.queueUnfollowAction(user.username);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unfollow'),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  String _formatFullDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }
}
