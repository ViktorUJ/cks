# Changelog

## 0.5.1 (15.11.2023)
### Features
* ckad mock exam was added
* [HR scenario](..%2Ftasks%2Fhr%2Fmock%2F01) was added
* [ping_pong](..%2Fdocker%2Fping_pong) server was added

## 0.4.1 (15.10.2023)
### Features
* Spot ec2 is moved  from **spot request** to  **spot fleet**, which gives spot ec2 more stability
* [Make commands](..%2FREADME.MD#command) is updated 
* Terraform code is updated  to use **terraform** version **v1.5.6** 
* Terraform aws provider is updated  to **v5.17.0**
* **Ubuntu_version** is added  to [k8s_self_management](..%2Fterraform%2Fmodules%2Fk8s_self_managment) module, which is the way to get **ami_id** by default 
* k8s version **1.28**  is used in cka-mock and cks-mock exams
* The [cks mock exam 01](..%2Ftasks%2Fcks%2Fmock%2F01)  uses version  **Graviton** instances **t4g.medium**
* The cks labs use version **1.28** and Graviton instances **t4g.medium**
* [Cks labs](..%2Ftasks%2Fcks%2Flabs) are actualized, [list](..%2Ftasks%2Fcks%2Flabs%2FREADME.MD) is added to them
* Cks mock [solutions](..%2Ftasks%2Fcks%2Fmock%2F01%2Fworker%2Ffiles%2Fsolutions)  are added  
* [Video](https://youtu.be/_GbsBOMaJ9Q) for run mock exam is added 
* [Video](https://youtu.be/I8CPwcGbrG8) for cks mock solutions is added 

## 0.3.1 (15.09.2023)
### Features
* The ability to run the [k8s_self_management](..%2Fterraform%2Fmodules%2Fk8s_self_managment) module on [EC2 Graviton](https://docs.aws.amazon.com/whitepapers/latest/aws-graviton-performance-testing/what-is-aws-graviton.html) is added
* Support for the new Kubernetes version [1.28](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.28.md) is introduced 
* Version 1.27 and Graviton instance t4g.medium  is used in [cka mock exam 01](..%2Ftasks%2Fcka%2Fmock%2F01)
* [Video for solutions ](https://youtu.be/IZsqAPpbBxM)  to the [cka mock exam 01](..%2Ftasks%2Fcka%2Fmock%2F01) is added
