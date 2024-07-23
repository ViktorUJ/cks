# Find OPA Gatekeeper custom resourses
```
k get crd
k get constraint
k get constrainttemplates
```

# Add untrusted repo into the constrainttemplates
```
k edit constrainttemplates k8strustedimages
```
.......
  - rego: |
      package k8strustedimages

      violation[{"msg": msg}] {
       not images
       msg := "not trusted image!"
      }

      images {
        image := input.review.object.spec.containers[_].image
        not startswith(image, "docker-fake.io/")
        not startswith(image, "google-gcr-fake.com/")
        <span style="color:red">not startswith(image, "very-bad-registry.com/") #add this line</span>
      }

...........


# Check if the admission webhook policy works right
```
k run test --image very-bad-registry.com/test
```
*Result should be like this:*
```
Error from server (Forbidden): admission webhook "validation.gatekeeper.sh" denied the request: [k8strustedimages] not trusted image!
```
