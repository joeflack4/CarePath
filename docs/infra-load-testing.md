# Load Testing Infrastructure

This document describes the load testing setup for CarePath AI's DB API and Chat API services using Locust.

## Overview

CarePath uses **Locust** (Python-based load testing framework) to test API performance under various load conditions. The load testing infrastructure allows you to:

- Test both DB API and Chat API independently
- Run tests at different RPS (requests per second) levels: 10, 100, and 1000
- Measure key metrics: error rate, P95 latency, throughput
- Generate detailed HTML and CSV reports
- Use web UI for interactive load testing

## Installation

Install Locust load testing dependencies:

```bash
make install-load-tests
```

This installs Locust into your current Python environment (virtual environment recommended).

## Prerequisites

Before running load tests, ensure:

1. **Services are running**: Start the API you want to test
   ```bash
   # For DB API tests
   make run-db-api

   # For Chat API tests
   make run-chat
   ```

2. **Data is loaded**: Load synthetic data for realistic testing
   ```bash
   make generate-synthetic
   make load-synthetic
   ```

3. **Virtual environment activated** (if using one):
   ```bash
   source env/python_venv/bin/activate
   ```

## Available Commands

### DB API Load Tests

The DB API is fast (typically <100ms response times) and can handle high RPS.

```bash
# Default test (10 users, 60 seconds)
make load-test-db-api

# Specific RPS targets
make load-test-db-api-10rps      # 5 users, 60s - light load
make load-test-db-api-100rps     # 50 users, 120s - medium load
make load-test-db-api-1000rps    # 500 users, 180s - heavy load
```

**Tested Endpoints:**
- `GET /health` - Health check
- `GET /health/db` - Database connectivity check
- `GET /patients` - List patients with pagination
- `GET /patients/{mrn}` - Get single patient
- `GET /patients/{mrn}/summary` - **Most important** - Used by Chat API
- `GET /encounters` - List encounters
- `GET /claims` - List claims
- `GET /documents` - List documents

### Chat API Load Tests

The Chat API uses **actual LLM inference** (6-7 minutes on CPU), so high RPS tests will cause timeouts.

```bash
# Default test (5 users, 300 seconds)
make load-test-chat

# Specific RPS targets
make load-test-chat-10rps        # 10 users, 300s - expect queue buildup
make load-test-chat-100rps       # 100 users, 300s - will cause timeouts
make load-test-chat-1000rps      # 500 users, 300s - stress test only
```

**Tested Endpoints:**
- `GET /health` - Health check
- `POST /triage` - **Main endpoint** - AI-powered patient query (6-7 min inference)

**Important Notes:**
- Chat API tests use actual LLM inference (not mock mode)
- 100 and 1000 RPS tests **will fail** - this is expected and demonstrates real-world limits
- Use these tests to understand infrastructure capacity, not to achieve target RPS

### Interactive Web UI

For manual testing with real-time charts:

```bash
# DB API web UI
make load-test-web-db-api

# Chat API web UI
make load-test-web-chat
```

Then open http://localhost:8089 in your browser to:
- Set custom user count and spawn rate
- Start/stop tests interactively
- View live charts and statistics
- Download reports

### View Results

Display formatted results from the most recent test:

```bash
make load-test-results
```

## Understanding Results

### Key Metrics

Each load test produces metrics for every endpoint and an aggregated summary:

1. **Total Requests** - Number of requests completed
2. **Total Failures** - Number of failed requests
3. **Error Rate** - Percentage of failed requests (failures / total × 100)
4. **Requests/sec (RPS)** - Actual throughput achieved
5. **Response Times**:
   - **Average** - Mean response time
   - **P50 (median)** - 50% of requests completed faster than this
   - **P95** - 95% of requests completed faster than this ⭐ **Key metric**
   - **P99** - 99% of requests completed faster than this

### P95 Latency

**P95 latency** is the primary performance indicator:
- **Definition**: 95% of requests completed within this time
- **Target for DB API**: < 100ms
- **Why P95?**: Excludes outliers but captures "typical worst case" user experience

**Example interpretation:**
- P95 = 85ms → PASS ✅ (95% of users wait < 85ms)
- P95 = 250ms → FAIL ❌ (5% of users wait > 250ms)

### Sample Output

```
======================================================================
LOAD TEST RESULTS
======================================================================
Results file: db_api_10rps_20250125_143022_stats.csv
Generated: 2025-01-25 14:31:22

----------------------------------------------------------------------
SUMMARY
----------------------------------------------------------------------
Total Requests:    1,234
Total Failures:    12
Error Rate:        0.97%

Requests/sec:      10.28

Response Times:
  Average:         45ms
  P50 (median):    42ms
  P95:             78ms
  P99:             95ms

  P95 Target (100ms): PASS (78ms)

----------------------------------------------------------------------
BY ENDPOINT
----------------------------------------------------------------------
Endpoint                              Reqs   Fail        Avg        P95
----------------------------------------------------------------------
/patients/{mrn}/summary                456      2       52ms       89ms
/patients                              185      1       38ms       65ms
/patients/{mrn}                        235      3       43ms       72ms
/encounters                             98      2       41ms       68ms
/claims                                 87      1       39ms       64ms
/documents                              92      2       40ms       66ms
/health                                 45      0       12ms       18ms
/health/db                              36      1       15ms       22ms

======================================================================
```

## Configuration Files

Pre-built configurations are in `infra/load_tests/configs/`:

| File | Users | Spawn Rate | Duration | Target RPS |
|------|-------|------------|----------|------------|
| `db_api_10rps.json` | 5 | 2/sec | 60s | 10 |
| `db_api_100rps.json` | 50 | 10/sec | 120s | 100 |
| `db_api_1000rps.json` | 500 | 50/sec | 180s | 1000 |
| `chat_api_10rps.json` | 10 | 2/sec | 300s | 10 |
| `chat_api_100rps.json` | 100 | 10/sec | 300s | 100* |
| `chat_api_1000rps.json` | 500 | 50/sec | 300s | 1000* |

*Target RPS for Chat API is **not achievable** with actual LLM inference (6-7 min per request).

## Advanced Usage

### Custom Parameters

Run Locust manually with custom settings:

```bash
cd infra/load_tests

# Custom DB API test
locust -f db_api_locustfile.py \
    --host=http://localhost:8001 \
    --users=25 \
    --spawn-rate=5 \
    --run-time=90s \
    --headless \
    --html=results/custom_test.html \
    --csv=results/custom_test

# Custom Chat API test
locust -f chat_api_locustfile.py \
    --host=http://localhost:8002 \
    --users=3 \
    --spawn-rate=1 \
    --run-time=600s \
    --headless
```

### Testing Cloud Deployment

To test deployed APIs on AWS EKS:

```bash
# Get API URLs
make k8s-get-urls

# Modify Makefile.load_tests or run manually
locust -f infra/load_tests/db_api_locustfile.py \
    --host=http://<db-api-loadbalancer-url> \
    --users=100 \
    --spawn-rate=10 \
    --run-time=180s \
    --headless
```

### Distributed Load Testing

For very high load (1000+ users), use Locust in distributed mode:

```bash
# Start master
locust -f db_api_locustfile.py --master --host=http://localhost:8001

# Start workers (in separate terminals)
locust -f db_api_locustfile.py --worker --master-host=localhost
locust -f db_api_locustfile.py --worker --master-host=localhost
locust -f db_api_locustfile.py --worker --master-host=localhost
```

## Results Files

All results are saved to `infra/load_tests/results/` (gitignored):

- `<test>_<timestamp>_stats.csv` - Detailed statistics per endpoint
- `<test>_<timestamp>_failures.csv` - All failures and errors
- `<test>_<timestamp>.html` - Interactive HTML report with charts
- `<test>_<timestamp>_stats_history.csv` - Time-series data
- `<test>_<timestamp>_exceptions.csv` - Python exceptions (if any)

**View HTML reports:**
```bash
open infra/load_tests/results/db_api_10rps_20250125_143022.html
```

## Troubleshooting

### DB API Issues

**Problem**: High error rate or P95 > 100ms

**Possible causes:**
- MongoDB not running or slow
  ```bash
  make mongo-local-start-macos
  ```
- Data not loaded
  ```bash
  make load-synthetic
  ```
- Too many concurrent connections - reduce users
- MongoDB needs indexing (check patient lookups by MRN)

**Problem**: Connection refused

**Solution**: Ensure DB API is running
```bash
make run-db-api
```

### Chat API Issues

**Problem**: All requests timing out

**Possible causes:**
- LLM inference is too slow (6-7 min is normal)
- Too many concurrent users - reduce to 1-5 users
- LLM not loaded properly - check Chat API logs

**Expected behavior:**
- First request takes 6-7 minutes (LLM inference)
- Subsequent requests also take 6-7 minutes (each query is independent)
- High RPS tests will fail - this is expected

**Solution**: Use mock mode for testing infrastructure without LLM overhead
```bash
# Edit .env
LLM_MODE=mock

# Restart Chat API
make run-chat
```

**Problem**: Out of memory

**Solution**: Reduce number of concurrent users or use mock mode
```bash
# For Chat API, keep users low (1-10) with actual LLM
make load-test-chat-10rps
```

### General Issues

**Problem**: `ModuleNotFoundError: No module named 'locust'`

**Solution**: Install dependencies
```bash
make install-load-tests
```

**Problem**: Results not showing

**Solution**: Check results directory exists and has files
```bash
ls -lh infra/load_tests/results/
```

## Best Practices

1. **Start small**: Begin with low RPS tests (10 RPS) before scaling up
2. **Establish baseline**: Run tests multiple times to get consistent baseline metrics
3. **Isolate variables**: Test one API at a time
4. **Monitor resources**: Watch CPU, memory, disk I/O during tests
5. **Clean data**: Use consistent synthetic data between test runs
6. **Document results**: Save HTML reports for comparison over time
7. **Test incrementally**: 10 RPS → 100 RPS → 1000 RPS to find breaking point
8. **Chat API limits**: Accept that actual LLM inference creates natural throughput limits

## Architecture

```
infra/load_tests/
├── requirements.txt              # Locust dependency
├── db_api_locustfile.py         # DB API test scenarios
├── chat_api_locustfile.py       # Chat API test scenarios
├── format_results.py            # Results formatter script
├── configs/                     # Pre-built configurations
│   ├── db_api_10rps.json
│   ├── db_api_100rps.json
│   ├── db_api_1000rps.json
│   ├── chat_api_10rps.json
│   ├── chat_api_100rps.json
│   └── chat_api_1000rps.json
└── results/                     # Generated results (gitignored)
    ├── *.csv
    └── *.html
```

## Example Workflow

Complete workflow for load testing:

```bash
# 1. Setup
source env/python_venv/bin/activate
make install-load-tests

# 2. Start services and load data
make run-db-api  # In terminal 1
make run-chat    # In terminal 2
make load-synthetic

# 3. Run DB API tests
make load-test-db-api-10rps
make load-test-db-api-100rps
make load-test-db-api-1000rps

# 4. Run Chat API tests (expect long durations)
make load-test-chat-10rps  # This will take 30+ minutes

# 5. View results
make load-test-results
open infra/load_tests/results/<latest>.html

# 6. Compare metrics
# - P95 latency < 100ms for DB API?
# - Error rate < 1%?
# - Achieved RPS meets target?
```

## See Also

- [Locust Documentation](https://docs.locust.io/)
- `infra/load_tests/db_api_locustfile.py` - DB API test implementation
- `infra/load_tests/chat_api_locustfile.py` - Chat API test implementation
- `notes/load-testing.md` - Implementation guide
- `Makefile.load_tests` - Load testing Makefile targets
