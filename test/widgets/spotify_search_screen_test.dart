import 'package:flutter_test/flutter_test.dart';
import 'package:groovy/screens/search_screen.dart';
import 'package:groovy/services/recent_searches_service.dart';
import 'package:groovy/models/song.dart';
import 'package:groovy/models/artist.dart';
import 'package:groovy/models/album.dart';
import '../test_helpers.dart';
import '../bootstrap.dart';

void main() {
  initializeTestEnvironment();

  testWidgets('SearchScreen renders Spotify style search bar and filter pills', (tester) async {
    final recentSearches = RecentSearchesService();
    recentSearches.addSong(Song(id: 's1', title: 'Indira', artist: 'Los Hermanos Zuleta'));
    recentSearches.addArtist(Artist(id: 'a1', name: 'Los Hermanos Zuleta'));
    recentSearches.addAlbum(Album(id: 'al1', name: 'Grandes Exitos', artist: 'Los Hermanos Zuleta'));

    await tester.pumpWidget(createTestApp(child: const SearchScreen()));
    await tester.pumpAndSettle();

    // Verify search title & search input
    expect(find.text('Buscar'), findsOneWidget);
    expect(find.text('Artistas, canciones, álbumes...'), findsOneWidget);

    // Verify recent searches with Spotify format
    expect(find.text('Indira'), findsOneWidget);
    expect(find.text('Canción • Los Hermanos Zuleta'), findsOneWidget);
    expect(find.text('Artista'), findsOneWidget);
    expect(find.text('Álbum • Los Hermanos Zuleta'), findsOneWidget);
  });
}
