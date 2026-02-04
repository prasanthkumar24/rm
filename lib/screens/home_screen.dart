import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user_model.dart';
import '../models/video_model.dart';
import '../models/library_model.dart';
import '../cubits/library_cubit.dart';
import '../cubits/video_cubit.dart';
import '../services/video_service.dart';
import '../services/auth_service.dart';
import 'video_grid_screen.dart';
import 'video_player_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  LibraryModel? _selectedLibrary;

  @override
  Widget build(BuildContext context) {
    // Theme colors
    final backgroundColor = const Color(0xFF00151C);
    final cardColor = const Color(0xFF0E323E);
    final accentBlue = const Color(0xFF3B6DCC);
    final mutedIconColor = const Color(0xFF6B8CA0);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        
        if (_currentIndex == 1 && _selectedLibrary != null) {
          setState(() {
            _selectedLibrary = null;
          });
        } else {
           // Allow app to exit or minimize if on root of tabs
           // For now, we can just let system handle it if we want to exit, 
           // but strictly 'canPop: false' prevents it. 
           // We'll mimic default behavior for root:
           // Navigator.of(context).pop(); // This would exit the app
           // But since we are at root, we might want to minimize.
           // Ideally, we should check if we can pop.
           // For simplicity, if not in library detail, we exit.
           final navigator = Navigator.of(context);
           if (navigator.canPop()) {
             navigator.pop();
           } 
           // If we can't pop (root), we don't do anything (effectively disabling back button for exit)
           // or we can allow exit.
           // Let's allow exit if not in nested state.
           // Actually, 'onPopInvoked' with 'canPop: false' means we must handle it.
           // SystemNavigator.pop() is better for root.
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF002B38), // Top (Lighter Teal/Blue)
                Color(0xFF00151C), // Bottom (Darker)
              ],
            ),
          ),
          child: _buildBody(context), // Removed SafeArea to fix header gaps
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == _currentIndex && index == 1 && _selectedLibrary != null) {
               // If tapping Library again while in detail, go back to list
               setState(() {
                 _selectedLibrary = null;
               });
            } else {
              setState(() {
                _currentIndex = index;
                if (index != 1) {
                  _selectedLibrary = null; // Reset library selection when switching tabs
                }
              });
            }
          },
          backgroundColor: const Color(0xFF001116), // Very dark footer
          selectedItemColor: accentBlue,
          unselectedItemColor: mutedIconColor,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today), // Or similar "Today" icon
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.library_books),
              label: 'Library',
            ),
            // Removed Logout as requested
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_currentIndex == 0) {
      return _buildHomeTab();
    } else if (_currentIndex == 1) {
      return _buildLibraryTab();
    }
    return Container();
  }

  Widget _buildHomeTab() {
    return BlocProvider(
      create: (context) => VideoCubit(context.read<VideoService>())
        ..loadAllVideos(widget.user.serverUrl, widget.user.id, widget.user.accessToken),
      child: Column(
        children: [
          // Header Banner
          // Increased height and ensuring it covers the status bar area
          SizedBox(
            height: 120, // Increased to cover status bar
            width: double.infinity,
            child: Stack(
              children: [
                // Subtle gradient for header background
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.6), // Darker at top for status bar readability
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                   top: 40, // Push content down to avoid status bar overlap
                   left: 0,
                   right: 0,
                   bottom: 0,
                   child: Center(
                    child: Image.asset(
                      'assets/header.jpg',
                      height: 60,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                         // Fallback if asset missing
                         return Text(
                           'RM LIVE', 
                           style: Theme.of(context).textTheme.headlineMedium,
                         );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: BlocBuilder<VideoCubit, VideoState>(
              builder: (context, state) {
                if (state is VideoLoading) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF3B6DCC)));
                } else if (state is VideoError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        const Text('Unable to load videos', style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context.read<VideoCubit>().loadAllVideos(
                                widget.user.serverUrl,
                                widget.user.id,
                                widget.user.accessToken,
                              ),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B6DCC)),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                } else if (state is VideoLoaded) {
                  if (state.videos.isEmpty) {
                    return const Center(child: Text('No videos found.', style: TextStyle(color: Colors.white70)));
                  }
                  
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          'Watch',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // List of Cards
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: state.videos.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 30),
                          itemBuilder: (context, index) {
                            return _buildVideoCard(state.videos[index]);
                          },
                        ),
                        
                        const SizedBox(height: 30),
                      ],
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(VideoModel video) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0E323E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.play_circle_outline, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    video.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white70,
                      fontFamily: 'Sans',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              video.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Video Thumbnail
          Container(
            height: 180,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: Color(0xFF3B6DCC)),
              ),
              errorWidget: (context, url, error) => const Center(
                child: Icon(Icons.error, color: Colors.white54),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              video.description.isNotEmpty ? video.description : 'No description available.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Watch Now Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoPlayerScreen(video: video, user: widget.user),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: const Text(
                  'Watch Now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B6DCC).withOpacity(0.2), // Transparent blue
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF3B6DCC), width: 1),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLibraryTab() {
    if (_selectedLibrary != null) {
      return VideoGridScreen(
        user: widget.user,
        library: _selectedLibrary!,
        onBack: () {
          setState(() {
            _selectedLibrary = null;
          });
        },
      );
    }

    return BlocProvider(
      create: (context) => LibraryCubit(context.read<VideoService>())
        ..loadLibraries(widget.user.serverUrl, widget.user.id, widget.user.accessToken),
      child: Column(
        children: [
           SizedBox(
            height: 120, // Match Home header height for consistency
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      'Library',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<LibraryCubit, LibraryState>(
              builder: (context, state) {
                if (state is LibraryLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is LibraryError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Unable to load libraries', style: TextStyle(color: Colors.white)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context.read<LibraryCubit>().loadLibraries(
                                widget.user.serverUrl,
                                widget.user.id,
                                widget.user.accessToken,
                              ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                } else if (state is LibraryLoaded) {
                  if (state.libraries.isEmpty) {
                    return const Center(child: Text('No libraries found.', style: TextStyle(color: Colors.white)));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.libraries.length,
                    itemBuilder: (context, index) {
                      final lib = state.libraries[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E323E), // Match card style
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.video_library, size: 24, color: Colors.white),
                          ),
                          title: Text(
                            lib.name,
                            style: const TextStyle(
                              fontSize: 18, 
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            lib.collectionType,
                            style: TextStyle(color: Colors.white.withOpacity(0.7)),
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white.withOpacity(0.5)),
                          onTap: () {
                            setState(() {
                              _selectedLibrary = lib;
                            });
                          },
                        ),
                      );
                    },
                  );
                }
                return const Center(child: Text('Loading libraries...', style: TextStyle(color: Colors.white)));
              },
            ),
          ),
        ],
      ),
    );
  }

  // _showLogoutConfirmation removed/unused

}
