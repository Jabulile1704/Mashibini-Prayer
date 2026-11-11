import 'package:flutter/material.dart';

import '../../application/reschedule_reminders.dart';
import '../../data/repositories/device_settings_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/sources/notifications/reminders.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/turn.dart';
import '../../domain/ids.dart';
import '../../domain/rota/family_editor.dart';
import '../../domain/rota/rota_engine.dart';
import '../brand/tokens.dart';
import '../widgets/date_text.dart';

/// Who takes a week (#74, R2.3).
class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({
    required this.familyRepository,
    required this.settings,
    required this.reminders,
    required this.ids,
    this.today,
    this.now,
    super.key,
  });

  final FamilyRepository familyRepository;
  final DeviceSettingsRepository settings;
  final Reminders reminders;
  final IdGenerator ids;
  final CalendarDate Function()? today;
  final DateTime Function()? now;

  static const Key addRow = Key('members.add');
  static const Key nameField = Key('members.add.name');
  static const Key confirmAdd = Key('members.add.confirm');
  static const Key confirmRemove = Key('members.remove.confirm');

  static Key rowFor(String memberId) => Key('members.row.$memberId');
  static Key removeFor(String memberId) => Key('members.remove.$memberId');

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  late final Stream<Family?> _families = widget.familyRepository.watch();

  late final RescheduleReminders _reschedule = RescheduleReminders(
    families: widget.familyRepository,
    settings: widget.settings,
    reminders: widget.reminders,
  );

  bool _busy = false;
  String? _message;

  CalendarDate get _today =>
      widget.today?.call() ?? CalendarDate.from(DateTime.now());

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  // ──────────────────────────── adding somebody ────────────────────────────

  /// Asks for a name, then adds them from the next turnover.
  Future<void> _add(Family family) async {
    final CalendarDate from = FamilyEditor.changesTakeEffect(family, _today);
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => _AddMemberDialog(from: from),
    );
    if (name == null || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      await widget.familyRepository.save(
        FamilyEditor.addMember(
          family,
          displayName: name,
          today: _today,
          ids: widget.ids,
        ),
      );
      await _reschedule(today: _today, now: _now);
    } on ArgumentError catch (error) {
      _say(error.message.toString());
    }

    if (mounted) {
      setState(() => _busy = false);
    }
  }

  // ─────────────────────────── removing somebody ───────────────────────────

  /// Takes somebody out of the rota from the next turnover, after asking.
  Future<void> _remove(Family family, Member member) async {
    final Family after;
    try {
      after = FamilyEditor.removeMember(
        family,
        memberId: member.id,
        today: _today,
        ids: widget.ids,
      );
    } on ArgumentError catch (error) {
      _say(error.message.toString());
      return;
    }

    final CalendarDate from = after.latestCycle.effectiveFrom;
    final Turn? instead = RotaEngine.forFamily(after).turnOn(from);
    if (!mounted) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Take ${member.displayName} out of the rota?'),
        content: Text(
          'From ${DateLabels.full(context, from)}'
          '${instead == null ? '' : ', ${instead.leader.displayName} leads '
                    'that week'}. '
          'Weeks ${member.displayName} has already led keep their name, and '
          'this week is not changed.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep them'),
          ),
          TextButton(
            key: FamilyMembersScreen.confirmRemove,
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Take them out'),
          ),
        ],
      ),
    );

    if (!(confirmed ?? false) || !mounted) {
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    // The family the dialog described, not one recomputed after it closed.
    await widget.familyRepository.save(after);
    await _reschedule(today: _today, now: _now);
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  void _say(String message) {
    if (mounted) {
      setState(() => _message = message);
    }
  }

  // ──────────────────────────────── the list ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Who takes a week')),
      body: SafeArea(
        child: StreamBuilder<Family?>(
          stream: _families,
          builder: (BuildContext context, AsyncSnapshot<Family?> stored) {
            final Family? family = stored.data;
            if (family == null) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(Space.xl),
                  child: Text('Set the rota up first.'),
                ),
              );
            }
            return _list(theme, family);
          },
        ),
      ),
    );
  }

  Widget _list(ThemeData theme, Family family) {
    final RotaEngine engine = RotaEngine.forFamily(family);
    final CalendarDate from = FamilyEditor.changesTakeEffect(family, _today);

    final List<Member> members = FamilyEditor.activeMembers(family, from);

    final bool atTheFloor = members.length <= 2;

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxl),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.lg,
            Space.lg,
            Space.md,
          ),
          child: Text(
            'In the order they take their turns, from '
            '${DateLabels.full(context, from)}. Adding or removing somebody '
            'starts then — this week keeps the person who already has it, '
            'and weeks that have already happened keep whoever led them.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        for (final Member member in members)
          ListTile(
            key: FamilyMembersScreen.rowFor(member.id),
            title: Text(member.displayName),
            subtitle: Text(_whenTheyLead(engine, member)),
            trailing: IconButton(
              key: FamilyMembersScreen.removeFor(member.id),
              icon: const Icon(Icons.person_remove_outlined),
              tooltip: 'Take ${member.displayName} out of the rota',
              onPressed: _busy || atTheFloor
                  ? null
                  : () => _remove(family, member),
            ),
          ),
        if (atTheFloor)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 0),
            child: Text(
              'A rota needs at least two people, so neither of these can be '
              'taken out. Add somebody first.',
              style: theme.textTheme.bodySmall,
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
        const Divider(height: Space.xl),
        ListTile(
          key: FamilyMembersScreen.addRow,
          leading: const Icon(Icons.person_add_outlined),
          title: const Text('Add somebody'),
          subtitle: const Text('They take their turn last'),
          onTap: _busy ? null : () => _add(family),
        ),
      ],
    );
  }

  /// When this person's next turn is, as a sentence.
  String _whenTheyLead(RotaEngine engine, Member member) {
    for (final Turn turn in engine.turnsFrom(_today, count: 24)) {
      if (turn.leader.id == member.id) {
        return turn.contains(_today)
            ? 'Leading this week'
            : 'Next: ${DateLabels.dayAndDate(context, turn.weekStart)}';
      }
    }
    return 'Not due a turn yet';
  }
}

/// Asks for a name, and will not return an empty one.
class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog({required this.from});

  final CalendarDate from;

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add somebody to the rota'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'They join on ${DateLabels.full(context, widget.from)} and take '
            'their turn last, so everybody already in the rota goes first.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Space.lg),
          TextField(
            key: FamilyMembersScreen.nameField,
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Their name'),
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
          valueListenable: _name,
          builder: (BuildContext context, TextEditingValue value, _) =>
              TextButton(
                key: FamilyMembersScreen.confirmAdd,
                onPressed: value.text.trim().isEmpty ? null : _submit,
                child: const Text('Add'),
              ),
        ),
      ],
    );
  }
}
