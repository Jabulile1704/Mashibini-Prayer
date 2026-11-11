import 'dart:async';
import 'dart:convert';

import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/journal_entry.dart';
import '../../domain/ids.dart';
import '../serialization/journal_json.dart';
import '../sources/local/key_value_store.dart';

/// Where journal entries live.
abstract interface class JournalRepository {
  /// Every entry, newest first.
  Future<List<JournalEntry>> all();

  Future<JournalEntry?> forDate(CalendarDate date);

  /// Writes [text] against [date], creating or replacing that day's entry.
  Future<void> write({
    required CalendarDate date,
    required String text,
    required DateTime now,
  });

  Future<void> delete(String id);

  Stream<List<JournalEntry>> watch();

  /// Keeps text that has been typed but not saved (N7).
  Future<void> saveDraft({required CalendarDate date, required String text});

  /// Unsaved text for [date], or null if there is none.
  Future<String?> loadDraft(CalendarDate date);

  Future<void> clearDraft(CalendarDate date);

  Future<void> dispose();
}

/// Journal entries on this device, one key per entry plus an index.
class LocalJournalRepository implements JournalRepository {
  LocalJournalRepository({required this._store, required this._ids});

  static const String indexKey = 'journal.index.v1';
  static const String entryPrefix = 'journal.entry.v1.';

  /// Drafts are keyed by date rather than by entry id, because a draft can
  /// exist for a day that has no entry yet — which is the common case.
  static const String draftPrefix = 'journal.draft.v1.';

  final KeyValueStore _store;
  final IdGenerator _ids;

  final StreamController<List<JournalEntry>> _changes =
      StreamController<List<JournalEntry>>.broadcast();

  bool _disposed = false;

  @override
  Future<List<JournalEntry>> all() async {
    final List<String> ids = await _readIndex();
    final List<JournalEntry> entries = <JournalEntry>[];
    final List<String> missing = <String>[];

    for (final String id in ids) {
      final String? stored = await _store.read('$entryPrefix$id');
      if (stored == null) {
        missing.add(id);
        continue;
      }
      try {
        entries.add(JournalJson.decode(stored));
      } on FormatException {
        // One unreadable entry must not cost somebody their whole journal.
        missing.add(id);
      }
    }

    if (missing.isNotEmpty) {
      await _writeIndex(<String>[
        for (final String id in ids)
          if (!missing.contains(id)) id,
      ]);
    }

    entries.sort((JournalEntry a, JournalEntry b) {
      final int byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.updatedAt.compareTo(a.updatedAt);
    });
    return entries;
  }

  @override
  Future<JournalEntry?> forDate(CalendarDate date) async {
    for (final JournalEntry entry in await all()) {
      if (entry.date == date) {
        return entry;
      }
    }
    return null;
  }

  @override
  Future<void> write({
    required CalendarDate date,
    required String text,
    required DateTime now,
  }) async {
    _assertUsable();
    final String trimmed = text.trim();
    final JournalEntry? existing = await forDate(date);

    if (trimmed.isEmpty) {
      if (existing != null) {
        await delete(existing.id);
      }
      await clearDraft(date);
      return;
    }

    final JournalEntry entry = existing == null
        ? JournalEntry(
            id: _ids.newId('j'),
            date: date,
            text: trimmed,
            updatedAt: now,
          )
        : existing.copyWith(text: trimmed, updatedAt: now);

    await _store.write('$entryPrefix${entry.id}', JournalJson.encode(entry));
    if (existing == null) {
      await _writeIndex(<String>[...await _readIndex(), entry.id]);
    }
    await clearDraft(date);
    await _announce();
  }

  @override
  Future<void> delete(String id) async {
    _assertUsable();
    await _store.delete('$entryPrefix$id');
    await _writeIndex(<String>[
      for (final String existing in await _readIndex())
        if (existing != id) existing,
    ]);
    await _announce();
  }

  @override
  Stream<List<JournalEntry>> watch() async* {
    _assertUsable();
    yield await all();
    yield* _changes.stream;
  }

  @override
  Future<void> saveDraft({
    required CalendarDate date,
    required String text,
  }) async {
    _assertUsable();
    if (text.trim().isEmpty) {
      await clearDraft(date);
      return;
    }
    await _store.write('$draftPrefix$date', text);
  }

  @override
  Future<String?> loadDraft(CalendarDate date) =>
      _store.read('$draftPrefix$date');

  @override
  Future<void> clearDraft(CalendarDate date) =>
      _store.delete('$draftPrefix$date');

  @override
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _changes.close();
  }

  Future<List<String>> _readIndex() async {
    final String? stored = await _store.read(indexKey);
    if (stored == null) {
      return <String>[];
    }
    try {
      final Object? decoded = jsonDecode(stored);
      if (decoded is! List<Object?>) {
        return <String>[];
      }
      return <String>[
        for (final Object? id in decoded)
          if (id is String) id,
      ];
    } on FormatException {
      return <String>[];
    }
  }

  Future<void> _writeIndex(List<String> ids) =>
      _store.write(indexKey, jsonEncode(ids));

  Future<void> _announce() async {
    if (!_changes.isClosed) {
      _changes.add(await all());
    }
  }

  void _assertUsable() {
    if (_disposed) {
      throw StateError('LocalJournalRepository used after dispose()');
    }
  }
}
