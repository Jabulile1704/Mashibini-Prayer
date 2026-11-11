import 'package:flutter/material.dart';

import '../../data/repositories/device_settings_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/member.dart';
import '../../domain/ids.dart';
import '../../domain/rota/rota_setup.dart';
import '../../domain/rota/week.dart';
import '../brand/tokens.dart';
import '../widgets/date_text.dart';
import '../widgets/weekday_names.dart';

/// Setting up the rota: who takes a week, which day it turns over, and whose
/// week it is now.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    required this.familyRepository,
    required this.settingsRepository,
    required this.ids,
    this.today,
    super.key,
  });

  static const Key turnoverDayField = Key('setup.turnoverDay');
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

  /// One per name, so the keyboard's "next" key can move between them
  /// rather than dismissing itself.
  final List<FocusNode> _focus = <FocusNode>[FocusNode(), FocusNode()];

  /// Monday, because a week that ends on Sunday starts on Monday.
  int _turnoverWeekday = DateTime.monday;
  int? _youAre;
  bool _saving = false;
  String? _formError;

  @override
  void dispose() {
    for (final TextEditingController controller in _names) {
      controller.dispose();
    }
    for (final FocusNode node in _focus) {
      node.dispose();
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
    setState(() {
      _names.add(TextEditingController());
      _focus.add(FocusNode());
    });
  }

  void _removePerson(int index) {
    setState(() {
      _names.removeAt(index).dispose();
      _focus.removeAt(index).dispose();
      // The remaining dropdown points at row indices, which have shifted.
      _youAre = null;
    });
  }

  /// Which week a position in the list covers.
  String _weekLabel(BuildContext context, int index) {
    if (index == 0) {
      return 'This week';
    }
    final CalendarDate starts = Week.startOf(
      _today,
      _turnoverWeekday,
    ).addDays(7 * index);
    return 'from ${DateLabels.dayAndDate(context, starts)}';
  }

  /// Moves a person to a different position in the rota.
  void _reorder(int from, int to) {
    setState(() {
      _names.insert(to, _names.removeAt(from));
      _focus.insert(to, _focus.removeAt(from));
      _youAre = null;
    });
  }

  /// Moves to the next name when the keyboard's "next" key is pressed.
  void _moveOn(int from) {
    if (from + 1 < _focus.length) {
      FocusScope.of(context).requestFocus(_focus[from + 1]);
    } else {
      FocusScope.of(context).unfocus();
    }
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
    final List<Member> members = <Member>[
      for (final (int, String) entry in filled)
        Member(id: widget.ids.newId('m'), displayName: entry.$2),
    ];
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
        currentLeaderId: members.first.id,
        today: _today,
        ids: widget.ids,
      );
      await widget.familyRepository.save(family);
      if (youPosition != null && youPosition >= 0) {
        await widget.settingsRepository.saveYouAre(members[youPosition].id);
      }
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
            padding: const EdgeInsets.all(Space.lg),
            children: <Widget>[
              _Heading(
                title: 'Whose week is it?',
                subtitle:
                    'The first person is leading this week. Drag to change '
                    'the order — after the last one it comes back round to '
                    'the first.',
              ),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: _names.length,
                onReorderItem: _reorder,
                itemBuilder: (BuildContext context, int i) => Padding(
                  key: ValueKey<TextEditingController>(_names[i]),
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: _Position(
                    index: i,
                    when: _weekLabel(context, i),
                    canRemove: _names.length > 2,
                    onRemove: () => _removePerson(i),
                    field: TextFormField(
                      controller: _names[i],
                      focusNode: _focus[i],
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: i == _names.length - 1
                          ? TextInputAction.done
                          : TextInputAction.next,
                      autofillHints: const <String>[AutofillHints.name],
                      onFieldSubmitted: (_) => _moveOn(i),
                      decoration: const InputDecoration(
                        hintText: 'Their name',
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (String? value) {
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
                ),
              ),
              if (_filledNames.length >= 2)
                Padding(
                  padding: const EdgeInsets.only(left: Space.xs),
                  child: Text(
                    '…and then back to ${_filledNames.first.$2}.',
                    style: Theme.of(context).textTheme.bodySmall,
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
              const SizedBox(height: Space.xl),
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
              const SizedBox(height: Space.xl),
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
                const SizedBox(height: Space.lg),
                Text(
                  _formError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: Space.xxl),
              FilledButton(
                key: SetupScreen.startButton,
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Start the rota'),
              ),
              const SizedBox(height: Space.xxl),
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
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: Space.xs),
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

/// One position in the rota: which week it is, who has it, and a handle.
class _Position extends StatelessWidget {
  const _Position({
    required this.index,
    required this.when,
    required this.field,
    required this.canRemove,
    required this.onRemove,
  });

  final int index;
  final String when;
  final Widget field;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isNow = index == 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.sm,
        Space.md,
      ),
      decoration: BoxDecoration(
        color: isNow
            ? theme.colorScheme.secondaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  when.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isNow
                        ? theme.colorScheme.onSecondaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Space.xs),
                field,
              ],
            ),
          ),
          if (canRemove)
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: 'Remove this person',
            ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.all(Space.sm),
              child: Icon(
                Icons.drag_handle,
                semanticLabel: 'Drag to reorder',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
