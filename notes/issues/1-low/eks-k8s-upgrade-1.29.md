# Issue: EKS Kubernetes 1.29 End of Extended Support

**Priority:** Low
**Deadline:** March 23, 2026
**Status:** Open

## Summary

AWS EKS extended support for Kubernetes 1.29 ends on March 23, 2026. Our demo cluster in us-east-2 is currently running 1.29.

## Impact

After March 23, 2026:
- No security patches for K8s control plane
- No EKS optimized AMIs or EKS Add-ons support for 1.29
- Cannot create new 1.29 clusters
- AWS will auto-upgrade clusters to 1.30

## Recommendation

AWS recommends:
- **Minimum:** Upgrade to 1.30
- **Preferred:** Upgrade to 1.32+ (avoids extended support)
- **Best:** Upgrade to 1.33 (latest, minimizes future upgrades)

## Required Changes

1. Update `infra/terraform/envs/demo/variables.tf`:
   ```hcl
   variable "cluster_version" {
     description = "Kubernetes version"
     type        = string
     default     = "1.33"  # or desired version
   }
   ```

2. Run `terraform apply` in `infra/terraform/envs/demo/`

## Pre-upgrade Checklist

- [ ] Review K8s deprecation notes for versions 1.30-1.33
- [ ] Check if any K8s APIs we use are deprecated
- [ ] Test upgrade in a non-production environment first (if applicable)
- [ ] Backup any critical data
- [ ] Plan upgrade during low-traffic window

## References

- [EKS Cluster Upgrade Docs](https://docs.aws.amazon.com/eks/latest/userguide/update-cluster.html)
- [EKS Kubernetes Version Support](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html)
- AWS Health Event: `AWS_EKS_PLANNED_LIFECYCLE_EVENT`
