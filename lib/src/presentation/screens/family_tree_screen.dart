import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/repositories/device_settings_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/sources/platform/photos.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/turn.dart';
import '../../domain/family/family_tree.dart';
import '../../domain/ids.dart';
import '../../domain/rota/family_editor.dart';
import '../../domain/rota/rota_engine.dart';
import '../brand/mark.dart';
import '../brand/tokens.dart';
import '../widgets/centred_message.dart';
import '../widgets/date_text.dart';
import 'family_member_sheet.dart';
import 'songbook_screen.dart';

/// The family, as a comb (#109).
///
/// Asked for as "a hierarchy of the family … a pic of each person, name,
/// role … all within this bee-comb like branch tree hierarchy".
///
/// **The tree is not the rota.** `cycle.order` says who takes a week;
/// `Family.members` says who the family is, and that is the larger set — a
/// grandchild belongs here without being handed a turn at leading prayer.
/// Everyone drawn here comes from `members`, and whether they lead is a
/// question this screen *answers* under their name rather than decides.
///
/// Generations come from [FamilyTree], which is pure: every awkward family —
/// a parent recorded after their child, a grandparent added later, two
/// people who ended up as each other's parent through a merge — is a unit
/// test rather than something to reproduce by tapping.
class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({
    required this.familyRepository,
    required this.settings,
    required this.photos,
    required this.ids,
    this.today,
    super.key,
  });

  final FamilyRepository familyRepository;
  final DeviceSettingsRepository settings;
  final Photos photos;
  final IdGenerator ids;
  final CalendarDate Function()? today;

  static const Key comb = Key('tree.comb');
  static const Key songbook = Key('tree.songbook');
  static const Key addRelative = Key('tree.addRelative');
  static const Key onThisPhone = Key('tree.onThisPhone');
  static const Key nameField = Key('tree.addRelative.name');
  static const Key confirmAdd = Key('tree.addRelative.confirm');

  static Key cellFor(String memberId) => Key('tree.cell.$memberId');

  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends State<FamilyTreeScreen> {
  late final Stream<Family?> _families = widget.familyRepository.watch();

  CalendarDate get _today =>
      widget.today?.call() ?? CalendarDate.from(DateTime.now());

  Future<void> _edit(Family family, Member member) async {
    final Member? updated = await showModalBottomSheet<Member>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // A sheet whose body scrolls swallows the drag that would dismiss
      // it: pulling down moves the list, and only a pull that starts at
      // the very top closes anything. The handle is a target that always
      // dismisses, wherever the list happens to be scrolled to.
      showDragHandle: true,
      builder: (BuildContext context) => FamilyMemberSheet(
        family: family,
        member: member,
        photos: widget.photos,
      ),
    );
    if (updated == null) {
      return;
    }
    await widget.familyRepository.save(
      FamilyEditor.updateMember(family, updated),
    );
  }

  Future<void> _add(Family family) async {
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => const _AddRelativeDialog(),
    );
    if (name == null) {
      return;
    }
    await widget.familyRepository.save(
      FamilyEditor.addRelative(family, displayName: name, ids: widget.ids),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Family')),
      body: SafeArea(
        child: StreamBuilder<Family?>(
          stream: _families,
          builder: (BuildContext context, AsyncSnapshot<Family?> stored) {
            final Family? family = stored.data;
            if (family == null) {
              return CentredMessage(
                children: <Widget>[
                  Text(
                    'Nobody here yet',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    'Set the rota up on the This week tab, and everybody in '
                    'it appears here.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              );
            }
            return _tree(theme, family);
          },
        ),
      ),
    );
  }

  Widget _tree(ThemeData theme, Family family) {
    final List<List<Member>> rows = FamilyTree.generations(family.members);
    final RotaEngine engine = RotaEngine.forFamily(family);
    final Set<String> inTheRota = <String>{
      for (final Member member in FamilyEditor.activeMembers(family, _today))
        member.id,
    };

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxl),
      children: <Widget>[
        const SizedBox(height: Space.lg),
        for (int row = 0; row < rows.length; row++) ...<Widget>[
          if (row > 0) const _Branch(),
          _CombRow(
            key: row == 0 ? FamilyTreeScreen.comb : null,
            // Alternate rows sit half a cell across, so they nest the way a
            // comb does rather than stacking into a grid.
            inset: row.isOdd,
            children: <Widget>[
              for (final Member member in rows[row])
                _Cell(
                  member: member,
                  note: _noteFor(engine, member, inTheRota),
                  onTap: () => _edit(family, member),
                ),
            ],
          ),
        ],
        const SizedBox(height: Space.xl),
        Padding(
          padding: Space.gutter,
          child: ListTile(
            key: FamilyTreeScreen.songbook,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.music_note_outlined),
            title: const Text('Songs we love'),
            subtitle: const Text('What this family sings, and who chose it'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => SongbookScreen(
                  familyRepository: widget.familyRepository,
                  settings: widget.settings,
                  ids: widget.ids,
                  today: widget.today,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        Padding(
          padding: Space.gutter,
          child: OutlinedButton.icon(
            key: FamilyTreeScreen.addRelative,
            onPressed: () => _add(family),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Add someone to the family'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.lg,
            Space.sm,
            Space.lg,
            Space.lg,
          ),
          child: Text(
            'Adding someone here does not give them a week of prayer. The '
            'rota is who leads; this is everybody.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const Divider(),
        Padding(
          key: FamilyTreeScreen.onThisPhone,
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 0),
          child: Text(
            'Photographs stay on this phone. They are never uploaded — which '
            'also means the others cannot see them, and reinstalling the app '
            'loses them.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  /// The line under a name.
  ///
  /// Their role if the family has given them one, because that is what they
  /// chose to say. Otherwise the rota answers: when they next lead, or that
  /// they are not in it — which is the fact most likely to be misread about
  /// a screen that shows more people than the rota does.
  String _noteFor(RotaEngine engine, Member member, Set<String> inTheRota) {
    final String? role = member.role;
    if (role != null && role.isNotEmpty) {
      return role;
    }
    if (!inTheRota.contains(member.id)) {
      return 'Not in the rota';
    }
    for (final Turn turn in engine.turnsFrom(_today, count: 24)) {
      if (turn.leader.id == member.id) {
        return turn.contains(_today)
            ? 'This week'
            : DateLabels.dayAndDate(context, turn.weekStart);
      }
    }
    return '';
  }
}

/// One generation, laid out as a row of cells.
class _CombRow extends StatelessWidget {
  const _CombRow({required this.children, required this.inset, super.key});

  final List<Widget> children;
  final bool inset;

  @override
  Widget build(BuildContext context) => Padding(
    // Half a cell on alternate rows, so generations nest the way a comb
    // does. **Only on the inset rows.** The first version balanced it with
    // the same padding on the right of every other row, which cost 38pt of
    // width and made a four-person family wrap after three — and a wrapped
    // run looks exactly like a generation below, which is the one thing
    // this screen must not say by accident.
    padding: EdgeInsets.only(left: inset ? _Cell.diameter / 2 : 0),
    // Wrap rather than Row: a generation can be larger than a phone, and a
    // family that outgrows one line should flow onto the next rather than
    // overflow off the side. What distinguishes a wrapped run from the next
    // generation is the stem drawn between generations and not between
    // runs.
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: Space.xs,
      runSpacing: Space.sm,
      children: children,
    ),
  );
}

/// The join between one generation and the next.
///
/// A single stem, not a line per parent. Drawing every edge needs the cells'
/// painted positions, which a `Wrap` settles at layout time and does not
/// report — and a line drawn between the wrong two people would be worse
/// than an honest one saying only "these came from those".
class _Branch extends StatelessWidget {
  const _Branch();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 2,
      height: Space.xl,
      color: Theme.of(context).colorScheme.outlineVariant,
    ),
  );
}

/// One person: a hexagon, their name, and a line about them.
///
/// The name sits **outside** the hexagon on purpose. Text inside a clipped
/// shape has nowhere to go when somebody turns the font size up, and the
/// largest text size is where this app's accessibility defects have been
/// found.
class _Cell extends StatelessWidget {
  const _Cell({required this.member, required this.note, required this.onTap});

  final Member member;
  final String note;
  final VoidCallback onTap;

  static const double diameter = 76;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String trimmed = member.displayName.trim();
    final String initial = trimmed.isEmpty
        ? '?'
        : trimmed.characters.first.toUpperCase();

    return Semantics(
      button: true,
      label: note.isEmpty ? member.displayName : '${member.displayName}, $note',
      child: ExcludeSemantics(
        child: InkWell(
          key: FamilyTreeScreen.cellFor(member.id),
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.md),
          child: SizedBox(
            width: diameter + Space.lg,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.xs),
              child: Column(
                children: <Widget>[
                  ClipPath(
                    clipper: _HexagonClipper(),
                    child: SizedBox(
                      width: diameter,
                      height: diameter,
                      child: _face(theme, initial),
                    ),
                  ),
                  const SizedBox(height: Space.sm),
                  Text(
                    member.displayName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (note.isNotEmpty)
                    Text(
                      note,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _face(ThemeData theme, String initial) {
    final String? path = member.photoPath;
    if (path == null) {
      return _initial(theme, initial);
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      // A photograph whose file has gone — deleted from the phone, or a
      // restore that did not carry it — falls back rather than showing a
      // broken-image glyph. Paths outlive files.
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
          _initial(theme, initial),
    );
  }

  Widget _initial(ThemeData theme, String initial) => Container(
    color: theme.colorScheme.secondaryContainer,
    alignment: Alignment.center,
    child: Text(
      initial,
      style: theme.textTheme.headlineSmall?.copyWith(
        color: theme.colorScheme.onSecondaryContainer,
      ),
    ),
  );
}

/// Asks for a name, and will not return an empty one.
class _AddRelativeDialog extends StatefulWidget {
  const _AddRelativeDialog();

  @override
  State<_AddRelativeDialog> createState() => _AddRelativeDialogState();
}

class _AddRelativeDialogState extends State<_AddRelativeDialog> {
  final TextEditingController _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _name.text.trim();
    if (name.isNotEmpty) {
      Navigator.of(context).pop(name);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Add someone to the family'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'They appear straight away and are not given a week of prayer. '
          'You can say who their parents are once they are here.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: Space.lg),
        TextField(
          key: FamilyTreeScreen.nameField,
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
              key: FamilyTreeScreen.confirmAdd,
              onPressed: value.text.trim().isEmpty ? null : _submit,
              child: const Text('Add'),
            ),
      ),
    ],
  );
}

/// The same hexagon the app's mark is drawn from, as a clip.
///
/// Reusing `CombMarkPainter.cell` rather than writing a second hexagon: two
/// shapes drawn from two bits of trigonometry are two shapes that can stop
/// matching.
class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => CombMarkPainter.cell(
    Offset(size.width / 2, size.height / 2),
    size.shortestSide / 2,
  );

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
