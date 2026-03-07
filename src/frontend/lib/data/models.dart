// ─── Song ──────────────────────────────────────────────────────────────────
class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? albumArtUrl;
  final Duration duration;
  final String? streamUrl;
  final String? serverId; // null = local
  final DateTime? lastPlayed;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtUrl,
    required this.duration,
    this.streamUrl,
    this.serverId,
    this.lastPlayed,
  });

  String get durationString {
    final m = duration.inMinutes;
    final s = duration.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id']?.toString() ?? '',
        title: json['title'] ?? 'Unknown',
        artist: json['artist'] ?? 'Unknown Artist',
        album: json['album'] ?? '',
        albumArtUrl: json['coverArt'],
        duration: Duration(seconds: json['duration'] ?? 0),
        streamUrl: json['streamUrl'],
        serverId: json['serverId'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'albumArtUrl': albumArtUrl,
        'duration': duration.inSeconds,
        'streamUrl': streamUrl,
        'serverId': serverId,
      };
}

// ─── Playlist ──────────────────────────────────────────────────────────────
class Playlist {
  final String id;
  String name;
  String? description;
  String? coverArtUrl;
  List<Song> songs;
  final bool isServer;
  final String? serverId;
  DateTime? lastPlayed;
  final DateTime createdAt;

  Playlist({
    required this.id,
    required this.name,
    this.description,
    this.coverArtUrl,
    List<Song>? songs,
    this.isServer = false,
    this.serverId,
    this.lastPlayed,
    DateTime? createdAt,
  })  : songs = songs ?? [],
        createdAt = createdAt ?? DateTime.now();

  int get songCount => songs.length;

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id']?.toString() ?? '',
        name: json['name'] ?? 'Untitled',
        description: json['description'],
        coverArtUrl: json['coverArt'],
        isServer: json['isServer'] ?? false,
        serverId: json['serverId'],
        lastPlayed: json['lastPlayed'] != null
            ? DateTime.tryParse(json['lastPlayed'])
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'coverArtUrl': coverArtUrl,
        'isServer': isServer,
        'serverId': serverId,
        'lastPlayed': lastPlayed?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };
}

// ─── Server ────────────────────────────────────────────────────────────────
enum ServerType { subsonic, navidrome, jellyfin, emby }

enum ServerStatus { unknown, online, offline, error }

class MusicServer {
  final String id;
  String name;
  String url;
  String? username;
  String? password;
  ServerType type;
  ServerStatus status;
  int? songCount;
  DateTime? lastSynced;

  MusicServer({
    required this.id,
    required this.name,
    required this.url,
    this.username,
    this.password,
    this.type = ServerType.navidrome,
    this.status = ServerStatus.unknown,
    this.songCount,
    this.lastSynced,
  });

  String get typeLabel {
    switch (type) {
      case ServerType.navidrome:
        return 'Navidrome';
      case ServerType.subsonic:
        return 'Subsonic';
      case ServerType.jellyfin:
        return 'Jellyfin';
      case ServerType.emby:
        return 'Emby';
    }
  }

  factory MusicServer.fromJson(Map<String, dynamic> json) => MusicServer(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        url: json['url'] ?? '',
        username: json['username'],
        type: ServerType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => ServerType.navidrome,
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'username': username,
        'type': type.name,
      };
}

// ─── Search Result ─────────────────────────────────────────────────────────
enum SearchResultType { song, album, artist, playlist }

class SearchResult {
  final SearchResultType type;
  final String id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final dynamic data; // Original object

  const SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.data,
  });
}

// ─── Player State ──────────────────────────────────────────────────────────
enum RepeatMode { none, one, all }

enum ShuffleMode { off, on }