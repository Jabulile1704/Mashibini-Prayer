import 'package:flutter/material.dart';

import '../../data/repositories/family_repository.dart';
import '../../domain/entities/calendar_date.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/turn.dart';
import '../../domain/rota/family_editor.dart';
import '../../domain/rota/rota_engine.dart';
import '../brand/mark.dart';
import '../brand/tokens.dart';
import '../widgets/centred_message.dart';
import '../widgets/date_text.dart';

/// The family, as a comb (#109).
///
/// Asked for as "a hierarchy of the family … a pic of each person, name,
/// role … all within this bee-comb like branch tree hierarchy". This is the
/// tab, and it is deliberately **not** that yet.
///
/// What it is: the people the app already knows, in cells, in the order they
/// take their turns. What it is not, and says so on the screen rather than
/// leaving somebody to wonder:
///
/// - **No hierarchy.** The app has no idea who is whose parent. `cycle.order`
///   is a flat list and `Family.members` has no edges between anybody, so
///   there is nothing to draw a branch from. Adding that is a schema change
///   with an ADR owing, and the rule it has to carry is that the tree and the
///   rota are different things: a grandchild belongs in the tree without
///   taking a week of prayer.
/// - **No photographs.** ADR-010 forbids file uploads and that clause stands
///   until there is a reason on paper to move it (#109).
/// - **No roles.** A `Member` is an id and a display name. What is under each
///   name here is their next turn, which the app does know.
///
/// A flat comb rather than an empty tab because the owner asked for the tab
/// today and said empty would do. An empty tab reads as broken; this one
/// shows real people, in the app's own shape, and names the three things that
/// are missing.
class FamilyTreeScreen extends StatelessWidget {
  const FamilyTreeScreen({
    required this.familyRepository,
    this.today,
    super.key,
  });

  final FamilyRepository familyRepository;
  final CalendarDate Function()? today;

  static const Key notBuiltYet = Key('tree.notBuiltYet');
  static const Key comb = Key('tree.comb');

  static Key cellFor(String memberId) => Key('tree.cell.$memberId');

  CalendarDate get _today => today?.call() ?? CalendarDate.from(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Family')),
      body: SafeArea(
        child: StreamBuilder<Family?>(
          stream: familyRepository.watch(),
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
                    'Set the rota up and the family appears here.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              );
            }

            final List<Member> members = FamilyEditor.activeMembers(
              family,
              _today,
            );
            final RotaEngine engine = RotaEngine.forFamily(family);

            return ListView(
              padding: const EdgeInsets.only(bottom: Space.xxl),
              children: <Widget>[
                const SizedBox(height: Space.xl),
                _Comb(
                  key: FamilyTreeScreen.comb,
                  members: members,
                  subtitleFor: (Member member) =>
                      _whenTheyLead(context, engine, member),
                ),
                const SizedBox(height: Space.xxl),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                  child: Text(
                    'NOT BUILT YET',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                const SizedBox(height: Space.sm),
                Padding(
                  key: FamilyTreeScreen.notBuiltYet,
                  padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                  child: Text(
                    'These are the people in the rota, not the whole family, '
                    'and they are a row of cells rather than a tree.\n\n'
                    'The branches are missing because the app does not know '
                    'who is whose parent — it only knows the order you take '
                    'your turns in. A tree can hold people who are not in '
                    'the rota at all, which is most of a family.\n\n'
                    'A photograph and a role for each person are missing too. '
                    'Both are coming; neither is here.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _whenTheyLead(BuildContext context, RotaEngine engine, Member member) {
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

/// Cells in staggered rows, the way a comb is built.
///
/// Three to a row, and every second row inset by half a cell so the cells
/// nest rather than stack in a grid. Rows of three fit a 375pt phone with the
/// screen gutter intact; a family larger than the rota will need this to
/// reflow rather than assume three, which is one of the things the tree work
/// will have to solve properly (#109).
class _Comb extends StatelessWidget {
  const _Comb({required this.members, required this.subtitleFor, super.key});

  final List<Member> members;
  final String Function(Member) subtitleFor;

  static const int _perRow = 3;
  static const double _radius = 40;

  @override
  Widget build(BuildContext context) {
    final List<List<Member>> rows = <List<Member>>[
      for (int i = 0; i < members.length; i += _perRow)
        members.sublist(
          i,
          i + _perRow > members.length ? members.length : i + _perRow,
        ),
    ];

    return Column(
      children: <Widget>[
        for (int row = 0; row < rows.length; row++)
          Padding(
            // Half a cell's width on alternate rows, which is what makes a
            // comb a comb rather than a grid.
            padding: EdgeInsets.only(
              left: row.isOdd ? _radius : 0,
              right: row.isOdd ? 0 : _radius,
              bottom: Space.lg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final Member member in rows[row])
                  _Cell(
                    member: member,
                    subtitle: subtitleFor(member),
                    radius: _radius,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One person: a hexagon with their initial, and their name underneath.
///
/// The name is **outside** the hexagon on purpose. Text inside a clipped
/// shape has nowhere to go when somebody turns the font size up, and the
/// largest text size is where this app's last four accessibility defects
/// were found. Outside, it wraps.
///
/// The hexagon is where a photograph goes when there is one.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.member,
    required this.subtitle,
    required this.radius,
  });

  final Member member;
  final String subtitle;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String initial = member.displayName.trim().isEmpty
        ? '?'
        : member.displayName.trim().characters.first;

    return Semantics(
      key: FamilyTreeScreen.cellFor(member.id),
      label: subtitle.isEmpty
          ? member.displayName
          : '${member.displayName}, ${subtitle.toLowerCase()}',
      child: SizedBox(
        width: radius * 2 + Space.sm,
        child: Column(
          children: <Widget>[
            ClipPath(
              clipper: _HexagonClipper(),
              child: Container(
                width: radius * 2,
                height: radius * 2,
                color: theme.colorScheme.secondaryContainer,
                alignment: Alignment.center,
                child: ExcludeSemantics(
                  child: Text(
                    initial.toUpperCase(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Space.sm),
            ExcludeSemantics(
              child: Column(
                children: <Widget>[
                  Text(
                    member.displayName,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The same hexagon the app's mark is drawn from, as a clip.
///
/// Reusing `CombMarkPainter.cell` rather than writing a second hexagon:
/// two shapes drawn from two bits of trigonometry are two shapes that can
/// stop matching.
class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => CombMarkPainter.cell(
    Offset(size.width / 2, size.height / 2),
    size.shortestSide / 2,
  );

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
