# Restrict ssh access from 0.0.0.0/0
It is necessary to find all SGs with open ssh port in Frankfurt region. remove this rule from securiti group. if this rule is added it should be removed automatically. and send email to xxxx@gmail.com.

# Solution
For detection of widely opened 22 port and further automatic remediation we can use AWS Config service

For this :
1. In AWS Config create a rule for port detection. Predifined 'restricted-ssh' rule can be used
2. Create an IAM role which will be used for removing founded inputs with necessary permissions
3. Set up remediation for the rule:
 - select SSM document which will be used for remediation or create it by yourself
 in our case the doc.name will be "AWS-DisableIncomingSSHOnPort22". In the input parameters specify the SGId and The role which will be assumed while document execution

For getting email about any chages in Config or for a special events from the specific rule we need:
- Create SNS topic
- Add the SNS topic to the Config settings
- Subscribe your email to the  SNS topc. If you want to get evens only from a specific rule , you should you Subscription filter policy