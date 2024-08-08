# Read docker [build best practies](https://docs.docker.com/build/building/best-practices/)

# Fix dockerfile
```
vim  /var/work/14/Dockerfile
```
*It should looks like this one:*
```
FROM ubuntu:20.04
RUN apt-get update && apt-get -y install curl
RUN groupadd myuser
RUN useradd -g myuser myuser
USER myuser
CMD ["sh", "-c", "while true ; do  id ;  sleep 1  ;done"]
```

# Build an image
```
podman build . -t cks:14
```

# Run a container
```
podman run -d --rm --name cks-14 cks:14
```

# Check the result
```
podman logs cks-14
sleep 2
```
*Result must be like this one:*
```
uid=1000(myuser) gid=1000(myuser) groups=1000(myuser)
```

# Remove the image
```
podman rmi cks:14 --force
```
*The container will be stopped and removed too*
