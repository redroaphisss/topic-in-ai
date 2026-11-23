# Lab 4 infrastructure with the hw4 RAG application

The original stub API is replaced with `hw4/app/main.py`, its browser UI and study passages. The app uses remote OpenAI embeddings and generation, retrieves four passages, and returns cited answers. The original hw4 directory is unchanged.

Endpoints: `/` (web UI), `/healthz`, `/readyz`, and `POST /api/ask` with `{"question":"How does RAG use embeddings?"}`. The former `/predict` and `/v1/chat` stub endpoints are replaced by `/api/ask`.

## Local run

From this directory:

```bash
docker build --platform linux/amd64 -t l4-t4-api:lab .
# Enter your OpenAI API key in the webpage, or set it in your shell.
docker run --rm -p 8080:8080 -e OPENAI_API_KEY -v rag-local:/data l4-t4-api:lab
```

Open http://localhost:8080 and enter your OpenAI API key in the password field. The key is sent to this server with each question and is not saved in browser storage or on disk. Use localhost or HTTPS when supplying a key. Leaving the field blank uses the server-configured key. `/readyz` checks the server-configured key, so it may return 503 when you only supply a key through the webpage.

To check the server-configured key:

```bash
curl --fail localhost:8080/healthz
curl --fail localhost:8080/readyz
curl --fail localhost:8080/api/ask -H 'Content-Type: application/json' \
  -d '{"question":"How does RAG use embeddings?"}'
```

The application uses container paths `/app` and `/data`; use Docker for the documented local configuration.

## Build, publish, and deploy

Authenticate using `gcloud auth login` and `gcloud auth application-default login`. Keep the existing terraform.tfvars, or copy terraform/terraform.tfvars.example and set your project, region and zone.

```bash
cd terraform
terraform init
terraform apply -target=google_artifact_registry_repository.lab -target=google_project_service.services -target=google_secret_manager_secret.openai
cd ..

export PROJECT_ID="$(gcloud config get-value project)"
export REGION="us-central1" # match terraform.tfvars
export IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/l4-lab-repo/l4-lab-api:lab"
gcloud auth configure-docker "$REGION-docker.pkg.dev"
docker build --platform linux/amd64 -t "$IMAGE" .
docker push "$IMAGE"
```

Add your API key to the newly created Secret Manager secret. With Bash, enter it without echoing or placing the value in command history:

```bash
read -rs -p 'OpenAI API key: ' OPENAI_KEY
printf '%s' "$OPENAI_KEY" | gcloud secrets versions add l4-lab-openai-key --project="$PROJECT_ID" --data-file=-
unset OPENAI_KEY
```

The secret name and registry names above assume the default `name_prefix = "l4-lab"`. Terraform grants the VM service account access to this secret; the key value is not in source, metadata, or Terraform state.

```bash
cd terraform
terraform plan
terraform apply
terraform output
```

Startup installs Docker (and NVIDIA Container Toolkit when `enable_gpu = true`), authenticates to Artifact Registry, pulls the image, and runs Uvicorn with the secret version reference and a persistent `rag-index:/data` volume. Rebuild and push after app changes; if the VM already exists, restart it to rerun startup and pull the tag. Remove the index volume when changing the study passages or embedding model.

This infrastructure defaults to a CPU VM because the remote-model RAG app does not require a GPU. Add `enable_gpu = true` to terraform.tfvars only if the assignment requires a T4; this requires eligible paid billing and T4 quota. CPU resources are still billable. The VM requests an external IP. If `constraints/compute.vmExternalIpAccess` blocks creation, obtain an administrator exception or configure private networking, outbound NAT and IAP access. The PDF's `enable_public_ip=false` example is not implemented in this supplied Terraform. IAP tunneling alone does not provide a public grading URL.

After startup, use `terraform output -raw external_ip` to find the VM. Open `http://EXTERNAL_IP:8080/` and repeat the checks above using that address. `/healthz` verifies the HTTP server; `/readyz` verifies key and embedding-index initialization. Test an actual question to verify generation. Empty questions return 422; provider failures return 503; the demo allows ten questions per minute.

## Submission and cleanup

The PDF's individual deployment assignment requests the public URL, app location, and Terraform scripts, with API keys and credentials hidden. Submit this app directory, Dockerfile, requirements.txt and Terraform sources. Exclude credentials, state files and .terraform. Arrange grading with the TA and destroy resources when no longer needed:

```bash
cd terraform
terraform destroy
```

No cloud deployment or submission is performed by these file changes.
