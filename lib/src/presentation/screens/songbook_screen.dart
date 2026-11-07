import 'package:flutter/material.dart';

import '../../data/repositories/device_settings_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/song.dart';
import '../../domain/ids.dart';
import '../../domain/rota/family_editor.dart';
import '../brand/tokens.dart';
import '../widgets/centred_message.dart';
import '../widgets/date_text.dart';

/// The songs this family loves, and who chose them (#110, R7.1).
///
/// **The first screen in the app that is deliberately shared.** The rota is
/// shared because it must be; the journal is private by requirement (R4.2)
/// and says so on itself. This is neither — it is shared because that is the
/// point of it, and sitting two tabs from the journal it has to say so
/// plainly or somebody will write something here thinking it is private.
///
/// It stores **text**: a title, who it is by, who chose it, and a link. That
/// is why it could be built now and photographs could not — fifty songs are
/// smaller than one photograph, so it rides the family document and touches
/// no clause of ADR-010.
class SongbookScreen extends StatefulWidget {
  const SongbookScreen({
    required this.familyRepository,
    required this.settings,
    required this.ids,
    this.today,
    super.key,
  });

  final FamilyRepository familyRepository;
  final DeviceSettingsRepository settings;
  final IdGenerator ids;
  final CalendarDate Function()? today;

  static const Key addSong = Key('songbook.add');
  static const Key titleField = Key('songbook.add.title');
  static const Key performerField = Key('songbook.add.performer');
  static const Key confirmAdd = Key('songbook.add.confirm');
  static const Key everyoneSees = Key('songbook.everyoneSees');

  static Key rowFor(String songId) => Key('songbook.row.$songId');
  static Key removeFor(String songId) => Key('songbook.remove.$songId');

  @override
  State<SongbookScreen> createState() => _SongbookScreenState();
}

class _SongbookScreenState extends State<SongbookScreen> {
  late final Stream<Family?> _families = widget.familyRepository.watch();
  late final Stream<String?> _youAre = widget.settings.watchYouAre();

  String? _message;

  CalendarDate get _today =>
      widget.today?.call() ?? CalendarDate.from(DateTime.now());

  Future<void> _add(Family family, String youAre) async {
    final _NewSong? song = await showDialog<_NewSong>(
      context: context,
      builder: (BuildContext context) => const _AddSongDialog(),
    );
    if (song == null) {
      return;
    }

    try {
      await widget.familyRepository.save(
        FamilyEditor.addSong(
          family,
          title: song.title,
          performer: song.performer,
          addedBy: youAre,
          today: _today,
          ids: widget.ids,
        ),
      );
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(() => _message = error.message.toString());
      }
    }
  }

  Future<void> _remove(Family family, Song song) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Take "${song.title}" out of the songbook?'),
        content: const Text('It goes for everyone, not just on this phone.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Take it out'),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) {
      return;
    }
    await widget.familyRepository.save(
      FamilyEditor.removeSong(family, songId: song.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Songs we love')),
      body: SafeArea(
        child: StreamBuilder<Family?>(
          stream: _families,
          builder: (BuildContext context, AsyncSnapshot<Family?> stored) {
            final Family? family = stored.data;
            if (family == null) {
              return CentredMessage(
                children: <Widget>[
                  Text(
                    'Set the rota up first',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    'The songbook belongs to the family, so the app needs to '
                    'know who that is.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              );
            }

            return StreamBuilder<String?>(
              stream: _youAre,
              builder: (BuildContext context, AsyncSnapshot<String?> who) =>
                  _book(theme, family, who.data),
            );
          },
        ),
      ),
    );
  }

  Widget _book(ThemeData theme, Family family, String? youAre) {
    final List<Song> songs = FamilyEditor.songbook(family);
    final Map<String, Member> byId = family.membersById;

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxl),
      children: <Widget>[
        Padding(
          key: SongbookScreen.everyoneSees,
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.lg,
            Space.lg,
            Space.md,
          ),
          child: Text(
            // Said at the top, not the bottom. The journal one tab away is
            // private by requirement, and somebody who has learned that
            // about this app will assume it here unless told otherwise.
            'Everyone in the family sees this book. Your journal is the '
            'private one.',
            style: theme.textTheme.bodyMedium,
          ),
        ),

        if (songs.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.xl,
              Space.lg,
              Space.lg,
            ),
            child: Text(
              'No songs yet. Add the one your family always comes back to.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          for (final Song song in songs)
            ListTile(
              key: SongbookScreen.rowFor(song.id),
              title: Text(song.title),
              subtitle: Text(_who(byId, song)),
              isThreeLine: false,
              trailing: IconButton(
                key: SongbookScreen.removeFor(song.id),
                icon: const Icon(Icons.close),
                tooltip: 'Take "${song.title}" out of the songbook',
                onPressed: () => _remove(family, song),
              ),
            ),

        if (_message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.lg, 0),
            child: Text(
              _message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),

        const SizedBox(height: Space.lg),
        Padding(
          padding: Space.gutter,
          child: youAre == null
              // A song records who chose it, so the app has to know which
              // person this phone belongs to. Said rather than disabled
              // without explanation.
              ? Text(
                  'Say which one you are in Settings, and you can add a '
                  'song — the book records who chose each one.',
                  style: theme.textTheme.bodySmall,
                )
              : OutlinedButton.icon(
                  key: SongbookScreen.addSong,
                  onPressed: () => _add(family, youAre),
                  icon: const Icon(Icons.add),
                  label: const Text('Add a song'),
                ),
        ),
      ],
    );
  }

  String _who(Map<String, Member> byId, Song song) {
    final String chooser =
        byId[song.addedBy]?.displayName ?? 'somebody who has left';
    final String when = DateLabels.dayAndDate(context, song.addedOn);
    return song.performer == null
        ? '$chooser · $when'
        : '${song.performer} · $chooser · $when';
  }
}

/// What the dialog returns.
class _NewSong {
  const _NewSong({required this.title, this.performer});

  final String title;
  final String? performer;
}

class _AddSongDialog extends StatefulWidget {
  const _AddSongDialog();

  @override
  State<_AddSongDialog> createState() => _AddSongDialogState();
}

class _AddSongDialogState extends State<_AddSongDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _performer = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _performer.dispose();
    super.dispose();
  }

  void _submit() {
    final String title = _title.text.trim();
    if (title.isEmpty) {
      return;
    }
    Navigator.of(context)
        .pop(_NewSong(title: title, performer: _performer.text.trim()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add a song'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          key: SongbookScreen.titleField,
          controller: _title,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'The song'),
        ),
        const SizedBox(height: Space.lg),
        TextField(
          key: SongbookScreen.performerField,
          controller: _performer,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Who sings it (if you know)',
          ),
          onSubmitted: (_) => _submit(),
        ),
      ],
    ),
    actions: <Widget>[
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _title,
        builder: (BuildContext context, TextEditingValue value, _) =>
            TextButton(
              key: SongbookScreen.confirmAdd,
              onPressed: value.text.trim().isEmpty ? null : _submit,
              child: const Text('Add'),
            ),
      ),
    ],
  );
}
