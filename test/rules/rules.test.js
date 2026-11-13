// Security rules tests.
//
// Run from the repository root:
//   firebase emulators:exec --only firestore --project demo-mashibini \
//     "cd test/rules && npm test"
//
// The project id begins with `demo-`, which tells the emulator not to look
// for a real Firebase project. These tests therefore prove the rules without
// anything existing in the cloud — which matters, because on the day they
// were written no Firebase project existed yet.
//
// What they are for: R4.2 and N3 say a journal entry is readable only by its
// author, *enforced in the database rather than only in the UI*. A test that
// drives the app cannot prove that. Only this can.
import { strict as assert } from 'node:assert';
import { after, before, describe, it } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
} from 'firebase/firestore';

let env;

const JABU = 'uid-jabulile';
const SISI = 'uid-sisi';
const STRANGER = 'uid-stranger';

const familyDoc = {
  name: 'Mashibini',
  turnoverWeekday: 7,
  schemaVersion: 1,
  memberUids: [JABU, SISI],
};

// The document the **app** produces, emitted by its own serialiser.
//
// Everything above is hand-built, which is how these tests could pass for
// twenty-five days while the rules asked for a `memberUids` the app never
// wrote. Both halves were right in isolation and had never been introduced.
//
// Written by `tool/emit_rules_fixture.dart`, which CI runs before this
// suite. A Dart test cannot reach the emulator and this file cannot reach
// `FamilyJson`; a fixture on disk is the only honest seam between them.
const fixturePath = new URL(
  './fixtures/family-from-the-app.json',
  import.meta.url,
);

let fromTheApp;
try {
  fromTheApp = JSON.parse(readFileSync(fixturePath, 'utf8'));
} catch (cause) {
  // Not committed on purpose: a checked-in copy of a generated document
  // goes stale silently, which is the exact failure this fixture exists to
  // fix.
  throw new Error(
    'Missing the app-produced fixture. Run, from the repository root:\n' +
      '  dart run tool/emit_rules_fixture.dart',
    { cause },
  );
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-mashibini',
    firestore: {
      rules: readFileSync('../../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });

  // Seed through the back door, which bypasses rules on purpose: these tests
  // are about who may read and write, not about how the data got there.
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'families/f1'), familyDoc);
    await setDoc(doc(db, 'families/f1/members/m1'), {
      displayName: 'Jabulile',
    });
    await setDoc(doc(db, 'families/f1/cycles/c1'), {
      effectiveFrom: '2026-10-18',
      order: ['m1'],
    });
    await setDoc(doc(db, `journals/${JABU}/entries/e1`), {
      entryDate: '2026-10-20',
      text: 'Private',
    });
    await setDoc(doc(db, `memberships/${JABU}`), { familyId: 'f1' });
  });
});

after(async () => {
  await env?.cleanup();
});

describe('journals are private by construction (R4.2, N3)', () => {
  it('the author can read their own entry', async () => {
    const db = env.authenticatedContext(JABU).firestore();
    await assertSucceeds(getDoc(doc(db, `journals/${JABU}/entries/e1`)));
  });

  it('the author can write their own entry', async () => {
    const db = env.authenticatedContext(JABU).firestore();
    await assertSucceeds(
      setDoc(doc(db, `journals/${JABU}/entries/e2`), { text: 'Mine' }),
    );
  });

  it('another member of the same family cannot read it', async () => {
    const db = env.authenticatedContext(SISI).firestore();
    await assertFails(getDoc(doc(db, `journals/${JABU}/entries/e1`)));
  });

  it('another member cannot write into it either', async () => {
    const db = env.authenticatedContext(SISI).firestore();
    await assertFails(
      setDoc(doc(db, `journals/${JABU}/entries/e3`), { text: 'Not yours' }),
    );
  });

  it('a stranger cannot read it', async () => {
    const db = env.authenticatedContext(STRANGER).firestore();
    await assertFails(getDoc(doc(db, `journals/${JABU}/entries/e1`)));
  });

  it('nobody signed out can read it', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, `journals/${JABU}/entries/e1`)));
  });

  it("listing somebody else's entries is refused, not merely empty", async () => {
    // A rule that filtered rather than refused would leak the count.
    const db = env.authenticatedContext(SISI).firestore();
    await assertFails(getDocs(collection(db, `journals/${JABU}/entries`)));
  });
});

describe('a membership says where to look, and nothing more (#75)', () => {
  it('an account can write down which family it is in', async () => {
    const db = env.authenticatedContext(JABU).firestore();
    await assertSucceeds(
      setDoc(doc(db, `memberships/${JABU}`), { familyId: 'f1' }),
    );
  });

  it('and read it back after a reinstall', async () => {
    const db = env.authenticatedContext(JABU).firestore();
    await assertSucceeds(getDoc(doc(db, `memberships/${JABU}`)));
  });

  it('nobody else can read it', async () => {
    // Not because the family id is a secret — it is in every copy of the
    // document — but because who belongs to which family is not a question
    // a stranger gets to ask.
    const db = env.authenticatedContext(SISI).firestore();
    await assertFails(getDoc(doc(db, `memberships/${JABU}`)));
  });

  it('and nobody can put somebody else in a family', async () => {
    const db = env.authenticatedContext(STRANGER).firestore();
    await assertFails(
      setDoc(doc(db, `memberships/${JABU}`), { familyId: 'f1' }),
    );
  });

  it('signed out, it is not there at all', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, `memberships/${JABU}`)));
  });

  it('knowing the family id is still not a way in', async () => {
    // The point of the collection, stated as a test. A membership record
    // hands out a family id; the family document refuses anybody who is
    // not already in memberUids, so the id on its own is worth nothing.
    const db = env.authenticatedContext(STRANGER).firestore();
    await assertSucceeds(
      setDoc(doc(db, `memberships/${STRANGER}`), { familyId: 'f1' }),
    );
    await assertFails(getDoc(doc(db, 'families/f1')));
  });
});

describe('the family is shared with its members', () => {
  it('a member can read the family', async () => {
    const db = env.authenticatedContext(JABU).firestore();
    await assertSucceeds(getDoc(doc(db, 'families/f1')));
  });

  it('a member can read the rota', async () => {
    const db = env.authenticatedContext(SISI).firestore();
    await assertSucceeds(getDoc(doc(db, 'families/f1/cycles/c1')));
    await assertSucceeds(getDocs(collection(db, 'families/f1/members')));
  });

  it('a member can change the rota', async () => {
    const db = env.authenticatedContext(SISI).firestore();
    await assertSucceeds(
      setDoc(doc(db, 'families/f1/cycles/c2'), {
        effectiveFrom: '2026-11-01',
        order: ['m1'],
      }),
    );
  });

  it('somebody outside the family cannot read it', async () => {
    const db = env.authenticatedContext(STRANGER).firestore();
    await assertFails(getDoc(doc(db, 'families/f1')));
  });

  it('somebody outside cannot reach the rota either', async () => {
    const db = env.authenticatedContext(STRANGER).firestore();
    await assertFails(getDoc(doc(db, 'families/f1/cycles/c1')));
    await assertFails(getDocs(collection(db, 'families/f1/members')));
  });

  it('a signed-out visitor gets nothing', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'families/f1')));
  });

  it('nobody can delete a family, not even a member', async () => {
    // This one caught a real hole: a recursive `match /{document=**}` inside
    // the family also matches the family document itself, and its `allow
    // write` granted delete over the top of `allow delete: if false`.
    const db = env.authenticatedContext(JABU).firestore();
    await assertFails(deleteDoc(doc(db, 'families/f1')));
  });

  it('a member can still delete a skip, which is not append-only', async () => {
    const db = env.authenticatedContext(JABU).firestore();
    await assertSucceeds(
      setDoc(doc(db, 'families/f1/skips/s1'), {
        weekStart: '2026-11-08',
        memberId: 'm1',
      }),
    );
    await assertSucceeds(deleteDoc(doc(db, 'families/f1/skips/s1')));
  });

  it('a subcollection nobody named is denied', async () => {
    // Spelling out members, cycles and skips means a new subcollection has
    // to be added to the rules on purpose rather than inheriting access.
    const db = env.authenticatedContext(JABU).firestore();
    await assertFails(getDoc(doc(db, 'families/f1/invoices/i1')));
    await assertFails(setDoc(doc(db, 'families/f1/invoices/i1'), { a: 1 }));
  });
});

describe('creating a family', () => {
  it('is allowed when the creator is in it', async () => {
    const db = env.authenticatedContext(STRANGER).firestore();
    await assertSucceeds(
      setDoc(doc(db, 'families/f-new'), {
        name: 'Another',
        turnoverWeekday: 7,
        schemaVersion: 1,
        memberUids: [STRANGER],
      }),
    );
  });

  it('is refused when the creator leaves themselves out', async () => {
    // Otherwise any account could create a family naming other people and
    // pull them into it.
    const db = env.authenticatedContext(STRANGER).firestore();
    await assertFails(
      setDoc(doc(db, 'families/f-sneaky'), {
        name: 'Not mine',
        turnoverWeekday: 7,
        schemaVersion: 1,
        memberUids: [JABU, SISI],
      }),
    );
  });

  it('is refused with no members at all', async () => {
    const db = env.authenticatedContext(STRANGER).firestore();
    await assertFails(
      setDoc(doc(db, 'families/f-empty'), {
        name: 'Nobody',
        turnoverWeekday: 7,
        schemaVersion: 1,
        memberUids: [],
      }),
    );
  });

  it('is refused by somebody signed out', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(
      setDoc(doc(db, 'families/f-anon'), {
        name: 'Anon',
        memberUids: ['whoever'],
      }),
    );
  });
});

describe('everything else is denied', () => {
  it('an unknown collection cannot be read', async () => {
    const db = env.authenticatedContext(JABU).firestore();
    await assertFails(getDoc(doc(db, 'secrets/anything')));
  });

  it('an unknown collection cannot be written', async () => {
    const db = env.authenticatedContext(JABU).firestore();
    await assertFails(setDoc(doc(db, 'secrets/anything'), { a: 1 }));
  });

  it('a top-level journals listing is refused', async () => {
    const db = env.authenticatedContext(JABU).firestore();
    await assertFails(getDocs(collection(db, 'journals')));
  });
});

describe('the rules file is the one in the repository', () => {
  it('reads from firestore.rules rather than an inline copy', () => {
    const source = readFileSync('../../firestore.rules', 'utf8');
    assert.match(source, /match \/journals\/\{uid\}/);
    assert.match(source, /match \/memberships\/\{uid\}/);
  });
});

describe('the document the app actually writes', () => {
  // The test that would have caught it. Not "do the rules work" — they did
  // — but "do the rules accept what this app produces", which nothing had
  // ever asked.
  it('is accepted by the rules it has to pass', async () => {
    const db = env.authenticatedContext(JABU).firestore();
    await assertSucceeds(
      setDoc(doc(db, `families/${fromTheApp.id}`), fromTheApp),
    );
  });

  it('carries the field the rules read', () => {
    // Belt and braces, and it fails for a clearer reason than a rules
    // rejection would: if `memberUids` ever stops being written, this says
    // so in one line instead of as a permission error.
    assert.ok(
      Array.isArray(fromTheApp.memberUids),
      'the app must write memberUids, or every rule that reads it errors',
    );
    assert.ok(fromTheApp.memberUids.includes(JABU));
  });

  it('is refused for somebody who is not in it', async () => {
    const db = env.authenticatedContext(STRANGER).firestore();
    await assertFails(
      setDoc(doc(db, `families/${fromTheApp.id}`), fromTheApp),
    );
  });

  it('names nothing that only exists on one phone', () => {
    // #140. A photograph lives at an absolute path inside one handset's
    // application directory; published here it is a dead path on every
    // other phone, and the merge would carry it back and forth for ever.
    //
    // A tripwire rather than a proof: the fixture has no photograph, so
    // this passes by construction today. It fails on the day somebody puts
    // a device path back into the shared document, which is the only day it
    // needs to work. The proof is on the Dart side, where every key the
    // document may carry is listed.
    const json = JSON.stringify(fromTheApp);
    assert.ok(
      !json.includes('photoPath'),
      'the family document must not carry a path into one phone',
    );
    assert.ok(
      !/\/data\/user\/|\/var\/mobile\/|app_flutter|\/tmp\//.test(json),
      'the family document must not carry an absolute file path',
    );
  });

  it('a member who has not signed in is simply not in memberUids', () => {
    // Mama has no uid in the fixture. She is in the family and cannot
    // sync, which is the honest consequence rather than a loophole.
    const names = fromTheApp.members.map((m) => m.displayName);
    assert.ok(names.includes('Mama'));
    assert.equal(fromTheApp.memberUids.length, 2);
  });
});
