
## Question 7 | Open Policy Agent

#### Task weight: 6%



The Open Policy Agent and Gatekeeper have been installed to, 
among other things, enforce blacklisting of certain image registries.
Alter the existing constraint and/or template to also blacklist images from very-bad-registry.com.

Test it by creating a single Pod using image very-bad-registry.com/image in Namespace default, it shouldn't work.

You can also verify your changes by looking at the existing Deployment untrusted in Namespace default,
it uses an image from the new untrusted source. The OPA contraint should throw violation messages for this one.