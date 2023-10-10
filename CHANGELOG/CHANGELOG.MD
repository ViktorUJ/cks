# Changelog
## 0.4.1* (15.10.2023)
### Features
* + move stop ec2 from **spot request** to  **spot fleet** .  get spot ec2 more stability
* + update [make commands](..%2FREADME.MD#command)
* + update terraform code  to use **terraform** version **v1.5.6** 
* +  update terraform aws provider to **v5.17.0**
* + add **ubuntu_version** to [k8s_self_management](..%2Fterraform%2Fmodules%2Fk8s_self_managment) module . now it is default way to get **ami_id**
* +  utilizes k8s version on cka-mock and cks mock to 1.28
* + The [cks mock exam 01](..%2Ftasks%2Fcks%2Fmock%2F01)  utilizes version  Graviton instances t4g.medium.
* + The cks labs utilizes version 1.28 and Graviton instances t4g.medium.
* +  actualize  [cks labs](..%2Ftasks%2Fcks%2Flabs)  , add [list](..%2Ftasks%2Fcks%2Flabs%2FREADME.MD) to them.
* + add  cks mock [solutions](..%2Ftasks%2Fcks%2Fmock%2F01%2Fworker%2Ffiles%2Fsolutions)
* add video for cks mock solutions

## 0.3.1 (15.09.2023)
### Features
* Added the ability to run the [k8s_self_management](..%2Fterraform%2Fmodules%2Fk8s_self_managment) module on [EC2 Graviton](https://docs.aws.amazon.com/whitepapers/latest/aws-graviton-performance-testing/what-is-aws-graviton.html).
* Introduced support for the new Kubernetes version [1.28](https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG/CHANGELOG-1.28.md).
* The [cka mock exam 01](..%2Ftasks%2Fcka%2Fmock%2F01)  utilizes version 1.27 and Graviton instances t4g.medium.
* Added a [video for solutions ](https://youtu.be/IZsqAPpbBxM)  to the [cka mock exam 01](..%2Ftasks%2Fcka%2Fmock%2F01).
