# Load Testing

Load testing infrastructure for CarePath AI using Locust.

## Quick Start

```bash
# 1. Install dependencies
make install-load-tests

# 2. Start the API you want to test
make run-db-api   # or make run-chat

# 3. Run a load test
make load-test-db-api-10rps
```

## Available Tests

### DB API
- `make load-test-db-api` - Default test
- `make load-test-db-api-10rps` - 10 RPS target
- `make load-test-db-api-100rps` - 100 RPS target
- `make load-test-db-api-1000rps` - 1000 RPS target

### Chat API
- `make load-test-chat` - Default test
- `make load-test-chat-10rps` - 10 RPS target (expect long duration)
- `make load-test-chat-100rps` - 100 RPS target (will timeout)
- `make load-test-chat-1000rps` - 1000 RPS target (stress test)

### Interactive Mode
- `make load-test-web-db-api` - Web UI for DB API (http://localhost:8089)
- `make load-test-web-chat` - Web UI for Chat API (http://localhost:8089)

## View Results

```bash
make load-test-results
```

Results are saved to `results/` directory (gitignored).

## Documentation

See comprehensive documentation at: **[docs/infra-load-testing.md](../../docs/infra-load-testing.md)**

## Files

- `db_api_locustfile.py` - DB API load test scenarios
- `chat_api_locustfile.py` - Chat API load test scenarios
- `format_results.py` - Results formatter
- `configs/` - Pre-built RPS configurations
- `results/` - Generated test results (gitignored)
