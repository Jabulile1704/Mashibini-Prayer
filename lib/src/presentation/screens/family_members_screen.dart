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
///
/// `FamilyEditor` has been finished and tested since Day 7 and unreachable
/// for fourteen days. Somebody joined or left the family and the app's only
/// answer was "start the rota again", which throws away the order, the
/// turnover day and every skip. This screen is the route it never had.
///
/// **It re-implements none of the rules.** Not the refusal to go below two
/// people, not the deferral to the next turnover, not the rotation that keeps
/// the next week's leader. All of that is in the domain, where it is tested
/// without a widget, and the job here is to show what it decided.
///
/// The pattern this screen uses for that is worth naming, because it is the
/// reason the confirmations cannot lie:
///
/// **Build the change, describe the result, then save the thing described.**
///
/// A dialog saying "Cousin will lead last, from Sunday 8 November" could be
/// written from a rule somebody remembered. Instead it is read off a real
/// [Family] that `FamilyEditor` produced, and on confirmation *that* family is
/// saved — not a second one computed again afterwards. The sentence and the
/// outcome are the same object, so the sentence cannot drift away from what
/// happens.
///
/// A later day may want roles and portraits here, and a hierarchy that is not
/// the rota's flat cycle (#109). None of that is this screen; it is noted
/// because this is where it would land.
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
  ///
  /// One dialog, not two. The date a person joins does not depend on their
  /// name, so it can be stated in the same dialog that asks for it — and a
  /// second "are you sure" over an addition that takes effect next week and
  /// can be undone by removing them again would be ceremony.
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
      // The domain refuses an empty name. The dialog refuses one too, so
      // this is the belt to that braces — but the rule lives in one place
      // and this is what honouring that costs.
      _say(error.message.toString());
    }

    if (mounted) {
      setState(() => _busy = false);
    }
  }

  // ─────────────────────────── removing somebody ───────────────────────────

  /// Takes somebody out of the rota from the next turnover, after asking.
  ///
  /// Builds the change first so the dialog can name the date, say who leads
  /// that week instead, and promise that past weeks keep this person's name —
  /// which is true because removal does not touch earlier epochs (R2.3), not
  /// because the dialog says so.
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

    // **The roster from the next turnover, not this week's.**
    //
    // Those differ for a few days after every edit, because an edit lands at
    // the next turnover (R2.3). Showing this week's was the first version
    // and it read as broken: take somebody out, confirm, and their row is
    // still sitting there — accurate, since they really are in the rota
    // until Sunday, and indistinguishable from nothing having happened.
    //
    // This screen is where the rota is *edited*, so it shows what the edits
    // have produced, and the paragraph above it says when that starts. The
    // other reading — a list of who is leading now — is This Week's job.
    final List<Member> members = FamilyEditor.activeMembers(family, from);

    // Two is the floor the domain enforces. Said here as a sentence rather
    // than left for somebody to discover by tapping a remove button and
    // reading an error, which is the same information delivered rudely.
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
  ///
  /// Read off the engine rather than from their position in the list, because
  /// a skip standing against a week ahead moves everybody and the list would
  /// not know.
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
///
/// Its own widget because it holds a controller, and a dialog built inside a
/// `showDialog` closure cannot without leaking it.
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
        // Listens to the field so it is only enabled once there is a name.
        // An "Add" that does nothing when tapped is worse than one that is
        // visibly not ready.
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
