Immutable Root FileSystem
Task weight: 2%

Update nginx deployment 
Modify Deployment nginx   in a way that no processes inside the container can modify the local filesystem, only /tmp directory should be
writeable.
