# Vector Store & Embeddings

## Proposal
- [ ] Create: `notes/vector-store-spec.md`. In it, come up with a number of recommended use cases for the vector store.
Each use case should get its own dedicated section. Example use cases: (i) FTS, (ii) Find similar patients. In a summary
section, create an ordered list of your most to least recommended use cases that we should consider implementing for
this app. When working on this, consider the data that we have in Mongo DB, and how we could vectorize it. You can use
`data-snippets.md` as reference.
  - Vectors should be stored on Pinecone, so logic should exist in the AI chat service to query it.
  - Should include implementation of a new service to create these embeddings and upload them to pinecone.
  - Your spec doc should also have a general list of implementation tasks. Use the below snippet as a starter
reference.

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
