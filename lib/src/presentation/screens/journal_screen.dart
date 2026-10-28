import 'package:flutter/material.dart';

import '../../data/repositories/journal_repository.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/journal_entry.dart';
import '../widgets/date_text.dart';
import 'write_entry_screen.dart';

/// What you prayed about, looking back.
///
/// Grouped by month and newest first (R4.3), because a journal is read from
/// the near end: the entry somebody wants is almost always a recent one.
class JournalScreen extends StatefulWidget {
  const JournalScreen({required this.journal, this.today, super.key});

  final JournalRepository journal;
  final CalendarDate Function()? today;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  late final Stream<List<JournalEntry>> _entries = widget.journal.watch();

  CalendarDate get _today =>
      widget.today?.call() ?? CalendarDate.from(DateTime.now());

  Future<void> _write(JournalEntry? existing) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => WriteEntryScreen(
          journal: widget.journal,
          date: existing?.date ?? _today,
          existing: existing,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _write(null),
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Write'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<JournalEntry>>(
          stream: _entries,
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<JournalEntry>> snapshot,
              ) {
                final List<JournalEntry>? entries = snapshot.data;
                if (entries == null) {
                  return const SizedBox.shrink();
                }
                if (entries.isEmpty) {
                  return _NothingWritten(theme: theme);
                }
                return _Entries(entries: entries, onTap: _write);
              },
        ),
      ),
    );
  }
}

class _NothingWritten extends StatelessWidget {
  const _NothingWritten({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Nothing written yet',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'What you write here stays on this phone. Nobody else can read '
            'it, and it is not sent anywhere.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _Entries extends StatelessWidget {
  const _Entries({required this.entries, required this.onTap});

  final List<JournalEntry> entries;
  final Future<void> Function(JournalEntry) onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) {
        final JournalEntry entry = entries[index];
        final bool startsMonth =
            index == 0 || entries[index - 1].month != entry.month;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (startsMonth) ...<Widget>[
              SizedBox(height: index == 0 ? 8 : 28),
              Text(
                DateLabels.monthAndYear(context, entry.date),
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
            ],
            _EntryTile(entry: entry, onTap: () => onTap(entry)),
          ],
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onTap});

  final JournalEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  DateLabels.dayAndDate(context, entry.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    height: 1.45,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
