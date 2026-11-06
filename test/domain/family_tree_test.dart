import 'package:flutter_test/flutter_test.dart';
import 'package:mashibini_prayer/src/domain/entities/member.dart';
import 'package:mashibini_prayer/src/domain/family/family_tree.dart';

/// The shape of a family, without a screen (#109).
///
/// Every awkward family that would be a nuisance to reproduce by tapping is
/// four lines here: a parent recorded after their child, a grandparent
/// added later, two people who ended up as each other's parent through a
/// merge.
void main() {
  Member person(String id, {List<String> parents = const <String>[]}) =>
      Member(id: id, displayName: id, parentIds: parents);

  List<List<String>> idsOf(List<List<Member>> rows) => <List<String>>[
    for (final List<Member> row in rows)
      <String>[for (final Member m in row) m.id],
  ];

  group('generations', () {
    test('a family with no relationships is one row', () {
      // Which is what the Family tab showed before any of this: the rota,
      // in rota order.
      final List<List<Member>> rows = FamilyTree.generations(<Member>[
        person('tata'),
        person('mama'),
        person('jabulile'),
      ]);
      expect(idsOf(rows), <List<String>>[
        <String>['tata', 'mama', 'jabulile'],
      ]);
    });

    test('children sit under their parents', () {
      final List<List<Member>> rows = FamilyTree.generations(<Member>[
        person('tata'),
        person('mama'),
        person('jabulile', parents: <String>['tata', 'mama']),
        person('sisi', parents: <String>['tata', 'mama']),
      ]);
      expect(idsOf(rows), <List<String>>[
        <String>['tata', 'mama'],
        <String>['jabulile', 'sisi'],
      ]);
    });

    test('three generations', () {
      final List<List<Member>> rows = FamilyTree.generations(<Member>[
        person('gogo'),
        person('tata', parents: <String>['gogo']),
        person('jabulile', parents: <String>['tata']),
      ]);
      expect(idsOf(rows), <List<String>>[
        <String>['gogo'],
        <String>['tata'],
        <String>['jabulile'],
      ]);
    });

    test('a parent recorded after their child still sits above them', () {
      // The order people were added in says nothing about the generations,
      // and a family will almost always be entered rota-first.
      final List<List<Member>> rows = FamilyTree.generations(<Member>[
        person('jabulile', parents: <String>['tata']),
        person('tata'),
      ]);
      expect(idsOf(rows), <List<String>>[
        <String>['tata'],
        <String>['jabulile'],
      ]);
    });

    test('depth follows the furthest parent, not the nearest', () {
      // A child of both a grandparent and a parent belongs below the
      // parent. Taking the minimum would draw them as their own parent's
      // sibling.
      final List<List<Member>> rows = FamilyTree.generations(<Member>[
        person('gogo'),
        person('tata', parents: <String>['gogo']),
        person('child', parents: <String>['gogo', 'tata']),
      ]);
      expect(idsOf(rows), <List<String>>[
        <String>['gogo'],
        <String>['tata'],
        <String>['child'],
      ]);
    });

    test('a parent the family has no record of is not a parent', () {
      // `parentIds` is denormalised and can drift, exactly as `cycle.order`
      // can. A ghost id must not push somebody into a generation of one.
      final List<List<Member>> rows = FamilyTree.generations(<Member>[
        person('tata'),
        person('jabulile', parents: <String>['somebody-who-left']),
      ]);
      expect(idsOf(rows), <List<String>>[
        <String>['tata', 'jabulile'],
      ]);
    });

    test('two people recorded as each other\'s parent do not hang it', () {
      // Unreachable through the UI — the screen will not offer a name that
      // closes a loop — but two phones merging offline can produce it, and
      // a stack overflow is a poor way to find out.
      final List<List<Member>> rows = FamilyTree.generations(<Member>[
        person('a', parents: <String>['b']),
        person('b', parents: <String>['a']),
      ]);
      expect(rows.expand((List<Member> r) => r), hasLength(2));
    });

    test('everybody appears exactly once, however tangled', () {
      final List<Member> tangled = <Member>[
        person('gogo'),
        person('tata', parents: <String>['gogo']),
        person('mama'),
        person('jabulile', parents: <String>['tata', 'mama']),
        person('sisi', parents: <String>['tata', 'mama']),
        person('baby', parents: <String>['sisi']),
        person('stranger', parents: <String>['ghost']),
      ];
      final List<List<Member>> rows = FamilyTree.generations(tangled);
      final List<Member> flat = rows.expand((List<Member> r) => r).toList();

      expect(flat, hasLength(tangled.length));
      expect(flat.toSet(), tangled.toSet());
    });

    test('nobody at all is no rows', () {
      expect(FamilyTree.generations(const <Member>[]), isEmpty);
    });
  });

  group('what cannot be a parent', () {
    final List<Member> family = <Member>[
      person('gogo'),
      person('tata', parents: <String>['gogo']),
      person('jabulile', parents: <String>['tata']),
    ];

    test('nobody is their own parent', () {
      expect(
        FamilyTree.wouldMakeALoop(family, childId: 'tata', parentId: 'tata'),
        isTrue,
      );
    });

    test('nor their own grandchild', () {
      expect(
        FamilyTree.wouldMakeALoop(
          family,
          childId: 'gogo',
          parentId: 'jabulile',
        ),
        isTrue,
      );
    });

    test('but an unrelated person is fine', () {
      final List<Member> withCousin = <Member>[...family, person('cousin')];
      expect(
        FamilyTree.wouldMakeALoop(
          withCousin,
          childId: 'cousin',
          parentId: 'tata',
        ),
        isFalse,
      );
    });

    test('the list offered to a screen cannot contain a wrong answer', () {
      // The refusal is an absence rather than an error message: a list that
      // cannot hold a wrong answer beats one that holds it and complains
      // after it is picked.
      final List<Member> offered = FamilyTree.possibleParentsFor(
        family,
        childId: 'gogo',
      );
      expect(
        offered.map((Member m) => m.id),
        isNot(contains('gogo')),
        reason: 'gogo cannot parent gogo',
      );
      expect(
        offered.map((Member m) => m.id),
        isNot(contains('tata')),
        reason: 'tata is already gogo\'s child',
      );
      expect(
        offered.map((Member m) => m.id),
        isNot(contains('jabulile')),
        reason: 'jabulile is already below gogo',
      );
      expect(offered, isEmpty);
    });

    test('and the eldest may be given a parent later', () {
      final List<Member> withGreat = <Member>[...family, person('khulu')];
      expect(
        FamilyTree.possibleParentsFor(
          withGreat,
          childId: 'gogo',
        ).map((Member m) => m.id),
        <String>['khulu'],
      );
    });
  });
}
