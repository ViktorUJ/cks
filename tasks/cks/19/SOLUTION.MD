add readOnlyRootFilesystem  and volumes to write 
```` 
# kubectl edit nginx

# add line to container level 

securityContext: # add
   readOnlyRootFilesystem: true # add  
````
