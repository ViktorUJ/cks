# generate-iam-policy

Generates an IAM policy JSON for AWS IAM Identity Center that allows managing users and their group membership while restricting access to specific groups only.

## What the policy allows

- Create, update, delete users in Identity Store
- Add/remove users to/from **specified groups only**
- View groups, memberships, directory info
- View and manage MFA devices for users
- Read-only access to SSO and Organizations

## What the policy denies

- Creating, deleting, or modifying groups
- Creating or modifying permission sets
- Assigning permission sets to accounts
- Adding users to groups not in the allowed list (via `sso-directory` bypass)

## Environment variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AWS_PROFILE` | yes | AWS CLI profile name |
| `AWS_REGION` | yes | AWS region where Identity Center is configured |
| `ALLOWED_GROUPS` | yes | Semicolon-separated group DisplayNames |

## Build

```bash
go build -o generate-iam-policy .
```

## Usage

```bash
AWS_PROFILE=default AWS_REGION=us-east-1 ALLOWED_GROUPS="Developers;DevOps;Team Leads" ./generate-iam-policy
```

Output: `iam-admin-policy.json` in the current directory.

## Apply the policy

Use the generated JSON as an inline policy for an IAM Identity Center permission set:

```bash
aws sso-admin put-inline-policy-to-permission-set \
  --instance-arn "arn:aws:sso:::instance/ssoins-XXXXXXXX" \
  --permission-set-arn "arn:aws:sso:::permissionSet/ssoins-XXXXXXXX/ps-XXXXXXXX" \
  --inline-policy file://iam-admin-policy.json \
  --profile default --region us-east-1
```
