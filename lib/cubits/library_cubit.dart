import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/library_model.dart';
import '../services/video_service.dart';

abstract class LibraryState {}
class LibraryInitial extends LibraryState {}
class LibraryLoading extends LibraryState {}
class LibraryLoaded extends LibraryState {
  final List<LibraryModel> libraries;
  LibraryLoaded(this.libraries);
}
class LibraryError extends LibraryState {
  final String message;
  LibraryError(this.message);
}

class LibraryCubit extends Cubit<LibraryState> {
  final VideoService _videoService;

  LibraryCubit(this._videoService) : super(LibraryInitial());

  Future<void> loadLibraries(String serverUrl, String userId, String accessToken) async {
    emit(LibraryLoading());
    try {
      final libraries = await _videoService.getUserViews(serverUrl, userId, accessToken);
      emit(LibraryLoaded(libraries));
    } catch (e) {
      emit(LibraryError(e.toString()));
    }
  }
}
