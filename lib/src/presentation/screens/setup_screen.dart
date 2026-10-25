import 'package:flutter/material.dart';

import '../../data/repositories/device_settings_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/member.dart';
import '../../domain/ids.dart';
import '../../domain/rota/rota_setup.dart';
import '../widgets/weekday_names.dart';

/// Setting up the rota: who takes a week, which day it turns over, and whose
/// week it is now.
///
/// Three questions a person can answer about their own family. The anchor
/// date is derived from them and never mentioned — see `RotaSetup` and R2.2.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    required this.familyRepository,
    required this.settingsRepository,
    required this.ids,
    this.today,
    super.key,
  });

  static const Key turnoverDayField = Key('setup.turnoverDay');
  static const Key currentLeaderField = Key('setup.currentLeader');
  static const Key youAreField = Key('setup.youAre');
  static const Key startButton = Key('setup.start');

  final FamilyRepository familyRepository;
  final DeviceSettingsRepository settingsRepository;

  /// Mints ids that will not collide with another phone's (R6.2).
  final IdGenerator ids;
  final CalendarDate Function()? today;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  /// Two empty rows to begin with: a rota needs at least two people, and
  /// showing one row would invite someone to try finishing with it.
  final List<TextEditingController> _names = <TextEditingController>[
    TextEditingController(),
    TextEditingController(),
  ];

  int _turnoverWeekday = DateTime.sunday;
  int? _currentLeader;
  int? _youAre;
  bool _saving = false;
  String? _formError;

  @override
  void dispose() {
    for (final TextEditingController controller in _names) {
      controller.dispose();
    }
    super.dispose();
  }

  CalendarDate get _today =>
      widget.today?.call() ?? CalendarDate.from(DateTime.now());

  /// Names typed so far, in order, with their row index.
  List<(int, String)> get _filledNames => <(int, String)>[
    for (int i = 0; i < _names.length; i++)
      if (_names[i].text.trim().isNotEmpty) (i, _names[i].text.trim()),
  ];

  void _addPerson() {
    setState(() => _names.add(TextEditingController()));
  }

  void _removePerson(int index) {
    setState(() {
      _names.removeAt(index).dispose();
      // The dropdowns point at row indices, which have just shifted.
      _currentLeader = null;
      _youAre = null;
    });
  }

  Future<void> _save() async {
    setState(() => _formError = null);
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }

    final List<(int, String)> filled = _filledNames;
    if (filled.length < 2) {
      setState(() => _formError = 'A rota needs at least two people.');
      return;
    }
    if (_currentLeader == null) {
      setState(() => _formError = 'Say whose week it is at the moment.');
      return;
    }

    final List<Member> members = <Member>[
      for (final (int, String) entry in filled)
        Member(id: widget.ids.newId('m'), displayName: entry.$2),
    ];
    final int leaderPosition = filled.indexWhere(
      ((int, String) entry) => entry.$1 == _currentLeader,
    );
    final int? youPosition = _youAre == null
        ? null
        : filled.indexWhere(((int, String) entry) => entry.$1 == _youAre);

    setState(() => _saving = true);
    try {
      final Family family = RotaSetup.build(
        familyId: 'f1',
        familyName: 'Mashibini',
        members: members,
        turnoverWeekday: _turnoverWeekday,
        currentLeaderId: members[leaderPosition].id,
        today: _today,
        ids: widget.ids,
      );
      await widget.familyRepository.save(family);
      if (youPosition != null && youPosition >= 0) {
        await widget.settingsRepository.saveYouAre(members[youPosition].id);
      }
      // Unreachable as the screen stands: everything RotaSetup refuses is
      // already refused above, with a sentence a person can act on. It stays
      // as a backstop for the day the two sets of rules drift apart, which is
      // the only way a domain invariant reaches a user — and a message beats
      // a red screen. It is the one block in this file with no test, because
      // there is no way to reach it without breaking the validation first.
    } on ArgumentError catch (error) {
      setState(() {
        _saving = false;
        _formError = error.message?.toString() ?? 'That rota does not work.';
      });
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<(int, String)> filled = _filledNames;

    return Scaffold(
      appBar: AppBar(title: const Text('Set up the rota')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _Heading(
                title: 'Who takes a week?',
                subtitle:
                    'In the order the rota goes round. You can change this '
                    'later.',
              ),
              for (int i = 0; i < _names.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: TextFormField(
                          controller: _names[i],
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: 'Person ${i + 1}',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (String? value) {
                            // Empty rows are ignored, not rejected: someone
                            // may add a row and change their mind.
                            if (value == null || value.trim().isEmpty) {
                              return null;
                            }
                            if (value.trim().length > 40) {
                              return 'That name is very long';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (_names.length > 2)
                        IconButton(
                          onPressed: () => _removePerson(i),
                          icon: const Icon(Icons.remove_circle_outline),
                          tooltip: 'Remove person ${i + 1}',
                        ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addPerson,
                  icon: const Icon(Icons.add),
                  label: const Text('Add someone'),
                ),
              ),
              const SizedBox(height: 24),
              _Heading(
                title: 'Your week turns over on',
                subtitle: 'The day the rota hands over to the next person.',
              ),
              DropdownButtonFormField<int>(
                key: SetupScreen.turnoverDayField,
                initialValue: _turnoverWeekday,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: <DropdownMenuItem<int>>[
                  for (final MapEntry<int, String> day
                      in WeekdayNames.byIsoWeekday.entries)
                    DropdownMenuItem<int>(
                      value: day.key,
                      child: Text(day.value),
                    ),
                ],
                onChanged: (int? value) {
                  if (value != null) {
                    setState(() => _turnoverWeekday = value);
                  }
                },
              ),
              const SizedBox(height: 24),
              _Heading(
                title: 'Whose week is it at the moment?',
                subtitle:
                    'So the app can carry on from where your family already '
                    'is.',
              ),
              DropdownButtonFormField<int>(
                key: SetupScreen.currentLeaderField,
                initialValue: _currentLeader,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Choose a person',
                ),
                items: <DropdownMenuItem<int>>[
                  for (final (int index, String name) in filled)
                    DropdownMenuItem<int>(value: index, child: Text(name)),
                ],
                onChanged: (int? value) =>
                    setState(() => _currentLeader = value),
              ),
              const SizedBox(height: 24),
              _Heading(
                title: 'Which one are you?',
                subtitle:
                    'Optional. Only used so this phone can say "your week" '
                    'instead of your name.',
              ),
              DropdownButtonFormField<int>(
                key: SetupScreen.youAreField,
                initialValue: _youAre,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Rather not say',
                ),
                items: <DropdownMenuItem<int>>[
                  for (final (int index, String name) in filled)
                    DropdownMenuItem<int>(value: index, child: Text(name)),
                ],
                onChanged: (int? value) => setState(() => _youAre = value),
              ),
              if (_formError != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  _formError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 32),
              FilledButton(
                key: SetupScreen.startButton,
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Start the rota'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
