import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';
import '../../services/theme_service.dart';
import '../../l10n/app_localizations.dart';

class NowPlayingMoreMenu extends StatelessWidget {
  const NowPlayingMoreMenu({super.key});

  void _setSleepTimer(BuildContext context, int minutes, PlayerProvider provider) {
    if (minutes == 0) {
      provider.setSleepTimer(Duration.zero, endCurrentSong: false);
    } else if (minutes == -1) {
      provider.setSleepTimer(Duration.zero, endCurrentSong: true);
    } else {
      provider.setSleepTimer(Duration(minutes: minutes), endCurrentSong: false);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context, listen: false);
    final platformDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final isDark = themeService.themeMode == ThemeMode.dark ||
        (themeService.themeMode == ThemeMode.system && platformDark);

    final bgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final subtitleColor = isDark ? Colors.white60 : Colors.black54;
    final iconColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final dividerColor = isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08);

    return Theme(
      data: isDark ? ThemeData.dark() : ThemeData.light(),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.only(bottom: 32, top: 16),
        child: Consumer<PlayerProvider>(
          builder: (context, provider, child) {
            final sleepTimerRemaining = provider.sleepTimerRemaining;
            final sleepTimerEndCurrentSong = provider.sleepTimerEndCurrentSong;
            
            String sleepTimerText = "Off";
            if (sleepTimerEndCurrentSong) {
              sleepTimerText = AppLocalizations.of(context)!.endOfSong;
            } else if (sleepTimerRemaining != null) {
              final minutes = sleepTimerRemaining.inMinutes;
              final seconds = (sleepTimerRemaining.inSeconds % 60).toString().padLeft(2, '0');
              sleepTimerText = "$minutes:$seconds";
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Sleep Timer Section
                ListTile(
                  leading: Icon(Icons.timer_outlined, color: iconColor),
                  title: Text(
                    AppLocalizations.of(context)!.sleepTimer,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sleepTimerText,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right_rounded, color: subtitleColor),
                    ],
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        backgroundColor: bgColor,
                        title: Text(
                          AppLocalizations.of(context)!.sleepTimer,
                          style: TextStyle(color: textColor),
                        ),
                        children: [
                          SimpleDialogOption(
                            child: Text("Off", style: TextStyle(color: textColor)),
                            onPressed: () => _setSleepTimer(context, 0, provider),
                          ),
                          SimpleDialogOption(
                            child: Text(AppLocalizations.of(context)!.sleepTimerMinutes(5), style: TextStyle(color: textColor)),
                            onPressed: () => _setSleepTimer(context, 5, provider),
                          ),
                          SimpleDialogOption(
                            child: Text(AppLocalizations.of(context)!.sleepTimerMinutes(10), style: TextStyle(color: textColor)),
                            onPressed: () => _setSleepTimer(context, 10, provider),
                          ),
                          SimpleDialogOption(
                            child: Text(AppLocalizations.of(context)!.sleepTimerMinutes(15), style: TextStyle(color: textColor)),
                            onPressed: () => _setSleepTimer(context, 15, provider),
                          ),
                          SimpleDialogOption(
                            child: Text(AppLocalizations.of(context)!.sleepTimerMinutes(30), style: TextStyle(color: textColor)),
                            onPressed: () => _setSleepTimer(context, 30, provider),
                          ),
                          SimpleDialogOption(
                            child: Text(AppLocalizations.of(context)!.endOfSong, style: TextStyle(color: textColor)),
                            onPressed: () => _setSleepTimer(context, -1, provider),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Divider(indent: 56, color: dividerColor),

                // Speed Dial Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Velocità Riproduzione", style: TextStyle(fontSize: 16, color: textColor)),
                          Text(
                            "${provider.playbackSpeed.toStringAsFixed(2)}x",
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: provider.playbackSpeed,
                        min: 0.5,
                        max: 2.0,
                        divisions: 6, // 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0
                        onChanged: (val) {
                          provider.setPlaybackSpeed(val);
                        },
                      ),
                    ],
                  ),
                ),

                // Pitch Correction Section
                SwitchListTile(
                  secondary: Icon(Icons.music_note_rounded, color: iconColor),
                  title: Text("Mantieni Pitch originale", style: TextStyle(color: textColor)),
                  subtitle: Text("Mantiene il tono inalterato quando cambi velocità", style: TextStyle(color: subtitleColor)),
                  value: provider.pitchCorrection,
                  onChanged: (val) {
                    provider.togglePitchCorrection();
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
