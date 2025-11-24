# AI Service Local Development Updates

Tasks for improving the local LLM development experience.

---

## 1. Response Timing Tracking

Track and display how long LLM inference takes.

### Backend Tasks

- [x] Add `inference_time_ms` field to triage response
  - [x] Capture start time before LLM inference in `llm_client.py`
  - [x] Calculate elapsed time after inference completes
  - [x] Return `inference_time_ms` in the API response JSON

- [x] Store timing in chat logs
  - [x] Add `inference_time_ms` field to chat log schema in `service_db_api`
  - [x] Update `chat_log_client.py` to include timing when storing logs
  - [x] Update MongoDB model/schema if needed

### Frontend Tasks

- [x] Display elapsed time counter while waiting
  - [x] Add a timer component that counts up (seconds/minutes) while request is pending
  - [x] Start timer when request is sent
  - [x] Stop timer when response is received

- [x] Display final inference time
  - [x] Show `inference_time_ms` from response after completion
  - [x] Format as human-readable (e.g., "7m 21s" or "441.9s")

---

## Notes
- Model is cached in memory after first load, subsequent requests faster
