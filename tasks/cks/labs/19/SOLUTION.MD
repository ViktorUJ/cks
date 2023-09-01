add readOnlyRootFilesystem  and volumes to write
````
# kubectl edit nginx

# add line to container level

securityContext: # add
   readOnlyRootFilesystem: true # add
volumeMounts:
          - mountPath: /tmp
            name: temp-vol

# add to spec level

volumes:
- emptyDir: {}
  name: temp-vol


````
check  pod will be running
