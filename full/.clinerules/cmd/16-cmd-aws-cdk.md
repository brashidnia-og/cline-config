---
paths:
  - "**/cdk.json"
  - "**/cdk.context.json"
  - "**/cdk.out/**"
  - "**/*-stack.ts"
  - "**/*-stack.js"
  - "**/*-stack.tsx"
  - "**/bin/*.ts"
  - "**/cloudformation/**"
  - "**/template.yaml"
  - "**/template.yml"
  - "**/samconfig.toml"
  - "**/.aws/**"
---

# AWS CLI and CDK command policy

Default to **read / synth / diff only**. Never deploy or mutate cloud state without explicit user authorization.

Before interpreting results, confirm account/region via `aws sts get-caller-identity` and env (`AWS_PROFILE`, `AWS_REGION`). Treat CloudWatch/S3 output as potentially sensitive; minimize scope. Inspect `cdk.json` and stacks before synth; do not invent AWS resources without repo evidence.

## Generally safe inspection
```bash
aws --version
aws sts get-caller-identity
aws configure list
aws ec2 describe-instances
aws ec2 describe-security-groups
aws s3 ls
aws s3 ls s3://bucket/...
aws s3api list-buckets
aws cloudformation describe-stacks
aws cloudformation describe-stack-events --stack-name <name>
aws cloudformation get-template --stack-name <name>
aws logs describe-log-groups
aws logs filter-log-events
aws iam get-user
aws iam list-roles
cdk --version
cdk doctor
cdk list
cdk synth
cdk diff
npx cdk list
npx cdk synth
npx cdk diff
```

Prefer specific filters and stack names over account-wide dumps. Do not print long-term keys, session tokens, or `.aws/credentials` contents.

## Not auto-approved
Do not automatically run:
- `cdk deploy`, `cdk destroy`, `cdk bootstrap`
- `aws cloudformation deploy` / `create-*` / `update-*` / `delete-*`
- Mutating `aws s3 cp|mv|rm` or destructive `aws s3 sync`
- Any `create-*`, `delete-*`, `put-*`, `update-*`, `modify-*`, `terminate-*`, `run-instances` unless explicitly requested
- Writes to AWS config/credentials files unless the user asks

Never deploy or alter cloud resources merely to validate a code change.
