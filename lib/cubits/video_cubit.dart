import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/video_model.dart';
import '../services/video_service.dart';

// States
abstract class VideoState extends Equatable {
  const VideoState();
  @override
  List<Object> get props => [];
}

class VideoInitial extends VideoState {}

class VideoLoading extends VideoState {}

class VideoLoaded extends VideoState {
  final List<VideoModel> videos;
  const VideoLoaded(this.videos);
  @override
  List<Object> get props => [videos];
}

class VideoError extends VideoState {
  final String message;
  const VideoError(this.message);
  @override
  List<Object> get props => [message];
}

// Cubit
class VideoCubit extends Cubit<VideoState> {
  final VideoService _videoService;

  VideoCubit(this._videoService) : super(VideoInitial());

  Future<void> loadLibraryVideos(String serverUrl, String parentId, String accessToken) async {
    emit(VideoLoading());
    try {
      final videos = await _videoService.getLibraryItems(serverUrl, parentId, accessToken);
      emit(VideoLoaded(videos));
    } catch (e) {
      emit(VideoError(e.toString()));
    }
  }

  Future<void> loadAllVideos(String serverUrl, String userId, String accessToken) async {
    emit(VideoLoading());
    try {
      final videos = await _videoService.getAllVideos(serverUrl, userId, accessToken);
      emit(VideoLoaded(videos));
    } catch (e) {
      emit(VideoError(e.toString()));
    }
  }
}
