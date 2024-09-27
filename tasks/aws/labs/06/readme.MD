# User was fired . Need to  revoke all keys used by the iam role.
 User login via iam identity center

https://aws.amazon.com/ru/blogs/security/how-to-revoke-federated-users-active-aws-sessions/


``` 
# check iam roles

#!/bin/bash

# Получаем текущее время в формате UTC для TokenIssueTime
current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Список ролей без "AWS" и "OrganizationAccountAccessRole"
roles=$(aws iam list-roles --query 'Roles[?contains(RoleName, `AWS`) == `false` && RoleName != `OrganizationAccountAccessRole`].RoleName' --output text)

cat > deny_policy.json <<EOL
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Deny",
            "Action": "*",
            "Resource": "*",
            "Condition": {
                "DateLessThan": {
                    "aws:TokenIssueTime": "$current_time"
                }
            }
        }
    ]
}
EOL
echo "*** policy "
cat deny_policy.json

# Перебираем каждую роль
for role in $roles; do
    echo "Adding policy to role: $role"
    aws iam put-role-policy --role-name "$role" --policy-name "DenyOldSessions" --policy-document file://deny_policy.json

    echo "Policy applied to role: $role"
done


```