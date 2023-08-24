# Welcome to the Kubernetes Learning Platform!

The **Kubernetes Learning Platform** is an open-source hub designed to help IT engineers effectively prepare for the **CKA (Certified Kubernetes Administrator)**, **CKS (Certified Kubernetes Security Specialist)**, and **CKAD (Certified Kubernetes Application Developer)** exams. Additionally, this platform offers invaluable hands-on experience with **AWS EKS (Elastic Kubernetes Service)**, equipping users with practical insights for real-world applications. Whether you're aiming to validate your skills, boost your career prospects in Kubernetes administration, security, application development, or delve into AWS EKS, this platform provides hands-on labs, practice tests, and expert guidance to ensure certification success.

- Prepare for the **CKA**: [Certified Kubernetes Administrator Exam](https://training.linuxfoundation.org/certification/certified-kubernetes-administrator-cka/)
- Enhance your skills for the **CKS**: [Certified Kubernetes Security Specialist Exam](https://training.linuxfoundation.org/certification/certified-kubernetes-security-specialist/)
- Excel in the **CKAD**: [Certified Kubernetes Application Developer Exam](https://training.linuxfoundation.org/certification/certified-kubernetes-application-developer-ckad/)

Master Kubernetes concepts, gain practical experience, and excel in the CKA, CKS, and CKAD exams with the **Kubernetes Learning Platform**.


## Repository Structure

The repository is organized into the following sections:

- **/[Makefile](Makefile)** - File containing scenarios for launching hands-on labs and mock exams.
- **/[tasks](tasks)** - Contains lab scenarios and mock exam scripts.
  - **/[cka](tasks%2Fcka)** - Everything related to CKA.
    - **/[labs](tasks%2Fcka%2Flabs)**  - Contains hands-on labs for the CKA exam.
    - **/[mock](tasks%2Fcka%2Fmock)**  - Contains mock scripts for the CKA exam.
  - **/[cks](tasks%2Fcks)** - Everything related to CKS.
    - **/[labs](tasks%2Fcks%2Flabs)**  - Contains hands-on labs for the CKS exam.
    - **/[mock](tasks%2Fcks%2Fmock)**  - Contains mock scripts for the CKS exam.
- **/[terraform](terraform)** - Contains modules and Terraform environments.
  - **/[environments](terraform%2Fenvironments)** - Terraform environments.
  - **/[modules](terraform%2Fmodules)** - Terraform modules.
 
## Requirements
- [terrafrom](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)  >= v1.1.7
- [terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) >= v0.36.1
- [aws IAM user](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html)  + [Access key](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html)  (or [IAM role](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) ) with  [Admin privilege  form VPC, EC2, IAM, EKS](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html) 
- [aws profile](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html) 

## Configuration and Setup
- Basic Settings and Parameters:
  - Overview of available configuration options.
  - Examples of configuration files (if applicable).
- Networking Configuration:
  - Setting up network parameters (IP addresses, ports, etc.).
- Integration with Other Systems:
  - How to integrate the product/system with other tools.
- Security:
  - Security best practices for the product/system.
  - Authentication and authorization setup.

## Usage
- Key Features and Capabilities:
  - Overview of features provided by the product/system.
- Usage Examples:
  - Detailed examples of performing tasks using the product/system.
- Command and Query Parameters:
  - List of available commands with descriptions of their parameters.

## Troubleshooting and Issues
- Problem Identification and Resolution:
  - Common issues users might encounter.
  - Detailed steps for diagnosing and resolving problems.
- Logging and Logs:
  - How to analyze log files to identify issues.

## Maintenance and Updates
- Backup and Restoration:
  - Recommendations for data backup.
- Regular Maintenance:
  - Tasks to maintain performance and stability of the product/system.
- Updating the Product/System:
  - Procedure for updating to new versions.

## User Guide (if applicable)
- Comprehensive guide on using the product/system for end users.

## Reference Materials (if applicable)
- List of available commands, APIs, parameters, etc.

## FAQ (Frequently Asked Questions)
- List of popular questions and their answers.

## Contacts

If you encounter any issues or have questions about the project, you can reach out to:

- [![Telegram](https://badgen.net/badge/icon/telegram?icon=telegram&label)](https://t.me/viktor_uj)
- [![LinkedI](https://badgen.net/badge/icon/linkedin?icon=linkedin&label)](https://www.linkedin.com/in/viktar-mikalayeu-mns)
- [![email](https://badgen.net/badge/icon/email?icon=email&label)](mailto:viktoruj@gmail.com)

[![email](https://badgen.net/badge/icon/email?icon=email&label)](mailto:viktoruj@gmail.com) [![Telegram](https://badgen.net/badge/icon/telegram?icon=telegram&label)](https://t.me/viktor_uj) [![LinkedI](https://badgen.net/badge/icon/linkedin?icon=linkedin&label)](https://www.linkedin.com/in/viktar-mikalayeu-mns)

## [Useful links](docs%2Flinks.MD)

## [Tips And Tricks](docs%2Ftips_tricks.MD)

## License and Usage Agreement
- [Apache License 2.0](LICENSE)
