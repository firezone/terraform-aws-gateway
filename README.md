# Firezone Terraform modules and examples for AWS

This repo contains Terraform modules to use for Firezone deployments on AWS.

## Examples

- [Internet Gateway](./examples/internet-gateway): This example shows how to
  deploy one or more Firezone Gateways in a single AWS VPC that is configured
  with an Internet Gateway for egress. The Gateways will be associated to
  dedicated Elastic IP Resources to minimize IP churn. Read this if you're
  looking to deploy Firezone Gateways to AWS that need to communicate with the
  internet using static IPs.
