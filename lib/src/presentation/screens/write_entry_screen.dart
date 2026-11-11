import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories/journal_repository.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/journal_entry.dart';
import '../brand/tokens.dart';
import '../widgets/date_text.dart';

/// Writing or changing one day's entry.
class WriteEntryScreen extends StatefulWidget {
  const WriteEntryScreen({
    required this.journal,
    required this.date,
    this.existing,
    this.now,
    super.key,
  });

  final JournalRepository journal;
  final CalendarDate date;
  final JournalEntry? existing;

  /// The clock, injectable so a test does not depend on when it ran.
  final DateTime Function()? now;

  static const Key textField = Key('journal.text');
  static const Key saveButton = Key('journal.save');

  @override
  State<WriteEntryScreen> createState() => _WriteEntryScreenState();
}

class _WriteEntryScreenState extends State<WriteEntryScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _text = TextEditingController(
    text: widget.existing?.text ?? '',
  );
  bool _saving = false;
  Timer? _draftTimer;

  /// How long to wait after the last keystroke before writing the draft.
  static const Duration _draftDelay = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _text.addListener(_scheduleDraft);
    unawaited(_restoreDraft());
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _text.removeListener(_scheduleDraft);
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _draftTimer?.cancel();
      unawaited(_writeDraft());
    }
  }

  /// Puts back anything typed and not saved before the app last went away.
  Future<void> _restoreDraft() async {
    final String? draft = await widget.journal.loadDraft(widget.date);
    if (draft == null || !mounted || draft == _text.text) {
      return;
    }
    _text.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  void _scheduleDraft() {
    _draftTimer?.cancel();
    _draftTimer = Timer(_draftDelay, () => unawaited(_writeDraft()));
  }

  Future<void> _writeDraft() async {
    if (_saving) {
      return;
    }
    await widget.journal.saveDraft(date: widget.date, text: _text.text);
  }

  Future<void> _save() async {
    _draftTimer?.cancel();
    setState(() => _saving = true);
    await widget.journal.write(
      date: widget.date,
      text: _text.text,
      now: widget.now?.call() ?? DateTime.now(),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(DateLabels.dayAndDate(context, widget.date))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                DateLabels.full(context, widget.date),
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: Space.lg),
              Expanded(
                child: TextField(
                  key: WriteEntryScreen.textField,
                  controller: _text,
                  autofocus: widget.existing == null,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                  decoration: const InputDecoration(
                    hintText: 'What are you praying about?',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: Space.md),
              Text(
                'Stays on this phone. Not sent anywhere.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Space.lg),
              FilledButton(
                key: WriteEntryScreen.saveButton,
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
