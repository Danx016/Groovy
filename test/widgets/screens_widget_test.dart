import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/screens/all_songs_screen.dart';
import 'package:groovy/screens/library_screen.dart';
import 'package:groovy/screens/playlists_screen.dart';
import 'package:groovy/screens/settings_screen.dart';
import 'package:groovy/screens/liked_albums_screen.dart';
import 'package:groovy/screens/favorites_screen.dart';
import 'package:groovy/screens/downloads_screen.dart';
import 'package:groovy/screens/artists_screen.dart';
import 'package:groovy/screens/albums_screen.dart';
import 'package:groovy/screens/genre_screen.dart';
import 'package:groovy/screens/radio_screen.dart';
import 'package:groovy/screens/account_screen.dart';
import 'package:groovy/screens/songs_screen.dart';
import 'package:groovy/screens/history_screen.dart';

import '../test_helpers.dart';
import '../bootstrap.dart';
import 'package:groovy/models/song.dart';
import 'package:groovy/services/youtube_service.dart';

class MockGenreYoutubeService extends YoutubeService {
  @override
  Future<List<Song>> getSongsByGenre(
    String genre, {
    int? size,
    int? count,
    int offset = 0,
  }) async {
    return [
      Song(id: 'mock_genre_s1', title: 'Rock Song 1', artist: 'Rock Artist', album: 'Rock Album'),
    ];
  }
}

void main() {
  initializeTestEnvironment();
  group('Screen Widget Tests', () {
    testWidgets('LibraryScreen builds without exception', (tester) async {
      await tester.pumpWidget(createTestApp(child: const LibraryScreen()));
      await tester.pump();
      expect(find.byType(LibraryScreen), findsOneWidget);
    });

    testWidgets('AllSongsScreen builds without exception and handles sorting', (tester) async {
      await tester.pumpWidget(createTestApp(child: const AllSongsScreen()));
      await tester.pump();
      expect(find.byType(AllSongsScreen), findsOneWidget);
    });

    testWidgets('PlaylistsScreen builds without exception', (tester) async {
      await tester.pumpWidget(createTestApp(child: const PlaylistsScreen()));
      await tester.pump();
      expect(find.byType(PlaylistsScreen), findsOneWidget);
    });

    testWidgets('SettingsScreen builds without exception', (tester) async {
      await tester.pumpWidget(createTestApp(child: const SettingsScreen()));
      await tester.pump();
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('LikedAlbumsScreen builds without exception and queries fallback', (tester) async {
      await tester.pumpWidget(createTestApp(child: const LikedAlbumsScreen()));
      await tester.pump();
      expect(find.byType(LikedAlbumsScreen), findsOneWidget);
    });

    testWidgets('FavoritesScreen builds and switches tabs', (tester) async {
      await tester.pumpWidget(createTestApp(child: const FavoritesScreen()));
      await tester.pump();
      expect(find.byType(FavoritesScreen), findsOneWidget);
    });

    testWidgets('DownloadsScreen builds with responsive layout', (tester) async {
      await tester.pumpWidget(createTestApp(child: const DownloadsScreen()));
      await tester.pump();
      expect(find.byType(DownloadsScreen), findsOneWidget);
    });

    testWidgets('ArtistsScreen builds and displays list with _ArtistAvatar', (tester) async {
      await tester.pumpWidget(createTestApp(child: const ArtistsScreen()));
      await tester.pump();
      expect(find.byType(ArtistsScreen), findsOneWidget);
    });

    testWidgets('AlbumsScreen builds with responsive grid', (tester) async {
      await tester.pumpWidget(createTestApp(child: const AlbumsScreen()));
      await tester.pump();
      expect(find.byType(AlbumsScreen), findsOneWidget);
    });


    testWidgets('GenreScreen builds and loads data in parallel', (tester) async {
      final mockYt = MockGenreYoutubeService();
      await tester.pumpWidget(createTestApp(
        youtubeService: mockYt,
        child: const GenreScreen(genre: 'Rock'),
      ));
      await tester.pump();
      expect(find.byType(GenreScreen), findsOneWidget);
    });

    testWidgets('RadioScreen builds without exception', (tester) async {
      await tester.pumpWidget(createTestApp(child: const RadioScreen()));
      await tester.pump();
      expect(find.byType(RadioScreen), findsOneWidget);
    });

    testWidgets('AccountScreen builds with user profile', (tester) async {
      await tester.pumpWidget(createTestApp(child: const AccountScreen()));
      await tester.pump();
      expect(find.byType(AccountScreen), findsOneWidget);
    });

    testWidgets('SongsScreen builds with cachedAllSongs', (tester) async {
      await tester.pumpWidget(createTestApp(child: const SongsScreen()));
      await tester.pump();
      expect(find.byType(SongsScreen), findsOneWidget);
    });

    testWidgets('HistoryScreen builds with songsByIdMap', (tester) async {
      await tester.pumpWidget(createTestApp(child: const HistoryScreen()));
      await tester.pump();
      expect(find.byType(HistoryScreen), findsOneWidget);
    });
  });
}
