# Post-Deploy Improvements (Phase 2+)

Once the initial MVP is deployed and stable, use this document to track incremental upgrades toward a more production-like system.

---

## 2. Real LLM (Qwen3-4B-Thinking-2507, CPU)

### 2.1 Implement LLM_MODE=qwen

- [ ] In `llm_client.py`:
  - [ ] Load Qwen3-4B-Thinking-2507 with Hugging Face on CPU
  - [ ] Implement `generate_response_qwen(query, patient_summary, optional_docs)`

- [ ] Control behavior via `LLM_MODE`:
  - [ ] `"mock"` – current MVP behavior
  - [ ] `"qwen"` – real inference

This should involve a hugging face library to download the model if it is not present on disk. Prompt the user for 
environment variables if needed to execute the download.

Likely use transformers library to interact with the LLM; use your best judgement.

### 2.2 Gradual Rollout

- [ ] Start with local tests only
- [ ] Add a staging environment, or dev namespace in EKS
- [ ] Only enable `LLM_MODE=qwen` in non-prod first

---

## 5. Observability & Monitoring

### 5.1 OpenTelemetry

- [ ] Replace custom tracing with OpenTelemetry:
  - [ ] Install OTEL SDK
  - [ ] Instrument FastAPI apps and HTTP clients
  - [ ] Configure exporter (e.g. CloudWatch, OTEL collector, Grafana Cloud)

### 5.2 Metrics

- [ ] Add metrics for:
  - [ ] Request counts, latency, and error rates per endpoint
  - [ ] LLM latency and errors
  - [ ] Pinecone query latency
  - [ ] DB query latency

- [ ] Create dashboards showing:
  - [ ] p50/p95/p99 latency for `/triage`
  - [ ] HPA scaling behavior over time

---

## 6. Load Testing (Scenario 3)

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

---

## 3. Synthetic data improvements
Up until now, we probably have usedthe same snippets in `data-snippets.md`, or something close to it; just 1 record for 
each model. Now, expand on that to create additional records--let's say, 10 each.

- [ ] Generate JSONL files with shapes matching `data-snippets.md`:
  - [ ] `data/synthetic/patients.jsonl`
  - [ ] `data/synthetic/encounters.jsonl`
  - [ ] `data/synthetic/claims.jsonl`
  - [ ] `data/synthetic/documents.jsonl`
  - [ ] `data/synthetic/chat_logs.jsonl`
  - [ ] (Optional) providers/audit_logs JSONL files

---

## 1. Vector Store & Embeddings (Pinecone)

### 1.1 Enable VECTOR_MODE=pinecone

- [ ] Switch `VECTOR_MODE` to `"pinecone"` in config when ready
- [ ] In `rag_service.py`:
  - [ ] Add embedding function for queries (hash-based or lightweight model)
  - [ ] Call `pinecone_client.query_embeddings` with query vector
  - [ ] Filter by `patient_mrn` as appropriate

### 1.2 Use Pinecone Results in /triage

- [ ] Extend `build_prompt`:
  - [ ] Retrieve top_k document snippets from Pinecone
  - [ ] Join them into the prompt alongside patient summary
- [ ] Make RAG behavior configurable via env var (e.g. `ENABLE_VECTOR_CONTEXT`)

---

## 4. Async Ingestion & Update Pipelines

### 4.1 Embedding Service

- [ ] Optionally create `service_embeddings/`:
  - [ ] FastAPI with endpoint to accept doc/patient data
  - [ ] Generate embeddings and upsert to Pinecone

- [ ] Introduce eventing:
  - [ ] When Mongo docs change, emit events to queue (e.g. SQS/Kafka)
  - [ ] `service_embeddings` consumes and updates vector DB

### 4.2 Freshness Checks

- [ ] Build a script or job to:
  - [ ] Compare docs in Mongo with entries in Pinecone
  - [ ] Log or alert on missing or stale embeddings

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
