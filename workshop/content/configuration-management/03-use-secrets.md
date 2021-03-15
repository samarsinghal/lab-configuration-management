## Using Secrets

Secrets can be mounted as data volumes or exposed as container-env-variables
to be used by a container in a Pod. Secrets can also be used by other parts of the
system, without being directly exposed to the Pod. For example, Secrets can hold
credentials that other parts of the system should use to interact with external
systems on your behalf.

### Using Secrets as files from a Pod

To consume a Secret in a volume in a Pod:

1. Create a secret or use an existing one. Multiple Pods can reference the same secret.
2. Modify your Pod definition to add a volume under `.spec.volumes[]`. Name the volume anything, and have a `.spec.volumes[].secret.secretName` field equal to the name of the Secret object.
3. Add a `.spec.containers[].volumeMounts[]` to each container that needs the secret. Specify `.spec.containers[].volumeMounts[].readOnly = true` and `.spec.containers[].volumeMounts[].mountPath` to an unused directory name where you would like the secrets to appear.
4. Modify your image or command line so that the program looks for files in that directory. Each key in the secret `data` map becomes the filename under `mountPath`.

```execute
kubectl create secret generic mysecret \
  --from-literal=username=admin \
  --from-literal=password='1f2d1e2e67df'
```


Look at a Pod defination that mounts a Secret in a volume:

```execute
cat pod-secret-volume.yaml
```

Create a pod

```execute
kubectl create -f pod-secret-volume.yaml
```

Each Secret you want to use needs to be referred to in `.spec.volumes`.

If there are multiple containers in the Pod, then each container needs its
own `volumeMounts` block, but only one `.spec.volumes` is needed per Secret.

You can package many files into one secret, or use many secrets, whichever is convenient.

#### Consuming Secret values from volumes

Inside the container that mounts a secret volume, the secret keys appear as
files and the secret values are base64 decoded and stored inside these files.
This is the result of commands executed inside the container from the example above:

```execute
ls /etc/foo/
```

The output is similar to:

```
username
password
```

```execute
cat /etc/foo/username
```

The output is similar to:

```
admin
```

```execute
cat /etc/foo/password
```

The output is similar to:

```
1f2d1e2e67df
```

The program in a container is responsible for reading the secrets from the files.

#### Mounted Secrets are updated automatically

When a secret currently consumed in a volume is updated, projected keys are eventually updated as well.
The kubelet checks whether the mounted secret is fresh on every periodic sync.
However, the kubelet uses its local cache for getting the current value of the Secret.

A Secret can be either propagated by watch (default), ttl-based, or by redirecting
all requests directly to the API server.
As a result, the total delay from the moment when the Secret is updated to the moment
when new keys are projected to the Pod can be as long as the kubelet sync period + cache
propagation delay, where the cache propagation delay depends on the chosen cache type
(it equals to watch propagation delay, ttl of cache, or zero correspondingly).


### Using Secrets as environment variables

To use a secret in an {{< glossary_tooltip text="environment variable" term_id="container-env-variables" >}}
in a Pod:

1. Create a secret or use an existing one.  Multiple Pods can reference the same secret.
1. Modify your Pod definition in each container that you wish to consume the value of a secret key to add an environment variable for each secret key you wish to consume. The environment variable that consumes the secret key should populate the secret's name and key in `env[].valueFrom.secretKeyRef`.
1. Modify your image and/or command line so that the program looks for values in the specified environment variables.

Look at a Pod defination that uses secrets from environment variables:

```execute
cat pod-secret-env-variable.yaml
```

Create a pod

```execute
kubectl create -f pod-secret-env-variable.yaml
```

#### Consuming Secret Values from environment variables

Inside a container that consumes a secret in the environment variables, the secret keys appear as
normal environment variables containing the base64 decoded values of the secret data.
This is the result of commands executed inside the container from the example above:

```shell
echo $SECRET_USERNAME
```

The output is similar to:

```
admin
```

```shell
echo $SECRET_PASSWORD
```

The output is similar to:

```
1f2d1e2e67df
```

#### Environment variables are not updated after a secret update

If a container already consumes a Secret in an environment variable, a Secret update will not be seen by the container unless it is restarted.
There are third party solutions for triggering restarts when secrets change.

#### Reloader

Reloader can watch changes in ConfigMap and Secret and do rolling upgrades on Pods with their associated DeploymentConfigs, Deployments, Daemonsets Statefulsets and Rollouts.

https://github.com/samarsinghal/Reloader


## Immutable Secrets {#secret-immutable}

The Kubernetes beta feature _Immutable Secrets and ConfigMaps_ provides an option to set
individual Secrets and ConfigMaps as immutable. For clusters that extensively use Secrets
(at least tens of thousands of unique Secret to Pod mounts), preventing changes to their
data has the following advantages:

- protects you from accidental (or unwanted) updates that could cause applications outages
- improves performance of your cluster by significantly reducing load on kube-apiserver, by
closing watches for secrets marked as immutable.

This feature is controlled by the `ImmutableEphemeralVolumes` [feature
gate](/docs/reference/command-line-tools-reference/feature-gates/),
which is enabled by default since v1.19. You can create an immutable
Secret by setting the `immutable` field to `true`. For example,
```yaml
apiVersion: v1
kind: Secret
metadata:
  ...
data:
  ...
immutable: true
```

Once a Secret or ConfigMap is marked as immutable, it is _not_ possible to revert this change
nor to mutate the contents of the `data` field. You can only delete and recreate the Secret.
Existing Pods maintain a mount point to the deleted Secret - it is recommended to recreate
these pods.

### Using imagePullSecrets

The `imagePullSecrets` field is a list of references to secrets in the same namespace.
You can use an `imagePullSecrets` to pass a secret that contains a Docker (or other) image registry
password to the kubelet. The kubelet uses this information to pull a private image on behalf of your Pod.


### Arranging for imagePullSecrets to be automatically attached

You can manually create `imagePullSecrets`, and reference it from
a ServiceAccount. Any Pods created with that ServiceAccount
or created with that ServiceAccount by default, will get their `imagePullSecrets`
field set to that of the service account.

### Secret and Pod lifetime interaction

When a Pod is created by calling the Kubernetes API, there is no check if a referenced
secret exists. Once a Pod is scheduled, the kubelet will try to fetch the
secret value. If the secret cannot be fetched because it does not exist or
because of a temporary lack of connection to the API server, the kubelet will
periodically retry. It will report an event about the Pod explaining the
reason it is not started yet. Once the secret is fetched, the kubelet will
create and mount a volume containing it. None of the Pod's containers will
start until all the Pod's volumes are mounted.

## Security properties

### Protections

Because secrets can be created independently of the Pods that use
them, there is less risk of the secret being exposed during the workflow of
creating, viewing, and editing Pods. The system can also take additional
precautions with Secrets, such as avoiding writing them to disk where
possible.

A secret is only sent to a node if a Pod on that node requires it.
The kubelet stores the secret into a `tmpfs` so that the secret is not written
to disk storage. Once the Pod that depends on the secret is deleted, the kubelet
will delete its local copy of the secret data as well.

There may be secrets for several Pods on the same node. However, only the
secrets that a Pod requests are potentially visible within its containers.
Therefore, one Pod does not have access to the secrets of another Pod.

There may be several containers in a Pod. However, each container in a Pod has
to request the secret volume in its `volumeMounts` for it to be visible within
the container. This can be used to construct useful [security partitions at the
Pod level](#use-case-secret-visible-to-one-container-in-a-pod).

On most Kubernetes distributions, communication between users
and the API server, and from the API server to the kubelets, is protected by SSL/TLS.
Secrets are protected when transmitted over these channels.


### Risks

 - In the API server, secret data is stored in etcd therefore:
   - Administrators should enable encryption at rest for cluster data (requires v1.13 or later).
   - Administrators should limit access to etcd to admin users.
   - Administrators may want to wipe/shred disks used by etcd when no longer in use.
   - If running etcd in a cluster, administrators should make sure to use SSL/TLS
     for etcd peer-to-peer communication.
 - If you configure the secret through a manifest (JSON or YAML) file which has
   the secret data encoded as base64, sharing this file or checking it in to a
   source repository means the secret is compromised. Base64 encoding is _not_ an
   encryption method and is considered the same as plain text.
 - Applications still need to protect the value of secret after reading it from the volume,
   such as not accidentally logging it or transmitting it to an untrusted party.
 - A user who can create a Pod that uses a secret can also see the value of that secret. Even
   if the API server policy does not allow that user to read the Secret, the user could
   run a Pod which exposes the secret.
 - Currently, anyone with root permission on any node can read _any_ secret from the API server,
   by impersonating the kubelet. It is a planned feature to only send secrets to
   nodes that actually require them, to restrict the impact of a root exploit on a
   single node.


