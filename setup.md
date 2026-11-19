# Deploy the Lab-4 RAG application

Run these commands in your Mac's Terminal, outside the restricted Codex session.

## 1. Resolve the external IP policy

Ask your TA or GCP administrator to allow an external IP for this instance under `constraints/compute.vmExternalIpAccess`:

```text
projects/ieor4577-515216/zones/us-central1-a/instances/l4-lab-t4
```

This exception is required for the current Terraform configuration to create the VM.

## 2. Authenticate and create the registry and secret

```bash
cd /Users/redroaphis/columbia/topic-in-ai/Lab-4-GCP-terraform

gcloud auth login
gcloud auth application-default login
gcloud config set project ieor4577-515216

cd terraform
terraform init
terraform apply \
  -target=google_project_service.services \
  -target=google_artifact_registry_repository.lab \
  -target=google_secret_manager_secret.openai
cd ..
```

Review the Terraform changes and enter `yes` when prompted.

## 3. Build and push the application image

Start Docker Desktop and wait until it is running, then execute:

```bash
export IMAGE="us-central1-docker.pkg.dev/ieor4577-515216/l4-lab-repo/l4-lab-api:lab"

gcloud auth configure-docker us-central1-docker.pkg.dev
docker build --platform linux/amd64 -t "$IMAGE" .
docker push "$IMAGE"
```

## 4. Store the OpenAI API key

Run the following in your default macOS zsh shell. Paste your key at the prompt; it will not be displayed or included in shell history.

```zsh
read -s 'OPENAI_KEY?OpenAI API key: '
echo
printf '%s' "$OPENAI_KEY" |
  gcloud secrets versions add l4-lab-openai-key \
    --project=ieor4577-515216 --data-file=-
unset OPENAI_KEY
```

## 5. Deploy

```bash
cd terraform
terraform plan
terraform apply
```

Review the changes and enter `yes` when prompted. First startup can take several minutes while drivers and Docker are initialized and the image is downloaded.

## 6. Open and verify the app

```bash
export EXTERNAL_IP="$(terraform output -raw external_ip)"
echo "http://${EXTERNAL_IP}:8080"

curl --fail "http://${EXTERNAL_IP}:8080/healthz"
curl --fail "http://${EXTERNAL_IP}:8080/readyz"
curl --fail "http://${EXTERNAL_IP}:8080/api/ask" \
  -H 'Content-Type: application/json' \
  -d '{"question":"How does RAG use embeddings?"}'
```

Open the printed URL in your browser. `/healthz` checks the HTTP server, `/readyz` checks key access and embedding-index initialization, and `/api/ask` checks answer generation.

If any command fails, stop and share the error before continuing. Do not share API keys or credentials.

## 7. Clean up when finished

Arrange grading with your TA before removing the deployment. The T4 VM incurs charges while running.

From `Lab-4-GCP-terraform/terraform`:

```bash
terraform destroy
```

Review the resources to be removed before entering `yes`.
