# add automatic tracking of asg changes , deleting instances . sending alerts and disabling keys

## Solution
For tracking/getting notification need to:
- create SNS topic with email subsription.
- configure ASG to send notifications to the SNS topic (go ASG -> Acitity -> Create notification)
 - configure EventBridge rule to get specific events and send them to SNS
