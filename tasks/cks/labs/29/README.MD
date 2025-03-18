# Perform a Docker security configutaion

Allowed resources:

- Kubernetes docs: https://kubernetes.io/docs/home/

- Falco docs: https://falco.org/docs/

|       **29**        | **Perform Docker security configuration**                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| :-----------------: | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Acceptance criteria | In the host docker as a container engine. We need to peform the following tasks to enhance Docker security.:<br/>&nbsp;&nbsp;- remove access to docker daemon for user `developer`.<br/>&nbsp;&nbsp;- Docker is not exposed to TCP socket.<br/>&nbsp;&nbsp;- Docker socket `/var/run/docker.sock` is confgiured to be used for users that are in `docker` group. Change docker socket permissions to make it available only for `root` user and `root` group.<br/> Acceptance creteria: <br/>&nbsp;&nbsp;- `developer` user is not able to use docker anymore.<br/>&nbsp;&nbsp;- docker is not being exposed using TCP.<br/>&nbsp;&nbsp;- docker.sock has proper permissions. |
