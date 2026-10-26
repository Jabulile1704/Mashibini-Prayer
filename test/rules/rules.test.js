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
import { doc, getDoc, setDoc, collection, getDocs } from 'firebase/firestore';

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

  it('nobody can delete a family', async () => {
    const db = env.authenticatedContext(JABU).firestore();
    const { deleteDoc } = await import('firebase/firestore');
    await assertFails(deleteDoc(doc(db, 'families/f1')));
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
  });
});
