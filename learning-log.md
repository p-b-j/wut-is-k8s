# k8s learning log

## spinning up a toy environment

Installed [kind](https://kind.sigs.k8s.io/) and spun up a new cluster w/

```bash
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
