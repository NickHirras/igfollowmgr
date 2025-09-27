import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../providers/instagram_provider.dart';
import '../models/instagram_user.dart';

class FollowersScreen extends StatefulWidget {
  const FollowersScreen({super.key});

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
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
        final followers = provider.searchFollowers(_searchQuery);
        
        return Scaffold(
          appBar: AppBar(
            title: Text('Followers (${followers.length})'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search followers...',
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
          body: _buildBody(context, provider, followers),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, InstagramProvider provider, List<InstagramUser> followers) {
    if (provider.isLoading && followers.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (followers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'No followers yet' : 'No followers found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Your followers will appear here once you start getting them.',
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
      itemCount: followers.length,
      itemBuilder: (context, index) {
        final follower = followers[index];
        return _buildFollowerCard(context, provider, follower);
      },
    );
  }

  Widget _buildFollowerCard(BuildContext context, InstagramProvider provider, InstagramUser follower) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          backgroundImage: follower.profilePictureUrl != null
              ? CachedNetworkImageProvider(follower.profilePictureUrl!)
              : null,
          child: follower.profilePictureUrl == null
              ? Text(
                  follower.username[0].toUpperCase(),
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
                follower.username,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (follower.isVerified)
              const Icon(
                Icons.verified,
                size: 16,
                color: Colors.blue,
              ),
            if (follower.isPrivate)
              const Icon(
                Icons.lock,
                size: 16,
                color: Colors.grey,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (follower.fullName != null && follower.fullName!.isNotEmpty)
              Text(
                follower.fullName!,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            if (follower.biography != null && follower.biography!.isNotEmpty)
              Text(
                follower.biography!,
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
                if (follower.followersCount != null)
                  _buildStatChip('${_formatNumber(follower.followersCount!)} followers'),
                if (follower.followingCount != null) ...[
                  const SizedBox(width: 8),
                  _buildStatChip('${_formatNumber(follower.followingCount!)} following'),
                ],
                if (follower.postsCount != null) ...[
                  const SizedBox(width: 8),
                  _buildStatChip('${_formatNumber(follower.postsCount!)} posts'),
                ],
              ],
            ),
            if (follower.followedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Followed you ${_formatDate(follower.followedAt!)}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, provider, follower, value),
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
              value: 'remove_follower',
              child: Row(
                children: [
                  Icon(Icons.person_remove, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Remove Follower', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showFollowerDetails(context, follower),
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

  void _handleMenuAction(BuildContext context, InstagramProvider provider, InstagramUser follower, String action) {
    switch (action) {
      case 'view_profile':
        _showFollowerDetails(context, follower);
        break;
      case 'remove_follower':
        _showRemoveFollowerDialog(context, provider, follower);
        break;
    }
  }

  void _showFollowerDetails(BuildContext context, InstagramUser follower) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              backgroundImage: follower.profilePictureUrl != null
                  ? CachedNetworkImageProvider(follower.profilePictureUrl!)
                  : null,
              child: follower.profilePictureUrl == null
                  ? Text(
                      follower.username[0].toUpperCase(),
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
                          follower.username,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (follower.isVerified)
                        const Icon(
                          Icons.verified,
                          size: 16,
                          color: Colors.blue,
                        ),
                      if (follower.isPrivate)
                        const Icon(
                          Icons.lock,
                          size: 16,
                          color: Colors.grey,
                        ),
                    ],
                  ),
                  if (follower.fullName != null && follower.fullName!.isNotEmpty)
                    Text(
                      follower.fullName!,
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
              if (follower.biography != null && follower.biography!.isNotEmpty) ...[
                Text(
                  'Bio',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(follower.biography!),
                const SizedBox(height: 16),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('Followers', follower.followersCount),
                  _buildStatColumn('Following', follower.followingCount),
                  _buildStatColumn('Posts', follower.postsCount),
                ],
              ),
              if (follower.followedAt != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Followed you on ${_formatFullDate(follower.followedAt!)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
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

  void _showRemoveFollowerDialog(BuildContext context, InstagramProvider provider, InstagramUser follower) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Follower'),
        content: Text('Are you sure you want to remove @${follower.username} from your followers?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.removeFollower(follower.username);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
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
