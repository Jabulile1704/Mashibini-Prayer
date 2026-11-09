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
