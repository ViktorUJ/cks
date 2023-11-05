**This script is an example of a scenario that can be used as part of the interview screening process for hiring employees for SRE (Site Reliability Engineer) and DevOps positions. The expected execution time should not exceed 25 minutes. The technology stack includes AWS, Kubernetes, Helm, and Prometheus.**

# Allowed resources

## **Kubernetes Documentation:**

<https://kubernetes.io/docs/> and their subdomains

<https://kubernetes.io/blog/> and their subdomains

<https://docs.aws.amazon.com/> and their subdomains

<https://prometheus.io/>  and their subdomains

<https://github.com/prometheus-community/helm-charts/>  and their subdomains



## Questions

|        **1**        | **Using AWS CLI, retrieve all instances with the tag `env_name=hr-mock`.** |
| :-----------------: |:-----------------------------------------------------------------------|
|     Task weight     | 1%                                                                     |
|       Cluster       | -                                                                      |
| Acceptance criteria | - region: `eu-north-1` <br/>- output: `json`<br/>- save output to : `/var/work/tests/artifacts/1/ec2_1.json` |


|        **2**        | **Update deployment named `test-app` in ns = `dev-team`.**                    |
|:-------------------:|:--------------------------------------------------------------------------|
|     Task weight     | 1%                                                                        |
|       Cluster       | cluster2                                                                  |
| Acceptance criteria | - ns: `dev-team` <br/>- deployment name: `test-app`<br/>-  replicas: `4` <br/>-  image: `nginx:stable` |
