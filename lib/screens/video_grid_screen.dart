import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/user_model.dart';
import '../models/library_model.dart';
import '../cubits/video_cubit.dart';
import '../services/video_service.dart';
import '../widgets/video_tile.dart';

class VideoGridScreen extends StatelessWidget {
  final User user;
  final LibraryModel library;
  final VoidCallback? onBack;

  const VideoGridScreen({
    Key? key,
    required this.user,
    required this.library,
    this.onBack,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => VideoCubit(context.read<VideoService>())
        ..loadLibraryVideos(user.serverUrl, library.id, user.accessToken),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: onBack != null 
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: onBack,
                )
              : null, // Default behavior if no callback (e.g. if used with Navigator.push)
          title: Text(
            library.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        body: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
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
          child: SafeArea(
            top: false, // Let content flow under transparent AppBar, but Grid needs padding
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
                          onPressed: () => context.read<VideoCubit>().loadLibraryVideos(
                                user.serverUrl,
                                library.id,
                                user.accessToken,
                              ),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B6DCC)),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                } else if (state is VideoLoaded) {
                  if (state.videos.isEmpty) {
                    return const Center(child: Text('No videos found in this library.', style: TextStyle(color: Colors.white70)));
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 100, 16, 16), // Top padding for AppBar
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.85, // Adjusted for taller cards
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: state.videos.length,
                    itemBuilder: (context, index) {
                      return VideoTile(video: state.videos[index], user: user);
                    },
                  );
                }
                return const Center(child: Text('Loading videos...', style: TextStyle(color: Colors.white70)));
              },
            ),
          ),
        ),
      ),
    );
  }
}
