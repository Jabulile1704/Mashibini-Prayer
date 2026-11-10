# Azure — a spike, and how to delete it

Read [ADR-024](../docs/adr/ADR-024-azure-is-a-spike-and-must-stay-disposable.md)
first. The short version: the owner has **$200 of credit for 30 days**, and
Azure's own page says that when it lapses, *"your account and services will
be disabled"* — with nothing stated about whether data survives.

So this exists on three terms, and the third is the one that matters:

1. A `RemoteFiles` seam, with Azure behind it.
2. The family's data does **not** move. Firestore keeps the document.
3. **Nothing may depend on it.** The app behaves exactly as it does today
   without any of this.

Term 3 is enforced, not hoped for: `test/data/remote_files_test.dart` runs
the unreachable, erroring and nonsense-answering cases and requires that
every one of them returns quietly.

## Deleting it

The thing to know before building it. When the credit runs out:

```sh
az group delete --name mashibini-files --yes
```

and drop `AZURE_FILES_URL` from the build. **That is the whole removal.**
No Dart changes. If a code change turns out to be needed, term 3 was not
honoured and the bug is in this repository rather than in Azure.

## What it is

```text
  phone ──(Firebase ID token)──► Function ──► SAS URL (15 min, one blob)
  phone ─────────────(PUT bytes)──────────────► Blob
```

The phone never holds a storage credential. The Function verifies the
Firebase token against Google's `tokeninfo` endpoint — verified rather than
trusted, because a token the client supplies is a claim and not evidence —
and checks the audience is this project, or any Firebase project's token
would open the container.

### Who may name which blob

**The caller does not choose the owner.** The blob is always
`<uid>/<key>`, with the uid taken from the token the request actually
proved and prepended by the Function. There is no string a client can send
that reaches another person's prefix — authorisation by construction rather
than by blocklist, which matters because a blocklist has to anticipate the
input and this does not.

`authz.ts` is the whole of that decision, in a file with no imports so it
can be tested without an Azure SDK, a Function host or a network.
`npm test` runs it, and CI runs it in the "Security rules" job.

It was not always so. The first version verified the token, used the uid for
a log line, and signed for whatever `key` the query string asked for — so
any holder of a valid token for this project could read, or overwrite, every
blob in the container. Google sign-in admits any Google account, which makes
"a valid token for this project" very nearly "anybody". It was never
deployed and nothing in the app ever called it; it was wrong code rather
than an exposure.

### What this cannot do yet

**Nobody can read anybody else's files, including their own family's.**

That is narrower than this spike exists for — the point was that
photographs and audio stop being stuck on one phone — and it is where it
stops, because **the Function cannot tell who is in which family.** It holds
a storage key and nothing else; membership lives in Firestore, which it
never reads.

Widening it is not a change to the rule above but the addition of a second
one, and it needs membership a caller cannot forge:

- the Firebase Admin SDK reading `families/{id}.memberUids` with service
  credentials, which means putting a service account into the Function's app
  settings; or
- a custom claim minted when somebody joins a family, so the token itself
  carries the family id.

Until one of those exists, "only your own" is the honest ceiling. It is
less than was wanted and more than was there.

## Building it

Costs are the open question. Azure's Blob pricing page renders its
per-GB figures as `$-` placeholders and **no free Blob allowance could be
found** — which is why this is a spike and not an adoption. Get real
numbers from the pricing calculator before relying on it.

```sh
az group create --name mashibini-files --location southafricanorth

az storage account create \
  --name mashibinifiles --resource-group mashibini-files \
  --sku Standard_LRS --kind StorageV2 --access-tier Hot

az storage container create \
  --name family-files --account-name mashibinifiles
```

Then the Function, with the settings it needs:

```sh
cd azure/sas-function && npm install && npm run build

az functionapp create \
  --name mashibini-sas --resource-group mashibini-files \
  --storage-account mashibinifiles \
  --consumption-plan-location southafricanorth \
  --runtime node --runtime-version 20 --functions-version 4

az functionapp config appsettings set \
  --name mashibini-sas --resource-group mashibini-files \
  --settings \
    STORAGE_ACCOUNT=mashibinifiles \
    STORAGE_KEY="$(az storage account keys list \
      --account-name mashibinifiles --query '[0].value' -o tsv)" \
    STORAGE_CONTAINER=family-files \
    FIREBASE_PROJECT=<the Firebase project id>

func azure functionapp publish mashibini-sas
```

**`STORAGE_KEY` is a real secret.** It never goes in this repository, never
in the app, and never in a `--dart-define`. It lives in the Function's app
settings and nowhere else — the whole reason the Function exists is so the
phone does not need it.

## Pointing the app at it

```sh
flutter build ios --release \
  --dart-define=AZURE_FILES_URL=https://mashibini-sas.azurewebsites.net/api/sas
```

Leave the define out and the app is exactly what it is today: files on the
phone, not shared, nothing broken.

## What is not here

**No Cosmos DB.** Its free tier is real and free forever — 1,000 RU/s and
25 GB, one account per subscription, though its own FAQ contradicts that
with 400 RU/s and 5 GB, so check the portal. It still is not worth taking:
Firestore's free tier already covers a four-person rota, and ADR-003 leans
on Firestore's offline persistence rather than building a write queue.
Moving to Cosmos would mean building that queue, which is the expensive
part of offline-first and the thing the architecture deliberately avoided.

**No Entra ID.** Google sign-in shipped on Day 26 and four people with
Android phones already have Google accounts.
