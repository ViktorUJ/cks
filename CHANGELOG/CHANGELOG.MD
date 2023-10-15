# Changelog
## 0.4.1 (15.10.2023)
### Features
* spot ec2 is moved  from **spot request** to  **spot fleet**, which gives spot ec2 more stability
* [make commands](..%2FREADME.MD#command) is update 
* terraform code is update  to use **terraform** version **v1.5.6** 
* terraform aws provider is updated  to **v5.17.0**
* **ubuntu_version** is added  to [k8s_self_management](..%2Fterraform%2Fmodules%2Fk8s_self_managment) module, which is the way to get **ami_id** by default 
* k8s version **1.28**  is used in cka-mock and cks-mock exams
* The [cks mock exam 01](..%2Ftasks%2Fcks%2Fmock%2F01)  uses version  **Graviton** instances **t4g.medium**.
* The cks labs uses version **1.28** and Graviton instances **t4g.medium**.
* actualize  [cks labs](..%2Ftasks%2Fcks%2Flabs)  , add [list](..%2Ftasks%2Fcks%2Flabs%2FREADME.MD) to them.
* add  cks mock [solutions](..%2Ftasks%2Fcks%2Fmock%2F01%2Fworker%2Ffiles%2Fsolutions)
* add [video](https://youtu.be/_GbsBOMaJ9Q) for run mock exam
* add [video](https://youtu.be/I8CPwcGbrG8) for cks mock solutions

## 0.3.1 (15.09.2023)
### Features
* Added the ability to run the [k8s_self_management](..%2Fterraform%2Fmodules%2Fk8s_self_managment) module on [EC2 Graviton](https://docs.aws.amazon.com/whitepapers/latest/aws-graviton-performance-testing/what-is-aws-graviton.html).
* Introduced support for the new Kubernetes version [1.28](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.28.md).
* The [cka mock exam 01](..%2Ftasks%2Fcka%2Fmock%2F01)  utilizes version 1.27 and Graviton instances t4g.medium.
* Added a [video for solutions ](https://youtu.be/IZsqAPpbBxM)  to the [cka mock exam 01](..%2Ftasks%2Fcka%2Fmock%2F01).
