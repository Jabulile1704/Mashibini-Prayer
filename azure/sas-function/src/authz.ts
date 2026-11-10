/**
 * Which blob a caller is allowed to name, given who they turned out to be.
 *
 * Its own module, with no imports, because this is the whole of the
 * authorisation decision and it should be testable without an Azure SDK, a
 * Function host, or a network. Until this file existed there was no test for
 * the question it answers, and the answer was wrong.
 *
 * ## What was wrong
 *
 * `sas.ts` verified the caller's Firebase ID token and then signed a SAS for
 * whatever `key` the query string asked for. The uid was used for exactly one
 * thing: a log line.
 *
 * So any holder of a valid token for the project could mint a **read** URL
 * for any blob in the container, and a **write** URL for any blob in the
 * container — reading somebody else's recordings, or overwriting them. Google
 * sign-in admits any Google account, so "a valid token for this project" is
 * very nearly "anybody", not "a member of this family".
 *
 * Authentication is not authorisation. The first asks who you are, and this
 * file is the second.
 *
 * ## What it does instead
 *
 * The caller does not get to name the owner. The uid is **prepended** by the
 * server, so the blob is always `<uid>/<key>` and there is no string a client
 * can send that reaches another person's prefix. That is authorisation by
 * construction rather than by validation — a rule that rejects bad input has
 * to anticipate it, and a rule that makes bad input inexpressible does not.
 *
 * ## What this deliberately does not do yet
 *
 * **Nobody can read anybody else's files**, including their own family's.
 * That is narrower than ADR-024 wants — the point of the spike was that
 * photographs and audio stop being stuck on one phone — and it is where this
 * stops for now, because the Function has no idea who is in which family.
 * It holds a storage key and nothing else; family membership lives in
 * Firestore, which this never reads.
 *
 * Widening it to the family is not a change to this rule, it is the addition
 * of a second one, and it needs a way to establish membership that a caller
 * cannot forge: the Firebase Admin SDK reading `families/{id}.memberUids`
 * with service credentials, or a custom claim minted when somebody joins.
 * Until one of those exists, "only your own" is the honest ceiling, and it is
 * better than the alternative that was actually shipped, which was everyone's.
 *
 * None of this is reachable from the app today — nothing outside
 * `lib/src/data/sources/remote/` constructs a `RemoteFiles`, and the Azure
 * implementation needs `--dart-define=AZURE_FILES_URL`. The Function was
 * never deployed. This is a fix to code that was wrong rather than to an
 * exposure that happened.
 */

/** The longest blob name we will sign for. Azure's own limit is 1024 UTF-8
 *  bytes for the whole name, and the uid and separator come out of that
 *  budget before the caller's key does. */
export const MAX_KEY_LENGTH = 512;

/**
 * The blob name this caller may use for [key], or `null` if there is none.
 *
 * `null` means refuse the request — not "use a default", not "try harder".
 * Every caller of this must turn it into a 4xx.
 */
export function blobNameFor(
  uid: string | null | undefined,
  key: string | null | undefined,
): string | null {
  // No uid means the token check did not produce one. There is no sensible
  // prefix to fall back to and the request is unauthenticated.
  if (!uid || uid.includes('/') || uid.includes('..')) {
    return null;
  }

  if (!key) {
    return null;
  }

  if (key.length > MAX_KEY_LENGTH) {
    return null;
  }

  // `..` cannot walk out of the prefix the way it walks out of a directory,
  // because this is a flat namespace and the result is used as a blob name
  // rather than a path. It is refused anyway: Blob and the clients in front
  // of it normalise names in ways that are not worth reasoning about one
  // release at a time, and no honest caller needs it.
  if (key.includes('..')) {
    return null;
  }

  // A leading slash would produce `<uid>//<key>`, which is a different blob
  // from `<uid>/<key>` and reachable by two spellings. Two names for one
  // file is how a quota check and a delete end up disagreeing.
  if (key.startsWith('/')) {
    return null;
  }

  // Backslashes, control characters and a trailing slash are all refused
  // rather than normalised. Normalising means this file and Azure have to
  // agree about the rules forever; refusing means they do not.
  if (/[\\\u0000-\u001f\u007f]/.test(key) || key.endsWith('/')) {
    return null;
  }

  return `${uid}/${key}`;
}

/**
 * Read or write, from the query string, defaulting to read.
 *
 * Separate from the blob name because they fail differently: an unknown
 * permission is not dangerous, it is just not write. An unknown blob name is
 * somebody asking for a file that is not theirs.
 */
export function permissionFrom(raw: string | null | undefined): 'r' | 'w' {
  return raw === 'w' ? 'w' : 'r';
}
