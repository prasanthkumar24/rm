import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final bool initialServerAvailable;

  const HomeScreen({Key? key, required this.user, this.initialServerAvailable = true}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  LibraryModel? _selectedLibrary;
  final Map<String, bool> _isExpanded = {};
  bool _isRetrying = false;
  late User _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    // Force portrait on home screen to prevent layout glitches after video
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  Future<void> _handleRetry(BuildContext context, {required bool isLibraryTab}) async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);

    try {
      final authService = context.read<AuthService>();

      // 1. If we don't have a valid session, try to log in first
      if (_currentUser.accessToken.isEmpty || _currentUser.id.isEmpty) {
        final credentials = await authService.getVideoCredentials();
        final username = credentials['username'];
        final password = credentials['password'];

        if (username != null && password != null) {
          try {
            final loggedInUser = await authService.login(
              _currentUser.serverUrl,
              username,
              password,
            );
            if (loggedInUser != null) {
              setState(() {
                _currentUser = loggedInUser;
              });
            }
          } catch (e) {
            debugPrint('Retry login failed: $e');
            // Continue anyway, maybe it was a transient error and we have a session now?
          }
        }
      }

      // 2. Trigger the appropriate cubit load
      if (mounted) {
        if (isLibraryTab) {
          context.read<LibraryCubit>().loadLibraries(
                _currentUser.serverUrl,
                _currentUser.id,
                _currentUser.accessToken,
              );
        } else {
          context.read<VideoCubit>().loadAllVideos(
                _currentUser.serverUrl,
                _currentUser.id,
                _currentUser.accessToken,
              );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

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
           final navigator = Navigator.of(context);
           if (navigator.canPop()) {
             navigator.pop();
           } 
        }
      },
      child: OrientationBuilder(
        builder: (context, orientation) {
          final size = MediaQuery.of(context).size;
          return Scaffold(
            extendBodyBehindAppBar: true,
            body: Container(
              width: size.width,
              height: size.height,
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
              child: _buildBody(context),
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                if (index == _currentIndex && index == 1 && _selectedLibrary != null) {
                   setState(() {
                     _selectedLibrary = null;
                   });
                } else {
                  setState(() {
                    _currentIndex = index;
                    if (index != 1) {
                      _selectedLibrary = null;
                    }
                  });
                }
              },
              backgroundColor: const Color(0xFF001116),
              selectedItemColor: accentBlue,
              unselectedItemColor: mutedIconColor,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w400),
              unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w400),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.library_books),
                  label: 'Library',
                ),
              ],
            ),
          );
        },
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
      create: (context) {
        final cubit = VideoCubit(context.read<VideoService>());
        if (widget.initialServerAvailable) {
          cubit.loadAllVideos(_currentUser.serverUrl, _currentUser.id, _currentUser.accessToken);
        } else {
          // Manually trigger error state if we already know server is down
          cubit.triggerError('SocketException: Video server not available');
        }
        return cubit;
      },
      child: Column(
        children: [
          // Header Banner
          SizedBox(
            height: 120, // Fixed height for header
            width: double.infinity,
            child: Stack(
              children: [
                // Header Image
                Positioned.fill(
                  child: Image.asset(
                    'assets/header.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF002B38), Color(0xFF00151C)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'RESURRECTION\nMINISTRIES',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Serif',
                                  letterSpacing: 1.2,
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
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
                  final isServerDown = state.message.toLowerCase().contains('socketexception') || 
                                     state.message.toLowerCase().contains('httpexception') ||
                                     state.message.toLowerCase().contains('connection refused');
                  
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
                          const SizedBox(height: 24),
                          Text(
                            isServerDown ? 'VIDEO SERVER NOT AVAILABLE' : 'UNABLE TO LOAD VIDEOS',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isServerDown 
                              ? 'Please check your internet connection or try again later.'
                              : 'An unexpected error occurred while fetching videos.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: _isRetrying ? null : () => _handleRetry(context, isLibraryTab: false),
                            icon: _isRetrying 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.refresh, color: Colors.white),
                            label: Text(_isRetrying ? 'RETRYING...' : 'RETRY CONNECTION', style: const TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B6DCC),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
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
                          style: GoogleFonts.poppins(
                            textStyle: Theme.of(context).textTheme.displaySmall,
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
                    style: GoogleFonts.poppins(
                      textStyle: Theme.of(context).textTheme.titleMedium,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600, // SemiBold
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
              style: GoogleFonts.poppins(
                textStyle: Theme.of(context).textTheme.headlineSmall,
                fontWeight: FontWeight.w600, // SemiBold
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isExpanded = _isExpanded[video.id] ?? false;
                final text = video.description.isNotEmpty ? video.description : 'No description available.';
                final textSpan = TextSpan(
                  text: text,
                  style: GoogleFonts.poppins(
                    textStyle: Theme.of(context).textTheme.bodyMedium,
                    color: Colors.white70,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                );

                final textPainter = TextPainter(
                  text: textSpan,
                  maxLines: 3,
                  textDirection: TextDirection.ltr,
                )..layout(maxWidth: constraints.maxWidth);

                final isTextOverflowing = textPainter.didExceedMaxLines;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text,
                      maxLines: isExpanded ? null : 3,
                      overflow: isExpanded ? null : TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        textStyle: Theme.of(context).textTheme.bodyMedium,
                        color: Colors.white70,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (isTextOverflowing)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _isExpanded[video.id] = !isExpanded;
                            });
                          },
                          child: Text(
                            isExpanded ? 'Show Less' : 'Read More...',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF3B6DCC),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
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
                      builder: (context) => VideoPlayerScreen(video: video, user: _currentUser),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow, color: Colors.white),
                label: Text(
                  'Watch Now',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold, // Bold
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
        user: _currentUser,
        library: _selectedLibrary!,
        onBack: () {
          setState(() {
            _selectedLibrary = null;
          });
        },
      );
    }

    return BlocProvider(
      create: (context) {
        final cubit = LibraryCubit(context.read<VideoService>());
        if (widget.initialServerAvailable) {
          cubit.loadLibraries(_currentUser.serverUrl, _currentUser.id, _currentUser.accessToken);
        } else {
          cubit.triggerError('SocketException: Video server not available');
        }
        return cubit;
      },
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
                      style: GoogleFonts.poppins(
                        textStyle: Theme.of(context).textTheme.headlineSmall,
                        fontWeight: FontWeight.bold,
                      ),
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
                  final isServerDown = state.message.toLowerCase().contains('socketexception') || 
                                     state.message.toLowerCase().contains('httpexception') ||
                                     state.message.toLowerCase().contains('connection refused');
                  
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off, size: 64, color: Colors.redAccent),
                          const SizedBox(height: 24),
                          Text(
                            isServerDown ? 'VIDEO SERVER NOT AVAILABLE' : 'UNABLE TO LOAD LIBRARIES',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isServerDown 
                              ? 'Please check your internet connection or try again later.'
                              : 'An unexpected error occurred while fetching your library.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: _isRetrying ? null : () => _handleRetry(context, isLibraryTab: true),
                            icon: _isRetrying 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.refresh, color: Colors.white),
                            label: Text(_isRetrying ? 'RETRYING...' : 'RETRY CONNECTION', style: const TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B6DCC),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
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
