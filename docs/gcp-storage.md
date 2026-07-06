# GCP Cloud Storage setup (images + model artifacts)

Decision (2026-07-05): cloud object storage = **GCP Cloud Storage**; local development uses
**fake-gcs-server** so the exact same client code runs in both environments.

## Local (already wired)
`infra/docker-compose.yml` runs `fsouza/fake-gcs-server` on port 4443. Clients point at it
via the `GCS_ENDPOINT=http://localhost:4443` env var; no credentials needed.

Python example (ml-service, when the owner gets there):
```python
from google.cloud import storage

client = storage.Client(client_options={"api_endpoint": os.environ["GCS_ENDPOINT"]})
```
Java (api): the `gcs.endpoint` / `gcs.bucket` keys are already in `application.yml`;
`com.google.cloud:google-cloud-storage` honors a custom host via
`StorageOptions.newBuilder().setHost(...)`.

When `GCS_ENDPOINT` is unset, clients fall back to real GCS + Application Default
Credentials — that's the only difference between dev and prod.

## Real GCP setup (ticket P2-04, one-time)
1. Create a GCP project (free tier: 5 GB-months US regional storage, always-free).
2. `gcloud storage buckets create gs://healthhub-images --location=us-east1 --uniform-bucket-level-access`
3. Service account with `roles/storage.objectAdmin` scoped to the bucket; download the JSON
   key → set `GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json` (gitignored, see
   `infra/.env.example`).
4. Optional lifecycle rule: delete raw uploads > 1 year old, or transition to Nearline.

## Layout convention
```
healthhub-images/
├── meals/{userId}/{yyyy-MM-dd}/{uuid}.jpg      # food photos
├── body/{userId}/{yyyy-MM-dd}/{uuid}.jpg       # progress photos (body-fat model)
├── face/{userId}/{yyyy-MM-dd}/{uuid}.jpg       # acne model
└── models/{model-name}/{version}/weights.safetensors
```
Postgres stores only object paths + metadata, never image bytes.
