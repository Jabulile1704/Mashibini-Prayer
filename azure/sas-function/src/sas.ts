import { app, HttpRequest, HttpResponseInit, InvocationContext } from '@azure/functions';
import {
  BlobSASPermissions,
  generateBlobSASQueryParameters,
  StorageSharedKeyCredential,
} from '@azure/storage-blob';

import { blobNameFor, permissionFrom } from './authz';

/**
 * Mints a short-lived SAS URL for one blob, for one operation.
 *
 * The phone never holds an Azure credential (ADR-024). It proves who it is
 * with the Firebase ID token it already has from signing in (#76), and this
 * hands back a URL that is good for one file, one permission, and fifteen
 * minutes.
 *
 * Deployed from `azure/sas-function`. If the trial credit lapses, delete the
 * resource group and drop `AZURE_FILES_URL` from the build — the app is
 * written to carry on without it, which is ADR-024's third term and is
 * enforced by `test/data/remote_files_test.dart`.
 */

const ACCOUNT = process.env.STORAGE_ACCOUNT ?? '';
const ACCOUNT_KEY = process.env.STORAGE_KEY ?? '';
const CONTAINER = process.env.STORAGE_CONTAINER ?? 'family-files';
const FIREBASE_PROJECT = process.env.FIREBASE_PROJECT ?? '';

/** Fifteen minutes. Long enough for a slow upload on a bad signal, short
 *  enough that a leaked URL is not a standing grant. */
const MINUTES = 15;

/**
 * Checks the caller is who they say, against Firebase.
 *
 * Verified with Google's public keys rather than trusted, because a token
 * the client supplies is a claim and not evidence. Returns the uid, or null.
 */
async function uidFrom(request: HttpRequest): Promise<string | null> {
  const header = request.headers.get('authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token || !FIREBASE_PROJECT) return null;

  // Google's tokeninfo endpoint does the signature and expiry checking.
  // A self-rolled JWT verification here would be a second place to get
  // key rotation wrong.
  const checked = await fetch(
    `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(token)}`,
  );
  if (!checked.ok) return null;

  const claims = (await checked.json()) as { aud?: string; sub?: string };
  // The audience must be this project, or any Firebase project's token
  // would open this container.
  if (claims.aud !== FIREBASE_PROJECT) return null;
  return claims.sub ?? null;
}

export async function sas(
  request: HttpRequest,
  context: InvocationContext,
): Promise<HttpResponseInit> {
  if (!ACCOUNT || !ACCOUNT_KEY) {
    context.error('Storage is not configured on this Function');
    return { status: 500 };
  }

  const uid = await uidFrom(request);
  if (!uid) {
    return { status: 401 };
  }

  const permission = permissionFrom(request.query.get('permission'));

  // **The caller does not choose the owner.** `blobNameFor` prepends the uid
  // this request actually proved, so there is no string a client can send
  // that names somebody else's file.
  //
  // Until this line existed, the uid was verified and then used for nothing
  // but a log entry, and `key` went to the signer as it arrived — which made
  // every blob in the container readable, and writable, by anybody holding a
  // token for this project. See `authz.ts` for the whole of it.
  const blobName = blobNameFor(uid, request.query.get('key'));
  if (blobName === null) {
    return { status: 400 };
  }

  const credential = new StorageSharedKeyCredential(ACCOUNT, ACCOUNT_KEY);
  const expiresOn = new Date(Date.now() + MINUTES * 60 * 1000);

  const query = generateBlobSASQueryParameters(
    {
      containerName: CONTAINER,
      blobName,
      permissions: BlobSASPermissions.parse(permission),
      expiresOn,
    },
    credential,
  ).toString();

  const url =
    `https://${ACCOUNT}.blob.core.windows.net/${CONTAINER}/${blobName}?${query}`;

  context.log(`sas ${permission} for ${blobName} to ${uid}`);
  return { jsonBody: { url, expiresOn: expiresOn.toISOString() } };
}

app.http('sas', {
  methods: ['GET'],
  authLevel: 'anonymous', // the Firebase token is the authentication
  handler: sas,
});
