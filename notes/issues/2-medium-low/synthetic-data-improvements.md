# Synthetic Data Improvements

Up until now, we probably have used the same snippets in `data-snippets.md`, or something close to it; just 1 record for
each model. Now, expand on that to create additional records--let's say, 10 each.

- [ ] Generate JSONL files with shapes matching `data-snippets.md`:
  - [ ] `data/synthetic/patients.jsonl`
  - [ ] `data/synthetic/encounters.jsonl`
  - [ ] `data/synthetic/claims.jsonl`
  - [ ] `data/synthetic/documents.jsonl`
  - [ ] `data/synthetic/chat_logs.jsonl`
  - [ ] (Optional) providers/audit_logs JSONL files

- [ ] Load Mongo DB with the new data.
