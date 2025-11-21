# Observability & Monitoring

## OpenTelemetry

- [ ] Replace custom tracing with OpenTelemetry:
  - [ ] Install OTEL SDK
  - [ ] Instrument FastAPI apps and HTTP clients
  - [ ] Configure exporter (e.g. CloudWatch, OTEL collector, Grafana Cloud)

## Metrics

- [ ] Add metrics for:
  - [ ] Request counts, latency, and error rates per endpoint
  - [ ] LLM latency and errors
  - [ ] Pinecone query latency
  - [ ] DB query latency

- [ ] Create dashboards showing:
  - [ ] p50/p95/p99 latency for `/triage`
  - [ ] HPA scaling behavior over time

## Docs
- [ ] `docs/observability.md`: Document the metrics that are tracked, and how to access them. Link to the document in
`README.md`.
