import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video_model.dart';
import '../models/library_model.dart';

class VideoService {
  
  Future<List<LibraryModel>> getUserViews(String serverUrl, String userId, String accessToken) async {
    final url = Uri.parse('$serverUrl/Users/$userId/Views');
    
    try {
      final response = await http.get(
        url,
        headers: {'X-Emby-Token': accessToken},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['Items'] ?? [];
        return items.map((item) => LibraryModel.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load libraries: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching libraries: $e');
      rethrow;
    }
  }

  Future<List<VideoModel>> getLibraryItems(String serverUrl, String parentId, String accessToken) async {
    // Broadened IncludeItemTypes to support Movies, Episodes, and generic Videos
    final url = Uri.parse('$serverUrl/Items?ParentId=$parentId&IncludeItemTypes=Movie,Video,Episode&Fields=Overview,RunTimeTicks&Recursive=true&api_key=$accessToken');
    
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['Items'] ?? [];
        
        return items.map((item) {
          final String id = item['Id'];
          final String title = item['Name'] ?? 'Unknown Title';
          final String description = item['Overview'] ?? '';
          
          // HLS URL (Fallback/Quick)
          // We will generate a more robust one in VideoPlayerScreen using getPlaybackUrl
          final String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
          final String videoStreamUrl = '$serverUrl/Videos/$id/master.m3u8?MediaSourceId=$id&PlaySessionId=$sessionId&api_key=$accessToken';
          
          // Thumbnail URL
          final String thumbUrl = '$serverUrl/Items/$id/Images/Primary?api_key=$accessToken';
          
          // Duration
          final int runTimeTicks = item['RunTimeTicks'] ?? 0;
          final duration = Duration(microseconds: runTimeTicks ~/ 10);

          return VideoModel(
            id: id,
            title: title,
            description: description,
            videoUrl: videoStreamUrl,
            thumbnailUrl: thumbUrl,
            duration: duration,
          );
        }).toList();
      } else {
        throw Exception('Failed to load items: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching items: $e');
      rethrow;
    }
  }

  Future<List<VideoModel>> getAllVideos(String serverUrl, String userId, String accessToken) async {
    // Fetch all recursive items for the user (Movies, Episodes, Videos)
    // Sort by DateCreated descending to show latest first
    final url = Uri.parse('$serverUrl/Users/$userId/Items?IncludeItemTypes=Movie,Video,Episode&Recursive=true&SortBy=DateCreated&SortOrder=Descending&Fields=Overview,RunTimeTicks&api_key=$accessToken');
    
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['Items'] ?? [];
        
        return items.map((item) {
          final String id = item['Id'];
          final String title = item['Name'] ?? 'Unknown Title';
          final String description = item['Overview'] ?? '';
          
          // HLS URL (Fallback/Quick)
          final String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
          final String videoStreamUrl = '$serverUrl/Videos/$id/master.m3u8?MediaSourceId=$id&PlaySessionId=$sessionId&api_key=$accessToken';
          
          // Thumbnail URL
          final String thumbUrl = '$serverUrl/Items/$id/Images/Primary?api_key=$accessToken';
          
          // Duration
          final int runTimeTicks = item['RunTimeTicks'] ?? 0;
          final duration = Duration(microseconds: runTimeTicks ~/ 10);

          return VideoModel(
            id: id,
            title: title,
            description: description,
            videoUrl: videoStreamUrl,
            thumbnailUrl: thumbUrl,
            duration: duration,
          );
        }).toList();
      } else {
        throw Exception('Failed to load all videos: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching all videos: $e');
      rethrow;
    }
  }

  Future<String> getPlaybackUrl(String serverUrl, String itemId, String accessToken, String userId) async {
    // 1. Call PlaybackInfo to get MediaSourceId and capabilities
    final playbackInfoUrl = Uri.parse('$serverUrl/Items/$itemId/PlaybackInfo?UserId=$userId');
    
    try {
      final response = await http.post(
        playbackInfoUrl,
        headers: {
          'X-Emby-Token': accessToken,
          'Content-Type': 'application/json',
          'X-Emby-Authorization': 'MediaBrowser Client="FlutterApp", Device="FlutterApp", DeviceId="flutter_app_id", Version="1.0.0"',
        },
        body: json.encode({
          'DeviceProfile': {
            'MaxStreamingBitrate': 140000000,
            'MusicStreamingTranscodingBitrate': 192000,
            'DirectPlayProfiles': [
              {'Container': 'mp4,m4v', 'Type': 'Video', 'VideoCodec': 'h264,hevc,vp9,av1', 'AudioCodec': 'aac,mp3,opus,flac,vorbis'},
              {'Container': 'mkv', 'Type': 'Video', 'VideoCodec': 'h264,hevc,vp9,av1', 'AudioCodec': 'aac,mp3,opus,flac,vorbis'}
            ],
            'TranscodingProfiles': [
              {
                'Container': 'ts',
                'Type': 'Video',
                'AudioCodec': 'aac,mp3,opus',
                'VideoCodec': 'h264',
                'Context': 'Streaming',
                'Protocol': 'hls'
              }
            ]
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> mediaSources = data['MediaSources'] ?? [];
        
        if (mediaSources.isEmpty) {
          throw Exception('No media sources found');
        }

        final mediaSource = mediaSources.first;
        final String mediaSourceId = mediaSource['Id'];
        final String playSessionId = data['PlaySessionId'] ?? DateTime.now().millisecondsSinceEpoch.toString();
        
        // Construct the HLS URL with all necessary parameters
        // Optimized for mobile streaming: H.264, AAC, 8Mbps video, 192kbps audio, 30fps
        return '$serverUrl/Videos/$itemId/master.m3u8'
            '?MediaSourceId=$mediaSourceId'
            '&PlaySessionId=$playSessionId'
            '&api_key=$accessToken'
            '&VideoCodec=h264'
            '&AudioCodec=aac'
            '&VideoBitrate=8000000'
            '&AudioBitrate=192000'
            '&MaxFramerate=30'
            '&TranscodingContainer=ts'
            '&SegmentContainer=ts'
            '&MinSegments=1'
            '&BreakOnNonKeyFrames=True'
            '&ManifestSubtitles=vtt'; // Request subtitles in manifest if available
      } else {
        throw Exception('Failed to get playback info: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting playback URL: $e');
      // Fallback to simple URL if PlaybackInfo fails
      return '$serverUrl/Videos/$itemId/master.m3u8?MediaSourceId=$itemId&api_key=$accessToken';
    }
  }
}
