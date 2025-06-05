# k8s learning log

## spinning up a toy environment

Installed [kind](https://kind.sigs.k8s.io/) and spun up a new cluster w/

```
[pbj@meadow]~/code/wut-is-k8s $ kind create cluster -n mordor
```

`kind` says it works by using docker... I wonder what I can see:

```
[pbj@meadow]~/code/wut-is-k8s $ docker ps
CONTAINER ID   IMAGE                            COMMAND                  CREATED         STATUS         PORTS                             NAMES
6848de8fd8f6   kindest/node:v1.32.2             "/usr/local/bin/entr…"   4 minutes ago   Up 4 minutes   127.0.0.1:55789->6443/tcp         mordor-control-plane
```

Sweet.

Now `kind` is prompting me to switch contexts to `kind-mordor`...

## wut is a context???

Google takes me to [these k8s
docs](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/)

I think I found the relevant section:

> Each context is a triple (cluster, user, namespace). For example, the dev-frontend context says,
> "Use the credentials of the developer user to access the frontend namespace of the development
> cluster".

So I imagine `kind` has setup the following for me:
- A cluster
- A user to connect to that cluster
- A namespace within that cluster
- A context pointing at the above three things `kind-mordor`

Goog points me to `kubectl config` as the thing that knows about those things:

```
[pbj@meadow]~/code/wut-is-k8s $ kubectl config get-users | grep mordor
kind-mordor
[pbj@meadow]~/code/wut-is-k8s $ kubectl config get-clusters | grep mordor
kind-mordor
[pbj@meadow]~/code/wut-is-k8s $ kubectl config get-contexts kind-mordor
CURRENT   NAME          CLUSTER       AUTHINFO      NAMESPACE
*         kind-mordor   kind-mordor   kind-mordor
```

Hmmm no namespace is set... I'd assume that means that it uses the default namespace.

I wonder if I can confirm that... ran `kubectl config view` and found the following section:

```
- context:
    cluster: kind-mordor
    user: kind-mordor
  name: kind-mordor
```

So no namespace is even set!!

Found the [config resource
definition](https://kubernetes.io/docs/reference/config-api/kubeconfig.v1/#Context), sure enough
namespace is optional. Doesn't say it explicitly, but I've gotta assume 'default' is used as the
default (lol).

### how does `kubectl` know about `mordor`?

Bit of a side quest here, but I was curious how kubectl knows about and auths to a cluster.

Mostly examined the output of `kubectl config view` to try to piece some stuff together.

#### Cluster definition

```
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://127.0.0.1:55789
  name: kind-mordor
```

[kubernetes resource docs](https://kubernetes.io/docs/reference/config-api/kubeconfig.v1/#Cluster)

> Server is the address of the kubernetes cluster (https://hostname:port).

> CertificateAuthorityData contains PEM-encoded certificate authority certificates. Overrides
> CertificateAuthority

So this seems to configure a cluster running on the control plane at `https://127.0.0.1:55789`
(matched my docker port forwarding!) and using the given certificate data as the certificate
authority to authenticate client connections.

#### User definition
```
- name: kind-mordor
  user:
    client-certificate-data: DATA+OMITTED
    client-key-data: DATA+OMITTED
```

Interesting note from the `NamedAuthInfo` docs, `user` and `AuthInfo` seem to be synonymous
according to these docs (which checks out based on the output of `kubectl config get-contexts`).

> user [Required] AuthInfo: AuthInfo holds the auth information

[AuthInfo resource docs](https://kubernetes.io/docs/reference/config-api/kubeconfig.v1/#AuthInfo)

Random tangent: noticed the `v1` on all these kubeconfig docs pages... googled v2 and found 
[this](https://github.com/kubernetes/kubernetes/issues/30395) lmao

Back to the definition...

> ClientCertificateData contains PEM-encoded data from a client cert file for TLS. Overrides
> ClientCertificate

> ClientKeyData contains PEM-encoded data from a client key file for TLS. Overrides ClientKey

So basically the client cert for authing to the cluster.

Fun aside, it was cool to see a user/authinfo config for one of our google users.
Gonna omit details here (company secrets) but they use the `gke-gcloud-auth-plugin`
for authing via SSO w/google (neato!).

### Gonna stop my rabbit hole here
Seems like `kind` gave me a real nice cluster setup out of the box (woo!)
But I maybe missed some core cluster setup knowledge b/c of this :(
I'm gonna stop my rabbit hole here. Maybe a fun future exercise would be to try to replace the kind
cluster w/a handbuilt control plan/cluster of my own running in docker (idk how hard that is).

## I wanna deploy something...
Kinda like a hello world app...

I know we use `helm` at MO, but I think that is something built on top of kubernetes.

I wanna reach for maybe the simplest way to get a pod that runs [this hello world
image](https://hub.docker.com/_/hello-world).

Searching around I remember I need a node to be able to run a pod... let's see if I have any:

```
[pbj@meadow]~/code/wut-is-k8s $ kubectl get nodes
NAME                   STATUS   ROLES           AGE   VERSION
mordor-control-plane   Ready    control-plane   64m   v1.32.2
```

Seems like I can use the control plane for now. I could also spin up worker nodes w/`kind`
([instructions](https://kind.sigs.k8s.io/docs/user/quick-start#advanced)).

I'm gonna stick w/my one node for now. Maybe a fun future exercise is trying to manually spin
up a new node from resource definitions... sounds tough.


### Deploying hello-world

Simple pod resource definition:

```
apiVersion: v1
kind: Pod
metadata:
  name: hello-world
spec:
  containers:
    - name: hello-world
      image: hello-world
```

```
[pbj@meadow]~/code/wut-is-k8s $ kubectl apply -f hello-world-pod.yaml`
pod/hello-world created
```

That went easier than expected! Here are some events:

```
Events:
  Type     Reason     Age                    From               Message
  ----     ------     ----                   ----               -------
  Normal   Scheduled  5m27s                  default-scheduler  Successfully assigned default/hello-world to mordor-control-plane
  Normal   Pulled     5m24s                  kubelet            Successfully pulled image "hello-world" in 2.825s (2.825s including waiting). Image size: 17098 bytes.
  Normal   Pulled     5m22s                  kubelet            Successfully pulled image "hello-world" in 927ms (927ms including waiting). Image size: 17098 bytes.
  Normal   Pulled     5m8s                   kubelet            Successfully pulled image "hello-world" in 910ms (910ms including waiting). Image size: 17098 bytes.
  Normal   Pulled     4m41s                  kubelet            Successfully pulled image "hello-world" in 939ms (939ms including waiting). Image size: 17098 bytes.
  Normal   Pulled     3m47s                  kubelet            Successfully pulled image "hello-world" in 1.092s (1.092s including waiting). Image size: 17098 bytes.
  Normal   Pulling    2m20s (x6 over 5m27s)  kubelet            Pulling image "hello-world"
  Normal   Created    2m19s (x6 over 5m24s)  kubelet            Created container: hello-world
  Normal   Started    2m19s (x6 over 5m24s)  kubelet            Started container hello-world
  Normal   Pulled     2m19s                  kubelet            Successfully pulled image "hello-world" in 973ms (973ms including waiting). Image size: 17098 bytes.
  Warning  BackOff    6s (x26 over 5m21s)    kubelet            Back-off restarting failed container hello-world in pod hello-world_default(d576c6b3-c32b-4d97-ad18-a5422820bdef)
```

Lmao forgot that my pod would be restarted. Let's change that by adding a `restartPolicy`

```
spec:
  ...
  restartPolicy: Never
```

Tried to apply again and it complained b/c I was updating a non-editable field. Learned about
`delete`:

```
[pbj@meadow]~/code/wut-is-k8s $ kubectl delete -f hello-world-pod.yaml
pod "hello-world" deleted
```

Re-applied. Worked like a charm:
```
[pbj@meadow]~/code/wut-is-k8s $ kubectl get pods
NAME          READY   STATUS      RESTARTS   AGE
hello-world   0/1     Completed   0          6s
[pbj@meadow]~/code/wut-is-k8s $ kubectl logs hello-world

Hello from Docker!
This message shows that your installation appears to be working correctly.

To generate this message, Docker took the following steps:
 1. The Docker client contacted the Docker daemon.
 2. The Docker daemon pulled the "hello-world" image from the Docker Hub.
    (arm64v8)
 3. The Docker daemon created a new container from that image which runs the
    executable that produces the output you are currently reading.
 4. The Docker daemon streamed that output to the Docker client, which sent it
    to your terminal.

To try something more ambitious, you can run an Ubuntu container with:
 $ docker run -it ubuntu bash

Share images, automate workflows, and more with a free Docker ID:
 https://hub.docker.com/

For more examples and ideas, visit:
 https://docs.docker.com/get-started
```

Events show just the one run too. Nice!

```
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  26s   default-scheduler  Successfully assigned default/hello-world to mordor-control-plane
  Normal  Pulling    25s   kubelet            Pulling image "hello-world"
  Normal  Pulled     24s   kubelet            Successfully pulled image "hello-world" in 980ms (980ms including waiting). Image size: 17098 bytes.
  Normal  Created    24s   kubelet            Created container: hello-world
  Normal  Started    24s   kubelet            Started container hello-world
```

Gonna stop for now. Not sure where I want to go next.
