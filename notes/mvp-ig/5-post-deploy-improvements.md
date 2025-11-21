# Post-Deploy Improvements (Phase 2+)

Once the initial MVP is deployed and stable, use this document to track incremental upgrades toward a more production-like system.

---

## 1. Real LLM (Qwen3-4B-Thinking-2507, CPU)

### 1.1 Implement LLM_MODE=Qwen3-4B-Thinking-2507

Ref: https://huggingface.co/Qwen/Qwen3-4B-Thinking-2507

- [x] If possible, make it such that we can automatically download this model.
  - [x] Use hugging face python library if possible. If need help with auth, prompt user.
  - [x] Have makefile command(s) to do the download.
  - [x] Ensure that deployment (dockerfile, terraform setup) is set up in such a way that it is set up to dowlnoad the
    model during the container set up process, and that the LLM is able to be utilized in the deployed service.

- [x] In `llm_client.py`:
  - [x] Load Qwen3-4B-Thinking-2507 with Hugging Face on CPU
  - [x] Implement `generate_response_qwen(query, patient_summary, optional_docs)`

- [x] Control behavior via `LLM_MODE`:
  - [x] `"mock"` – current MVP behavior
  - [x] `"qwen"` – real inference

- [x] Renames if necessary: If there are refs in the codebase that say `LLM_MODE=qwen`, change that to say
`LLM_MODE=Qwen3-4B-Thinking-2507` instead.

This should involve a hugging face library to download the model if it is not present on disk. Prompt the user for 
environment variables if needed to execute the download.

Likely use transformers library to interact with the LLM; use your best judgement.

### 1.2 Gradual Rollout

- [x] Write a document: `notes/rollout-options.md`, that explains some different options: (i) replacing all pods at once with
the new ones, one at a time, until all pods are the new version, (ii) a feature-controlling scheme where a certain % of
traffic / users are routed to the new version of the app, (iii) separate deployments entirely for staging and prod.
- [x] For now, though, we're going to go with option (i), so create a task document, `notes/ai-service-upgrade.md`,
where you create a list of markdown checkbox tasks to execute to go about executing this deployment. But don't get
started on that work until prompted.

### 1.3. Docs
- [x] `docs/models.md`: Write about how the setup works, how to download models, and how to deploy new models, and do
rollbacks to change to a previous deployment, or select different LLM_MODE's. Link to the document in `README.md`.

---

## 2. Observability & Monitoring

### 2.1 OpenTelemetry

- [ ] Replace custom tracing with OpenTelemetry:
  - [ ] Install OTEL SDK
  - [ ] Instrument FastAPI apps and HTTP clients
  - [ ] Configure exporter (e.g. CloudWatch, OTEL collector, Grafana Cloud)

### 2.2 Metrics

- [ ] Add metrics for:
  - [ ] Request counts, latency, and error rates per endpoint
  - [ ] LLM latency and errors
  - [ ] Pinecone query latency
  - [ ] DB query latency

- [ ] Create dashboards showing:
  - [ ] p50/p95/p99 latency for `/triage`
  - [ ] HPA scaling behavior over time

### 2.3. Docs
- [ ] `docs/observability.md`: Document the metrics that are tracked, and how to access them. Link to the document in 
`README.md`.

---

## 3. Load Testing (Scenario 3)

- [ ] Choose k6 or Locust
- [ ] Create load test scripts for:
  - [ ] Sustained, moderate load on `/triage`
  - [ ] Short, high-burst load simulating marketing push

- [ ] Measure:
  - [ ] Error rate
  - [ ] p95 latency
  - [ ] CPU utilization before and during scale-out

- [ ] Produce a simple Markdown/HTML report summarizing:
  - [ ] Test conditions
  - [ ] Results
  - [ ] Observed scaling

- [ ] Makefile commands

- [ ] Docs: `docs/load-testing.md`.  Link to the document in `README.md`.

---

## 4. Synthetic data improvements
Up until now, we probably have usedthe same snippets in `data-snippets.md`, or something close to it; just 1 record for 
each model. Now, expand on that to create additional records--let's say, 10 each.

- [ ] Generate JSONL files with shapes matching `data-snippets.md`:
  - [ ] `data/synthetic/patients.jsonl`
  - [ ] `data/synthetic/encounters.jsonl`
  - [ ] `data/synthetic/claims.jsonl`
  - [ ] `data/synthetic/documents.jsonl`
  - [ ] `data/synthetic/chat_logs.jsonl`
  - [ ] (Optional) providers/audit_logs JSONL files

- [ ] Load Mongo DB with the new data.

---

## 5. Vector Store & Embeddings

### 5.1. Proposal
- [ ] Craate: `notes/vector-store-spec.md`. In it, come up with a number of recommended use cases for the vector store. 
Each use case should get its own dedicated section. Example use cases: (i) FTS, (ii) Find similar patients. In a summary 
section, create an ordered list of your most to least recommended use cases that we should consider implementing for 
this app. When working on this, consider the data that we have in Mongo DB, and how we could vectroize it. You can use 
`data-snippets.md` as reference.
  - Vectors should be stored on Pinecone, so logic should exist in the AI chat service to query it.
  - Should include implementation of a new service to create these embeddings and upload them to pinecone. 
  - Your spec doc should also have a general list of implementation tasks. Use the below snippet as a starter 
reference. 

```md
# Vector store
## Enable VECTOR_MODE=pinecone

- [ ] Switch `VECTOR_MODE` to `"pinecone"` in config when ready
- [ ] In `rag_service.py`:
  - [ ] Add embedding function for queries (hash-based or lightweight model)
  - [ ] Call `pinecone_client.query_embeddings` with query vector
  - [ ] Filter by `patient_mrn` as appropriate

## Use Pinecone Results in /triage

- [ ] Extend `build_prompt`:
  - [ ] Retrieve top_k document snippets from Pinecone
  - [ ] Join them into the prompt alongside patient summary
- [ ] Make RAG behavior configurable via env var (e.g. `ENABLE_VECTOR_CONTEXT`)

# Embedding service, and Async Ingestion & Update Pipelines
## Embedding Service

- [ ] Optionally create `service_embeddings/`:
  - [ ] FastAPI with endpoint to accept doc/patient data
  - [ ] Generate embeddings and upsert to Pinecone

- [ ] Introduce eventing:
  - [ ] When Mongo docs change, emit events to queue (e.g. SQS/Kafka)
  - [ ] `service_embeddings` consumes and updates vector DB

## Freshness Checks

- [ ] Build a script or job to:
  - [ ] Compare docs in Mongo with entries in Pinecone
  - [ ] Log or alert on missing or stale embeddings
```

---

## 7. Reliability / Incident Playbooks (Scenario 4)

- [ ] Create a brief runbook:
  - [ ] How to roll back deployment (e.g. `kubectl rollout undo`)
  - [ ] How to quickly scale replicas manually
  - [ ] How to locate logs and traces for a specific `trace_id`

- [ ] Define SLOs:
  - [ ] e.g. `/triage` p95 latency < 3s under normal load
  - [ ] Document basic error budget thinking

---

## 8. Security, Secrets & PHI

- [ ] Replace plaintext env vars for secrets with:
  - [ ] AWS Secrets Manager or SSM Parameter Store
  - [ ] Terraform-managed K8s Secrets sourced from those stores

- [ ] Implement real `scrub()` in `scrub_phi.py`:
  - [ ] Strip or mask:
    - [ ] Names
    - [ ] MRNs
    - [ ] DOBs
    - [ ] Other PHI fields in logs
  - [ ] Avoid logging full free-text queries if they may contain PHI

---

## 9. Optional Future Work

- [ ] Add Redis cache:
  - [ ] Cache patient summaries
  - [ ] Cache recent LLM responses

- [ ] Add CI/CD:
  - [ ] GitHub Actions pipeline for build/test/push
  - [ ] Optional Terraform apply with manual approval

- [ ] Extend APIs:
  - [ ] More clinical data types (labs, tasks, care-gap summaries)
  - [ ] More analytics endpoints built over Mongo aggregations
