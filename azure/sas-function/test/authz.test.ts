import { strict as assert } from 'node:assert';
import { describe, it } from 'node:test';

import { blobNameFor, permissionFrom, MAX_KEY_LENGTH } from '../src/authz';

/**
 * The Function had no tests at all, which is why it shipped an
 * authorisation decision that did not authorise anything.
 *
 * These use `node:test` and `node:assert` — both in the standard library —
 * so the suite adds no dependency to a spike whose whole premise is that it
 * can be deleted (ADR-024).
 *
 * The first group is the defect. It is written the way an attacker would
 * phrase it rather than the way the implementation is phrased, so that it
 * keeps meaning the same thing if the implementation changes.
 */

const MINE = 'uid-jabulile';
const SOMEBODY_ELSE = 'uid-sisi';

describe('a caller cannot name somebody else’s file', () => {
  it('cannot reach another uid by asking for it directly', () => {
    const name = blobNameFor(MINE, `${SOMEBODY_ELSE}/a-song.mp3`);

    // Not null — this is a *legal* key, it just is not the file they think.
    // The protection is that it lands inside their own prefix rather than
    // being refused, which is the difference between authorisation by
    // construction and authorisation by blocklist.
    assert.equal(name, `${MINE}/${SOMEBODY_ELSE}/a-song.mp3`);
    assert.ok(name!.startsWith(`${MINE}/`));
  });

  it('cannot climb out with ..', () => {
    assert.equal(blobNameFor(MINE, `../${SOMEBODY_ELSE}/a-song.mp3`), null);
    assert.equal(blobNameFor(MINE, '..'), null);
    assert.equal(blobNameFor(MINE, 'songs/../../x'), null);
  });

  it('cannot escape with a leading slash', () => {
    assert.equal(blobNameFor(MINE, '/a-song.mp3'), null);
    assert.equal(blobNameFor(MINE, `/${SOMEBODY_ELSE}/a-song.mp3`), null);
  });

  it('cannot use a backslash or a control character to mean something else', () => {
    assert.equal(blobNameFor(MINE, '..\\x'), null);
    assert.equal(blobNameFor(MINE, 'a\\b'), null);
    assert.equal(blobNameFor(MINE, 'a\u0000b'), null);
    assert.equal(blobNameFor(MINE, 'a\nb'), null);
  });

  it('whatever the key, the name always begins with the caller’s uid', () => {
    // The property, rather than a list of the tricks thought of today. If
    // this ever fails, the specific case matters less than the fact that the
    // guarantee is no longer structural.
    const attempts = [
      'a-song.mp3',
      'songs/a-song.mp3',
      `${SOMEBODY_ELSE}/a-song.mp3`,
      './a-song.mp3',
      'songs//a-song.mp3',
      '%2e%2e/a-song.mp3',
      'a-song.mp3?x=1',
      '....//a-song.mp3',
    ];

    for (const key of attempts) {
      const name = blobNameFor(MINE, key);
      if (name !== null) {
        assert.ok(
          name.startsWith(`${MINE}/`),
          `"${key}" produced "${name}", which is outside ${MINE}/`,
        );
      }
    }
  });
});

describe('a request that proved nothing gets nothing', () => {
  it('refuses a missing uid', () => {
    assert.equal(blobNameFor(null, 'a-song.mp3'), null);
    assert.equal(blobNameFor(undefined, 'a-song.mp3'), null);
    assert.equal(blobNameFor('', 'a-song.mp3'), null);
  });

  it('refuses a uid that is not a single path segment', () => {
    // Firebase uids are opaque alphanumerics, so neither of these can arrive
    // from a verified token. Refused anyway: this function's guarantee is
    // that the prefix is exactly one segment, and it should not depend on a
    // promise made somewhere else.
    assert.equal(blobNameFor('a/b', 'a-song.mp3'), null);
    assert.equal(blobNameFor('..', 'a-song.mp3'), null);
  });
});

describe('the ordinary cases still work', () => {
  it('a plain key', () => {
    assert.equal(blobNameFor(MINE, 'a-song.mp3'), `${MINE}/a-song.mp3`);
  });

  it('a key with folders in it', () => {
    assert.equal(
      blobNameFor(MINE, 'songs/2026/a-song.mp3'),
      `${MINE}/songs/2026/a-song.mp3`,
    );
  });

  it('a key at the length limit, and one over it', () => {
    const atLimit = 'a'.repeat(MAX_KEY_LENGTH);
    assert.equal(blobNameFor(MINE, atLimit), `${MINE}/${atLimit}`);
    assert.equal(blobNameFor(MINE, 'a'.repeat(MAX_KEY_LENGTH + 1)), null);
  });

  it('an empty key is not a file', () => {
    assert.equal(blobNameFor(MINE, ''), null);
    assert.equal(blobNameFor(MINE, null), null);
    assert.equal(blobNameFor(MINE, 'songs/'), null);
  });
});

describe('the permission', () => {
  it('is write only when asked for exactly', () => {
    assert.equal(permissionFrom('w'), 'w');
  });

  it('is read for everything else, including nonsense', () => {
    // Defaulting the other way would make a typo grant write.
    assert.equal(permissionFrom('r'), 'r');
    assert.equal(permissionFrom(null), 'r');
    assert.equal(permissionFrom(undefined), 'r');
    assert.equal(permissionFrom(''), 'r');
    assert.equal(permissionFrom('W'), 'r');
    assert.equal(permissionFrom('rw'), 'r');
    assert.equal(permissionFrom('delete'), 'r');
  });
});
