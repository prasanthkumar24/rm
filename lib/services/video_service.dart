import 'package:flutter/foundation.dart';
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
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['Items'] ?? [];
        return items.map((item) => LibraryModel.fromJson(item)).toList();
      } else {
        throw Exception('Failed to load libraries: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching libraries: $e');
      rethrow;
    }
  }

  Future<List<VideoModel>> getLibraryItems(String serverUrl, String parentId, String accessToken) async {
    // Broadened IncludeItemTypes to support Movies, Episodes, and generic Videos
    // Added MediaSources to determine if Direct Play (Static Stream) is possible
    final url = Uri.parse('$serverUrl/Items?ParentId=$parentId&IncludeItemTypes=Movie,Video,Episode&Fields=Overview,RunTimeTicks,Taglines,MediaSources&Recursive=true&api_key=$accessToken');
    
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['Items'] ?? [];
        
        return items.map((item) {
          final String id = item['Id'];
          final String title = item['Name'] ?? 'Unknown Title';
          String description = item['Overview'] ?? '';
          
          if (description.isEmpty && item['Taglines'] != null && (item['Taglines'] as List).isNotEmpty) {
             description = (item['Taglines'] as List).join('. ');
          }
          
          final String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
          
          // Using a placeholder URL for lists, but the actual playback URL 
          // will be determined in VideoPlayerScreen using getPlaybackUrl
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
      debugPrint('Error fetching items: $e');
      rethrow;
    }
  }

  Future<List<VideoModel>> getAllVideos(String serverUrl, String userId, String accessToken) async {
    // Fetch all recursive items for the user (Movies, Episodes, Videos)
    // Added MediaSources to determine if Direct Play (Static Stream) is possible
    final url = Uri.parse('$serverUrl/Users/$userId/Items?IncludeItemTypes=Movie,Video,Episode&Recursive=true&SortBy=DateCreated&SortOrder=Descending&Fields=Overview,RunTimeTicks,Taglines,MediaSources&api_key=$accessToken');
    
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> items = data['Items'] ?? [];
        
        return items.map((item) {
          final String id = item['Id'];
          final String title = item['Name'] ?? 'Unknown Title';
          String description = item['Overview'] ?? '';
          
          if (description.isEmpty && item['Taglines'] != null && (item['Taglines'] as List).isNotEmpty) {
             description = (item['Taglines'] as List).join('. ');
          }
          
          final String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
          
          // Using a placeholder URL for lists, but the actual playback URL 
          // will be determined in VideoPlayerScreen using getPlaybackUrl
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
        throw Exception('Failed to load videos: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching videos: $e');
      rethrow;
    }
  }

  Future<String> getPlaybackUrl(String serverUrl, String itemId, String accessToken, String userId) async {
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
            'MaxStreamingBitrate': 20000000,
            'MusicStreamingTranscodingBitrate': 192000,
            'DirectPlayProfiles': [
              {'Container': 'mp4', 'Type': 'Video', 'VideoCodec': 'h264', 'AudioCodec': 'aac'}
            ],
            'TranscodingProfiles': []
          }
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> mediaSources = data['MediaSources'] ?? [];
        
        if (mediaSources.isEmpty) {
          throw Exception('No media sources found');
        }

        Map<String, dynamic>? directMp4Source;
        for (final src in mediaSources) {
          final container = (src['Container'] ?? '').toString().toLowerCase();
          final supportsDirectPlay = src['SupportsDirectPlay'] == true;
          if (container == 'mp4' && supportsDirectPlay) {
            final streams = (src['MediaStreams'] as List<dynamic>? ?? []);
            final hasH264 = streams.any((s) =>
                (s['Type'] ?? '') == 'Video' &&
                (s['Codec'] ?? '').toString().toLowerCase() == 'h264');
            final hasAac = streams.any((s) =>
                (s['Type'] ?? '') == 'Audio' &&
                (s['Codec'] ?? '').toString().toLowerCase() == 'aac');
            if (hasH264 && hasAac) {
              directMp4Source = Map<String, dynamic>.from(src);
              break;
            }
          }
        }

        if (directMp4Source != null) {
          final String mediaSourceId = directMp4Source['Id'];
          final String finalUrl = '$serverUrl/Videos/$itemId/stream'
              '?static=true'
              '&MediaSourceId=$mediaSourceId'
              '&api_key=$accessToken';
          debugPrint('Direct Play URL generated: $finalUrl');
          return finalUrl;
        }

        // Fallback to server-decided manifest without forcing codecs/bitrates
        final fallbackSource = mediaSources.first;
        final String mediaSourceId = fallbackSource['Id'];
        final String fallbackUrl = '$serverUrl/Videos/$itemId/master.m3u8'
            '?MediaSourceId=$mediaSourceId'
            '&api_key=$accessToken';
        debugPrint('Direct Play not possible, fallback to HLS: $fallbackUrl');
        return fallbackUrl;
      } else {
        throw Exception('Failed to get playback info: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting playback URL: $e');
      return '$serverUrl/Videos/$itemId/master.m3u8?MediaSourceId=$itemId&api_key=$accessToken';
    }
  }

  Future<String> getQualityPlaybackUrl({
    required String serverUrl,
    required String itemId,
    required String accessToken,
    required String userId,
    required String quality, // '240p','360p','480p','720p','1080p'
  }) async {
    final playbackInfoUrl = Uri.parse('$serverUrl/Items/$itemId/PlaybackInfo?UserId=$userId');
    int maxWidth = 854;
    int maxHeight = 480;
    int videoBitrate = 1500000;
    switch (quality) {
      case '240p':
        maxWidth = 426; maxHeight = 240; videoBitrate = 400000;
        break;
      case '360p':
        maxWidth = 640; maxHeight = 360; videoBitrate = 800000;
        break;
      case '480p':
        maxWidth = 854; maxHeight = 480; videoBitrate = 1500000;
        break;
      case '720p':
        maxWidth = 1280; maxHeight = 720; videoBitrate = 3000000;
        break;
      case '1080p':
        maxWidth = 1920; maxHeight = 1080; videoBitrate = 6000000;
        break;
    }

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
            'MaxStreamingBitrate': videoBitrate,
            'TranscodingProfiles': [
              {
                'Container': 'ts',
                'Type': 'Video',
                'AudioCodec': 'aac',
                'VideoCodec': 'h264',
                'Context': 'Streaming',
                'Protocol': 'hls'
              }
            ]
          },
          'DirectPlayProfiles': [],
          'EnableDirectPlay': false,
          'EnableDirectStream': false,
          'MaxAudioChannels': 2,
          'SupportsDirectPlay': false,
          'SupportsDirectStream': false,
          'SupportsTranscoding': true,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> mediaSources = data['MediaSources'] ?? [];
        if (mediaSources.isEmpty) {
          throw Exception('No media sources found');
        }
        final mediaSourceId = mediaSources.first['Id'];
        return '$serverUrl/Videos/$itemId/master.m3u8'
            '?MediaSourceId=$mediaSourceId'
            '&api_key=$accessToken'
            '&VideoCodec=h264'
            '&AudioCodec=aac'
            '&VideoBitrate=$videoBitrate'
            '&MaxWidth=$maxWidth'
            '&MaxHeight=$maxHeight'
            '&TranscodingContainer=ts'
            '&SegmentContainer=ts';
      } else {
        throw Exception('Failed to get playback info: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting quality URL: $e');
      return '$serverUrl/Videos/$itemId/master.m3u8?MediaSourceId=$itemId&api_key=$accessToken';
    }
  }
}
