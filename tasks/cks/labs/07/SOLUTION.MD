### https://www.youtube.com/watch?v=ocSgbSCX34M
### https://habr.com/ru/company/vk/blog/669788/
### https://habr.com/ru/company/southbridge/blog/688268/
### https://habr.com/ru/company/southbridge/blog/688268/

### rego   https://www.openpolicyagent.org/docs/latest/policy-language/

We look at existing OPA constraints, these are implemeted using CRDs by Gatekeeper:

```sh
➜ k get crd
NAME                                                 CREATED AT
blacklistimages.constraints.gatekeeper.sh            2020-09-14T19:29:31Z
configs.config.gatekeeper.sh                         2020-09-14T19:29:04Z
constraintpodstatuses.status.gatekeeper.sh           2020-09-14T19:29:05Z
constrainttemplatepodstatuses.status.gatekeeper.sh   2020-09-14T19:29:05Z
constrainttemplates.templates.gatekeeper.sh          2020-09-14T19:29:05Z
requiredlabels.constraints.gatekeeper.sh             2020-09-14T19:29:31Z
```

So we can do:

```sh
➜ k get constraint
NAME                                                           AGE
blacklistimages.constraints.gatekeeper.sh/pod-trusted-images   10m

NAME                                                                  AGE
requiredlabels.constraints.gatekeeper.sh/namespace-mandatory-labels   10m
```

and then look at the one that is probably about blacklisting images:

```sh
k edit blacklistimages pod-trusted-images
```
```yaml
# kubectl edit blacklistimages pod-trusted-images
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: BlacklistImages
metadata:
...
spec:
  match:
    kinds:
    - apiGroups:
      - ""
      kinds:
      - Pod
````      
It looks like this constraint simply applies the template to all Pods, no arguments passed. So we edit the template:

```sh
k edit constrainttemplates blacklistimages
```

```yaml
# kubectl edit constrainttemplates blacklistimages
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
...
spec:
  crd:
    spec:
      names:
        kind: BlacklistImages
  targets:
  - rego: |
      package k8strustedimages

      images {
        image := input.review.object.spec.containers[_].image
        not startswith(image, "docker-fake.io/")
        not startswith(image, "google-gcr-fake.com/")
        not startswith(image, "very-bad-registry.com/") # ADD THIS LINE
      }

      violation[{"msg": msg}] {
        not images
        msg := "not trusted image!"
      }
    target: admission.k8s.gatekeeper.sh
```

We simply have to add another line. After editing we try to create a Pod of the bad image:

```sh
➜ k run opa-test --image=very-bad-registry.com/image
Error from server ([denied by pod-trusted-images] not trusted image!): admission webhook "validation.gatekeeper.sh" denied the request: [denied by pod-trusted-images] not trusted image!
```

Nice! After some time we can also see that Pods of the existing Deployment "untrusted" will be listed as violators:

```sh
➜ k describe blacklistimages pod-trusted-images
...
  Total Violations:  2
  Violations:
    Enforcement Action:  deny
    Kind:                Namespace
    Message:             you must provide labels: {"security-level"}
    Name:                sidecar-injector
    Enforcement Action:  deny
    Kind:                Pod
    Message:             not trusted image!
    Name:                untrusted-68c4944d48-tfsnb
    Namespace:           default
Events:                  <none>
```

Great, OPA fights bad registries !

 
