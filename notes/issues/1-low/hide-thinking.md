
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
