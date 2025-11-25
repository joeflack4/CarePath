# Load Testing Implementation Guide

## Overview
Implement load testing infrastructure using **Locust** (Python-based, easier to integrate with existing Python codebase) to test DB API and Chat API independently.

**Key Metrics:**
- Error rate
- P95 latency (target: 100ms for DB API, longer for Chat API due to LLM inference)
- RPS levels: 10, 100, 1000

**Target APIs:**
- DB API (port 8001): Fast responses expected
- Chat API (port 8002): Uses actual LLM (6-7 min inference time on CPU)

---

## Implementation Tasks

### Phase 1: Setup & Dependencies

- [ ] Create `infra/load_tests/` directory structure
- [ ] Create `infra/load_tests/requirements.txt` with Locust dependency
- [ ] Add Locust install command to Makefile (`make install-load-tests`)
- [ ] Create `.env` variables for load test configuration (API URLs, default settings)

### Phase 2: DB API Load Tests

- [ ] Create `infra/load_tests/db_api_locustfile.py`
  - [ ] Health check endpoint test (`GET /health`)
  - [ ] Patient list endpoint test (`GET /patients`)
  - [ ] Patient by MRN endpoint test (`GET /patients/{mrn}`)
  - [ ] Patient summary endpoint test (`GET /patients/{mrn}/summary`)
  - [ ] Encounters endpoint test (`GET /encounters`)
  - [ ] Claims endpoint test (`GET /claims`)
  - [ ] Documents endpoint test (`GET /documents`)
- [ ] Configure realistic task weights (summary endpoint most used)
- [ ] Add response validation (check status codes, response structure)

### Phase 3: Chat API Load Tests

- [ ] Create `infra/load_tests/chat_api_locustfile.py`
  - [ ] Health check endpoint test (`GET /health`)
  - [ ] Triage endpoint test (`POST /triage`)
- [ ] Configure longer timeout for LLM inference (10+ minutes)
- [ ] Add sample patient MRNs and queries for realistic testing
- [ ] Add response validation (check for required fields: response, trace_id, etc.)

### Phase 4: Configuration Presets

- [ ] Create `infra/load_tests/configs/` directory
- [ ] Create preset config files:
  - [ ] `db_api_10rps.json` - 10 RPS for DB API
  - [ ] `db_api_100rps.json` - 100 RPS for DB API
  - [ ] `db_api_1000rps.json` - 1000 RPS for DB API
  - [ ] `chat_api_10rps.json` - 10 RPS for Chat API
  - [ ] `chat_api_100rps.json` - 100 RPS for Chat API (may timeout)
  - [ ] `chat_api_1000rps.json` - 1000 RPS for Chat API (may timeout)
- [ ] Each config should specify: users, spawn_rate, run_time, host

### Phase 5: Makefile Commands

- [ ] Add `make load-test-db-api` - Run DB API load test with default settings
- [ ] Add `make load-test-chat` - Run Chat API load test with default settings
- [ ] Add `make load-test-db-api-10rps` - 10 RPS preset
- [ ] Add `make load-test-db-api-100rps` - 100 RPS preset
- [ ] Add `make load-test-db-api-1000rps` - 1000 RPS preset
- [ ] Add `make load-test-chat-10rps` - 10 RPS preset
- [ ] Add `make load-test-chat-100rps` - 100 RPS preset
- [ ] Add `make load-test-chat-1000rps` - 1000 RPS preset
- [ ] Add `make load-test-web` - Start Locust web UI for interactive testing
- [ ] Add `make load-test-report` - Generate HTML report from last run

### Phase 6: Results & Reporting

- [ ] Create `infra/load_tests/results/` directory (gitignored)
- [ ] Configure Locust to output CSV stats to results directory
- [ ] Add timestamp-based result file naming
- [ ] Create simple Python script to format results summary (`infra/load_tests/format_results.py`)
- [ ] Add `make load-test-results` command to display latest results

### Phase 7: Documentation

- [ ] Create `docs/infra-load-testing.md` with:
  - [ ] Overview and purpose
  - [ ] Installation instructions
  - [ ] Available Makefile commands
  - [ ] Configuration options
  - [ ] Understanding the results (metrics explained)
  - [ ] Interpreting P95 latency
  - [ ] RPS preset descriptions
  - [ ] Troubleshooting common issues
  - [ ] Notes on Chat API LLM inference times

### Phase 8: Testing & Validation

- [ ] Test load tests against local DB API
- [ ] Test load tests against local Chat API (mock mode first)
- [ ] Test load tests against local Chat API (actual LLM mode)
- [ ] Verify all Makefile commands work
- [ ] Verify results are saved correctly
- [ ] Test against cloud deployment (optional)

---

## Technical Notes

### Why Locust over k6?
- **Python-based**: Integrates naturally with existing Python codebase
- **No Go/JavaScript needed**: Team already familiar with Python
- **Easy to extend**: Can add custom metrics, validations
- **Web UI**: Built-in web interface for interactive testing
- **Docker-friendly**: Easy to containerize for distributed testing

### RPS Configuration Strategy
For Locust, users = concurrent users, not RPS directly. To achieve target RPS:
- RPS ≈ users × (1 / avg_response_time)
- For DB API (fast, ~10ms): 10 RPS ≈ 1-2 users, 100 RPS ≈ 10-20 users, 1000 RPS ≈ 100-200 users
- For Chat API (slow, ~6-7 min): 10 RPS would require 3600+ concurrent users (impractical)

### Chat API Considerations
- Actual LLM inference takes 6-7 minutes on CPU
- High RPS tests (100, 1000) will likely result in timeouts or queue buildup
- Consider testing Chat API at lower RPS (1-10) or with longer timeouts
- Results will reflect real-world infrastructure capacity

### Directory Structure
```
infra/load_tests/
├── requirements.txt
├── db_api_locustfile.py
├── chat_api_locustfile.py
├── format_results.py
├── configs/
│   ├── db_api_10rps.json
│   ├── db_api_100rps.json
│   ├── db_api_1000rps.json
│   ├── chat_api_10rps.json
│   ├── chat_api_100rps.json
│   └── chat_api_1000rps.json
└── results/           # gitignored
    └── *.csv
```

---

## Questions/Decisions Made

1. **Tool choice**: Locust (Python) - easier integration with existing codebase
2. **LLM mode for Chat API tests**: Actual LLM (per user request) - note that high RPS tests may timeout
3. **Results storage**: Local CSV files with timestamps, gitignored
