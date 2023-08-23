#### Answer:

We check the directory:

```sh

➜ cd /opt/course/6/binaries

➜ ls
kube-apiserver  kube-controller-manager  kube-proxy  kubelet
```

To generate the sha512 sum of a binary we do:

```sh
➜ sha512sum kube-apiserver 
f417c0555bc0167355589dd1afe23be9bf909bf98312b1025f12015d1b58a1c62c9908c0067a7764fa35efdac7016a9efa8711a44425dd6692906a7c283f032c  kube-apiserver
```

Looking good, next:

```
➜ sha512sum kube-controller-manager
60100cc725e91fe1a949e1b2d0474237844b5862556e25c2c655a33b0a8225855ec5ee22fa4927e6c46a60d43a7c4403a27268f96fbb726307d1608b44f38a60  kube-controller-manager
```

Okay, next:

```sh
➜ sha512sum kube-proxy
52f9d8ad045f8eee1d689619ef8ceef2d86d50c75a6a332653240d7ba5b2a114aca056d9e513984ade24358c9662714973c1960c62a5cb37dd375631c8a614c6  kube-proxy
```

Also good, and finally:

```sh
➜ sha512sum kubelet
7b720598e6a3483b45c537b57d759e3e82bc5c53b3274f681792f62e941019cde3d51a7f9b55158abf3810d506146bc0aa7cf97b36f27f341028a54431b335be  kubelet
```

Catch! Binary kubelet has a different hash!


But did we actually compare everything properly before? Let's have a closer look at kube-controller-manager again:

```sh
➜ sha512sum kube-controller-manager > compare

➜ vim compare 
```

Edit to only have the provided hash and the generated one in one line each:

```sh
# ./compare
60100cc725e91fe1a949e1b2d0474237844b5862556e25c2c655a33b0a8225855ec5ee22fa4927e6c46a60d43a7c4403a27268f96fbb726307d1608b44f38a60  
60100cc725e91fe1a949e1b2d0474237844b5862556e25c2c655a33boa8225855ec5ee22fa4927e6c46a60d43a7c4403a27268f96fbb726307d1608b44f38a60
```

Looks right at a first glance, but if we do:

```sh
➜ cat compare | uniq
60100cc725e91fe1a949e1b2d0474237844b5862556e25c2c655a33b0a8225855ec5ee22fa4927e6c46a60d43a7c4403a27268f96fbb726307d1608b44f38a60
60100cc725e91fe1a949e1b2d0474237844b5862556e25c2c655a33boa8225855ec5ee22fa4927e6c46a60d43a7c4403a27268f96fbb726307d1608b44f38a60
```

This shows they are different, by just one character actually.

To complete the task we do:

```sh
rm kubelet kube-controller-manager
```
 