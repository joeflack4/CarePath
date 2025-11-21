# Security, Secrets & PHI

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
