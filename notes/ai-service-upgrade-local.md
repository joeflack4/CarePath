# AI Service Local Development Updates

Tasks for improving the local LLM development experience.

---

## 1. Response Timing Tracking

Track and display how long LLM inference takes.

### Backend Tasks

- [ ] Add `inference_time_ms` field to triage response
  - [ ] Capture start time before LLM inference in `llm_client.py`
  - [ ] Calculate elapsed time after inference completes
  - [ ] Return `inference_time_ms` in the API response JSON

- [ ] Store timing in chat logs
  - [ ] Add `inference_time_ms` field to chat log schema in `service_db_api`
  - [ ] Update `chat_log_client.py` to include timing when storing logs
  - [ ] Update MongoDB model/schema if needed

### Frontend Tasks

- [ ] Display elapsed time counter while waiting
  - [ ] Add a timer component that counts up (seconds/minutes) while request is pending
  - [ ] Start timer when request is sent
  - [ ] Stop timer when response is received

- [ ] Display final inference time
  - [ ] Show `inference_time_ms` from response after completion
  - [ ] Format as human-readable (e.g., "7m 21s" or "441.9s")

---

## 2. Thinking Output Configuration

The Qwen3 model outputs "thinking" text before the actual response. This should be configurable.

### Problem

The model's output includes internal reasoning/thinking wrapped in tags like:
```
<thinking>
Okay, the user is asking about their medications...
</thinking>
<response>
Your current medication is Metformin 500mg...
</response>
```

Currently, the full output (including thinking) is being returned.

### Backend Tasks

- [ ] Add `SHOW_THINKING` configuration option
  - [ ] Add to `service_chat/config.py`: `SHOW_THINKING: bool = False`
  - [ ] Add to `.env.example` with documentation

- [ ] Implement thinking text filtering in `llm_client.py`
  - [ ] If `SHOW_THINKING=False`: Strip `<thinking>...</thinking>` blocks from response
  - [ ] If `SHOW_THINKING=True`: Return full response including thinking
  - [ ] Handle edge cases (malformed tags, multiple thinking blocks, etc.)

### Documentation Tasks

- [ ] Create `docs/configuration.md`
  - [ ] Document all environment variables for service_chat
  - [ ] Include `SHOW_THINKING` with description and default value
  - [ ] Include `LLM_MODE`, `MODEL_CACHE_DIR`, etc.

- [ ] Update `README.md`
  - [ ] Add link to `docs/configuration.md`
  - [ ] Brief mention of configuration options in relevant section

---

## 3. Related Fixes (Already Completed)

These items were completed during the initial local LLM setup:

- [x] Fixed `MODEL_CACHE_DIR` configuration not being read from `.env`
  - Added `MODEL_CACHE_DIR` to `service_chat/config.py`
  - Updated `model_manager.py` to use settings instead of direct `os.environ`

- [x] Added `accelerate` dependency to `requirements.txt`
  - Required for `device_map` parameter in model loading

---

## Notes

- CPU inference is slow (~7 minutes for a single response on first request)
- Model is cached in memory after first load, subsequent requests faster
- Consider GPU instances for production deployment
