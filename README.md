# Topics in AI

Coursework and a retrieval-augmented generation (RAG) application with Google Cloud deployment infrastructure.

See [Lab 4](lab4/README.md) for application setup and Terraform deployment instructions.

Local credentials, Terraform state, variable files, and generated caches are excluded from version control. Configure deployment values using `lab4/terraform/terraform.tfvars.example`.

# assignment3

![Application interface](lab4/app_interface.png)

![Public IP blocked](lab4/blocked_ip.png)

Deploy the RAG application to Google Cloud project `YOUR_GCP_PROJECT_ID` using the Terraform configuration in `lab4/terraform`. Set `YOUR_GCP_PROJECT_ID` to your Google Cloud project ID in the export command below, and use the same value in `terraform.tfvars`. Run the following steps from the repository root with Terraform, the Google Cloud CLI, and Docker installed, and Docker running.

The project needs billing enabled, permission to create the configured resources, a default VPC, and permission to assign an external IP. The remote-model RAG app deploys without a GPU by default. If the assignment requires a T4, add `enable_gpu = true` to `terraform.tfvars`; GPU mode requires an eligible paid billing account and T4 quota in the selected zone. CPU deployment still uses billable resources.

### 1. Authenticate and select the project

In addition to `gcloud auth login`, Terraform needs [Application Default Credentials](https://docs.cloud.google.com/docs/terraform/authentication):

```sh
export YOUR_GCP_PROJECT_ID="your-project-id"
gcloud config set project "$YOUR_GCP_PROJECT_ID"
gcloud auth application-default login
gcloud auth application-default set-quota-project "$YOUR_GCP_PROJECT_ID"

cd lab4/terraform
terraform init
terraform workspace new "$YOUR_GCP_PROJECT_ID"
```

If the workspace already exists, run `terraform workspace select "$YOUR_GCP_PROJECT_ID"` instead. The existing default workspace state may reference another project; keep it intact and use the `YOUR_GCP_PROJECT_ID` workspace for this deployment. Workspaces separate state, but do not select the Google Cloud project.

Write the exported project ID into the local `terraform.tfvars` file using the following command from `lab4/terraform`. This replaces that file with the three deployment settings below; preserve any optional overrides you need before running it. Shell exports do not substitute placeholders inside `.tfvars` files.

```sh
cat > terraform.tfvars <<EOF
project_id = "$YOUR_GCP_PROJECT_ID"
region     = "us-central1"
zone       = "us-central1-a"
EOF
cat terraform.tfvars
```

Confirm `project_id` shows your actual project ID, rather than `YOUR_GCP_PROJECT_ID` or `your-project-id`, before running Terraform.

The commands below assume the default `name_prefix = "l4-lab"` and `image_tag = "lab"`.

### 2. Create the registry and secret container

The container image and API key must be available before the VM starts. Bootstrap these resources first, review the plan, and enter `yes`:

```sh
terraform apply \
  -target=google_project_service.services \
  -target=google_artifact_registry_repository.lab \
  -target=google_secret_manager_secret.openai
```

### 3. Build and upload the application

```sh
cd ..

export PROJECT_ID="$YOUR_GCP_PROJECT_ID"
export REGION="us-central1"
export IMAGE="$REGION-docker.pkg.dev/$PROJECT_ID/l4-lab-repo/l4-lab-api:lab"

gcloud auth configure-docker "$REGION-docker.pkg.dev"
docker build --platform linux/amd64 -t "$IMAGE" .
docker push "$IMAGE"
```

### 4. Store the OpenAI API key

Run these commands in **zsh**. The prompt hides the key while typing and keeps its value out of shell history. The VM reads the key from Secret Manager; Terraform does not store its value in state.

```zsh
read -rs 'OPENAI_KEY?OpenAI API key: '
printf '\n'
printf '%s' "$OPENAI_KEY" | gcloud secrets versions add l4-lab-openai-key \
  --project="$PROJECT_ID" --data-file=-
unset OPENAI_KEY
```

### 5. Deploy the VM

```sh
cd terraform
terraform workspace show
terraform plan -out=deploy.tfplan
terraform apply deploy.tfplan
terraform output
```

Confirm the workspace is `YOUR_GCP_PROJECT_ID` and review the saved plan before applying it. Startup can take several minutes while drivers and Docker are initialized and the image is pulled.

### 6. Verify the application

```sh
export APP_IP="$(terraform output -raw external_ip)"

curl --fail "http://$APP_IP:8080/healthz"
curl --fail "http://$APP_IP:8080/readyz"
curl --fail "http://$APP_IP:8080/api/ask" \
  -H 'Content-Type: application/json' \
  -d '{"question":"How does RAG use embeddings?"}'
```

Open `http://EXTERNAL_IP:8080/`, replacing `EXTERNAL_IP` with the `external_ip` output. Leave the webpage's key field blank to use the server-configured key. Use HTTPS if supplying a key through the webpage.

If an organization policy blocks external IP creation, obtain an administrator exception or configure private networking, outbound NAT, and IAP access. The supplied Terraform always requests an external IP; it does not implement `enable_public_ip=false`. IAP alone does not provide a public grading URL.

### 7. Clean up

When grading is complete, destroy this deployment to stop ongoing VM charges. From `lab4/terraform`:

```sh
terraform workspace select "$YOUR_GCP_PROJECT_ID"
terraform plan -destroy
terraform destroy
```

Review the resources before confirming destruction. Keep credentials, Terraform state, local variable files, and saved plans out of submissions and version control.
