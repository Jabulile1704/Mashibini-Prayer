import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/repositories/device_settings_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/repositories/photo_library_repository.dart';
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

/// The family, as a comb (#109).
class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({
    required this.familyRepository,
    required this.settings,
    required this.photos,
    required this.photoLibrary,
    required this.ids,
    this.today,
    super.key,
  });

  final FamilyRepository familyRepository;
  final DeviceSettingsRepository settings;
  final Photos photos;

  /// Where this phone keeps the photographs (#140). Not the family's.
  final PhotoLibraryRepository photoLibrary;

  final IdGenerator ids;
  final CalendarDate Function()? today;

  static const Key comb = Key('tree.comb');
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

  Map<String, String> _photos = const <String, String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_loadPhotos());
  }

  Future<void> _loadPhotos() async {
    final Map<String, String> paths = await widget.photoLibrary.all();
    if (mounted) {
      setState(() => _photos = paths);
    }
  }

  CalendarDate get _today =>
      widget.today?.call() ?? CalendarDate.from(DateTime.now());

  Future<void> _edit(Family family, Member member) async {
    final MemberEdit? edited = await showModalBottomSheet<MemberEdit>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => FamilyMemberSheet(
        family: family,
        member: member,
        photoPath: _photos[member.id],
        photos: widget.photos,
      ),
    );
    if (edited == null) {
      return;
    }

    // The photograph goes to this phone's store and the member record goes
    // to the family's document. They are saved separately because they are
    // not the same kind of thing (#140).
    if (edited.photoPath case final String path) {
      await widget.photoLibrary.remember(member.id, path);
    } else {
      await widget.photoLibrary.forget(member.id);
    }
    await _loadPhotos();

    await widget.familyRepository.save(
      FamilyEditor.updateMember(family, edited.member),
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
            inset: row.isOdd,
            children: <Widget>[
              for (final Member member in rows[row])
                _Cell(
                  member: member,
                  photoPath: _photos[member.id],
                  note: _noteFor(engine, member, inTheRota),
                  onTap: () => _edit(family, member),
                ),
            ],
          ),
        ],
        const SizedBox(height: Space.xl),
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
    padding: EdgeInsets.only(left: inset ? _Cell.diameter / 2 : 0),
    child: Wrap(
      alignment: WrapAlignment.center,
      spacing: Space.xs,
      runSpacing: Space.sm,
      children: children,
    ),
  );
}

/// The join between one generation and the next.
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
class _Cell extends StatelessWidget {
  const _Cell({
    required this.member,
    required this.photoPath,
    required this.note,
    required this.onTap,
  });

  final Member member;

  /// Where this phone keeps their photograph, if it has one.
  final String? photoPath;

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
    final String? path = photoPath;
    if (path == null) {
      return _initial(theme, initial);
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
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
class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => CombMarkPainter.cell(
    Offset(size.width / 2, size.height / 2),
    size.shortestSide / 2,
  );

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
