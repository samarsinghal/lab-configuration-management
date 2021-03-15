Secrets are similar to ConfigMaps. The only big difference between them is the base64-encoding obfuscation. 

ConfigMaps are intended for non-sensitive data—configuration data—like config files and environment variables and are a great way to create customized running services from generic container images where as Secrets are a Kubernetes object intended for storing a small amount of sensitive data, such as passwords, OAuth tokens, and ssh keys. 

Kubernetes Secrets are, by default, stored as unencrypted base64-encoded
strings. By default they can be retrieved - as plain text - by anyone with API
access, or anyone with access to Kubernetes' underlying data store, etcd. In
order to safely use Secrets, it is recommended you (at a minimum):

1. [Enable Encryption at Rest](/docs/tasks/administer-cluster/encrypt-data/) for Secrets.
2. [Enable or configure RBAC rules](/docs/reference/access-authn-authz/authorization/) that restrict reading and writing the Secret. Extremely sensitive Secrets data should probably be stored using something like HashiCorp Vault. Be aware that secrets can be obtained implicitly by anyone with the permission to create a Pod.

## Overview of Secrets

To use a Secret, a Pod needs to reference the Secret.
A Secret can be used with a Pod in three ways:

- As [files](#using-secrets-as-files-from-a-pod) in a volume mounted on one or more of its containers.
- As [container environment variable](#using-secrets-as-environment-variables).
- By the [kubelet when pulling images](#using-imagepullsecrets) for the Pod.


## Types of Secret {#secret-types}

When creating a Secret, you can specify its type using the `type` field of
the [`Secret`](/docs/reference/generated/kubernetes-api/{{< param "version" >}}/#secret-v1-core)
resource, or certain equivalent `kubectl` command line flags (if available).
The Secret type is used to facilitate programmatic handling of the Secret data.

Kubernetes provides several builtin types for some common usage scenarios.
These types vary in terms of the validations performed and the constraints
Kubernetes imposes on them.

| Builtin Type | Usage |
|--------------|-------|
| `Opaque`     |  arbitrary user-defined data |
| `kubernetes.io/service-account-token` | service account token |
| `kubernetes.io/dockercfg` | serialized `~/.dockercfg` file |
| `kubernetes.io/dockerconfigjson` | serialized `~/.docker/config.json` file |
| `kubernetes.io/basic-auth` | credentials for basic authentication |
| `kubernetes.io/ssh-auth` | credentials for SSH authentication |
| `kubernetes.io/tls` | data for a TLS client or server |
| `bootstrap.kubernetes.io/token` | bootstrap token data |

You can define and use your own Secret type by assigning a non-empty string as the
`type` value for a Secret object. An empty string is treated as an `Opaque` type.
Kubernetes doesn't impose any constraints on the type name. However, if you
are using one of the builtin types, you must meet all the requirements defined
for that type.

### Opaque secrets

`Opaque` is the default Secret type if omitted from a Secret configuration file.
When you create a Secret using `kubectl`, you will use the `generic`
subcommand to indicate an `Opaque` Secret type. For example, the following
command creates an empty Secret of type `Opaque`.

```execute
kubectl create secret generic empty-secret
kubectl get secret empty-secret
```

The output looks like:

```
NAME           TYPE     DATA   AGE
empty-secret   Opaque   0      2m6s
```

The `DATA` column shows the number of data items stored in the Secret.
In this case, `0` means we have just created an empty Secret.

###  Service account token Secrets

A `kubernetes.io/service-account-token` type of Secret is used to store a
token that identifies a service account. When using this Secret type, you need
to ensure that the `kubernetes.io/service-account.name` annotation is set to an
existing service account name. A Kubernetes controller fills in some other
fields such as the `kubernetes.io/service-account.uid` annotation and the
`token` key in the `data` field set to actual token content.

The following example configuration declares a service account token Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret-sa-sample
  annotations:
    kubernetes.io/service-account.name: "sa-name"
type: kubernetes.io/service-account-token
data:
  # You can include additional key value pairs as you do with Opaque Secrets
  extra: YmFyCg==
```

When creating a `Pod`, Kubernetes automatically creates a service account Secret
and automatically modifies your Pod to use this Secret. The service account token
Secret contains credentials for accessing the API.

The automatic creation and use of API credentials can be disabled or
overridden if desired. However, if all you need to do is securely access the
API server, this is the recommended workflow.


### Docker config Secrets

You can use one of the following `type` values to create a Secret to
store the credentials for accessing a Docker registry for images.

- `kubernetes.io/dockercfg`
- `kubernetes.io/dockerconfigjson`

The `kubernetes.io/dockercfg` type is reserved to store a serialized
`~/.dockercfg` which is the legacy format for configuring Docker command line.
When using this Secret type, you have to ensure the Secret `data` field
contains a `.dockercfg` key whose value is content of a `~/.dockercfg` file
encoded in the base64 format.

The `kubernetes.io/dockerconfigjson` type is designed for storing a serialized
JSON that follows the same format rules as the `~/.docker/config.json` file
which is a new format for `~/.dockercfg`.
When using this Secret type, the `data` field of the Secret object must
contain a `.dockerconfigjson` key, in which the content for the
`~/.docker/config.json` file is provided as a base64 encoded string.

Below is an example for a `kubernetes.io/dockercfg` type of Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret-dockercfg
type: kubernetes.io/dockercfg
data:
  .dockercfg: |
    "<base64 encoded ~/.dockercfg file>"
```

If you do not want to perform the base64 encoding, you can choose to use the
`stringData` field instead.

When you create these types of Secrets using a manifest, the API
server checks whether the expected key does exists in the `data` field, and
it verifies if the value provided can be parsed as a valid JSON. The API
server doesn't validate if the JSON actually is a Docker config file.

When you do not have a Docker config file, or you want to use `kubectl`
to create a Docker registry Secret, you can do:

```execute
kubectl create secret docker-registry secret-tiger-docker \
  --docker-username=tiger \
  --docker-password=pass113 \
  --docker-email=tiger@acme.com
```

This command creates a Secret of type `kubernetes.io/dockerconfigjson`.
If you dump the `.dockerconfigjson` content from the `data` field, you will
get the following JSON content which is a valid Docker configuration created
on the fly:

```json
{
  "auths": {
    "https://index.docker.io/v1/": {
      "username": "tiger",
      "password": "pass113",
      "email": "tiger@acme.com",
      "auth": "dGlnZXI6cGFzczExMw=="
    }
  }
}
```

### Basic authentication Secret

The `kubernetes.io/basic-auth` type is provided for storing credentials needed
for basic authentication. When using this Secret type, the `data` field of the
Secret must contain the following two keys:

- `username`: the user name for authentication;
- `password`: the password or token for authentication.

Both values for the above two keys are base64 encoded strings. You can, of
course, provide the clear text content using the `stringData` for Secret
creation.

The following YAML is an example config for a basic authentication Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret-basic-auth
type: kubernetes.io/basic-auth
stringData:
  username: admin
  password: t0p-Secret
```

The basic authentication Secret type is provided only for user's convenience.
You can create an `Opaque` for credentials used for basic authentication.
However, using the builtin Secret type helps unify the formats of your credentials
and the API server does verify if the required keys are provided in a Secret
configuration.

### SSH authentication secrets

The builtin type `kubernetes.io/ssh-auth` is provided for storing data used in
SSH authentication. When using this Secret type, you will have to specify a
`ssh-privatekey` key-value pair in the `data` (or `stringData`) field
as the SSH credential to use.

The following YAML is an example config for a SSH authentication Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret-ssh-auth
type: kubernetes.io/ssh-auth
data:
  # the data is abbreviated in this example
  ssh-privatekey: |
     MIIEpQIBAAKCAQEAulqb/Y ...
```

The SSH authentication Secret type is provided only for user's convenience.
You can create an `Opaque` for credentials used for SSH authentication.
However, using the builtin Secret type helps unify the formats of your credentials
and the API server does verify if the required keys are provided in a Secret
configuration.


SSH private keys do not establish trusted communication between an SSH client and
host server on their own. A secondary means of establishing trust is needed to
mitigate "man in the middle" attacks, such as a `known_hosts` file added to a
ConfigMap.


### TLS secrets

Kubernetes provides a builtin Secret type `kubernetes.io/tls` for storing
a certificate and its associated key that are typically used for TLS . This
data is primarily used with TLS termination of the Ingress resource, but may
be used with other resources or directly by a workload.
When using this type of Secret, the `tls.key` and the `tls.crt` key must be provided
in the `data` (or `stringData`) field of the Secret configuration, although the API
server doesn't actually validate the values for each key.

The following YAML contains an example config for a TLS Secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: secret-tls
type: kubernetes.io/tls
data:
  # the data is abbreviated in this example
  tls.crt: |
    MIIC2DCCAcCgAwIBAgIBATANBgkqh ...
  tls.key: |
    MIIEpgIBAAKCAQEA7yn3bRHQ5FHMQ ...
```

The TLS Secret type is provided for user's convenience. You can create an `Opaque`
for credentials used for TLS server and/or client. However, using the builtin Secret
type helps ensure the consistency of Secret format in your project; the API server
does verify if the required keys are provided in a Secret configuration.

When creating a TLS Secret using `kubectl`, you can use the `tls` subcommand
as shown in the following example:

```execute
kubectl create secret tls my-tls-secret \
  --cert=path/to/cert/file \
  --key=path/to/key/file
```

The public/private key pair must exist before hand. The public key certificate
for `--cert` must be .PEM encoded (Base64-encoded DER format), and match the
given private key for `--key`.
The private key must be in what is commonly called PEM private key format,
unencrypted. In both cases, the initial and the last lines from PEM (for
example, `--------BEGIN CERTIFICATE-----` and `-------END CERTIFICATE----` for
a cetificate) are *not* included.

### Bootstrap token Secrets

A bootstrap token Secret can be created by explicitly specifying the Secret
`type` to `bootstrap.kubernetes.io/token`. This type of Secret is designed for
tokens used during the node bootstrap process. It stores tokens used to sign
well known ConfigMaps.

A bootstrap token Secret is usually created in the `kube-system` namespace and
named in the form `bootstrap-token-<token-id>` where `<token-id>` is a 6 character
string of the token ID.

As a Kubernetes manifest, a bootstrap token Secret might look like the
following:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: bootstrap-token-5emitj
  namespace: kube-system
type: bootstrap.kubernetes.io/token
data:
  auth-extra-groups: c3lzdGVtOmJvb3RzdHJhcHBlcnM6a3ViZWFkbTpkZWZhdWx0LW5vZGUtdG9rZW4=
  expiration: MjAyMC0wOS0xM1QwNDozOToxMFo=
  token-id: NWVtaXRq
  token-secret: a3E0Z2lodnN6emduMXAwcg==
  usage-bootstrap-authentication: dHJ1ZQ==
  usage-bootstrap-signing: dHJ1ZQ==
```

A bootstrap type Secret has the following keys specified under `data`:

- `token-id`: A random 6 character string as the token identifier. Required.
- `token-secret`: A random 16 character string as the actual token secret. Required.
- `description`: A human-readable string that describes what the token is
  used for. Optional.
- `expiration`: An absolute UTC time using RFC3339 specifying when the token
  should be expired. Optional.
- `usage-bootstrap-<usage>`: A boolean flag indicating additional usage for
  the bootstrap token.
- `auth-extra-groups`: A comma-separated list of group names that will be
  authenticated as in addition to the `system:bootstrappers` group.

The above YAML may look confusing because the values are all in base64 encoded
strings. In fact, you can create an identical Secret using the following YAML:

```yaml
apiVersion: v1
kind: Secret
metadata:
  # Note how the Secret is named
  name: bootstrap-token-5emitj
  # A bootstrap token Secret usually resides in the kube-system namespace
  namespace: kube-system
type: bootstrap.kubernetes.io/token
stringData:
  auth-extra-groups: "system:bootstrappers:kubeadm:default-node-token"
  expiration: "2020-09-13T04:39:10Z"
  # This token ID is used in the name
  token-id: "5emitj"
  token-secret: "kq4gihvszzgn1p0r"
  # This token can be used for authentication
  usage-bootstrap-authentication: "true"
  # and it can be used for signing
  usage-bootstrap-signing: "true"
```

## Create a Secret

There are several options to create a Secret:

- [create Secret using `kubectl` command](/docs/tasks/configmap-secret/managing-secret-using-kubectl/)
- [create Secret from config file](/docs/tasks/configmap-secret/managing-secret-using-config-file/)
- [create Secret using kustomize](/docs/tasks/configmap-secret/managing-secret-using-kustomize/)

### Create a Secret manually

To create the Secret containing the MYSQL_ROOT_PASSWORD, choose a password and convert it to base64:

Lets Say The root password will be "KubernetesRocks!"

```execute
echo -n 'KubernetesRocks!' | base64
```

S3ViZXJuZXRlc1JvY2tzIQ==

Make a note of the encoded string. You need it to create the YAML file for the Secret:

```execute
cat mysql-secret.yaml
```

Create the Secret in Kubernetes with the kubectl apply command:

```execute
kubectl apply -f mysql-secret.yaml
```

secret/db-root-password created

View the newly created Secret 

Now that you've created the Secret, use kubectl describe to see it:

```execute
kubectl describe secret db-root-password
```

Name:         db-root-password
Namespace:    secrets-and-configmaps
Labels:       <none>
Annotations:
Type:         Opaque

Data
====
password:  16 bytes
Note that the Data field contains the key you set in the YAML: password. The value assigned to that key is the password you created, but it is not shown in the output. Instead, the value's size is shown in its place, in this case, 16 bytes.

You can also use the kubectl edit secret <secretname> command to edit the Secret and kubectl get secret <secretname> -o yaml to view secret.

```execute
kubectl get secret db-root-password -o yaml
```

Again, the data field with the password key is visible, and this time you can see the base64-encoded Secret.

Decode the Secret
Let's say you need to view the Secret in plain text, for example, to verify that the Secret was created with the correct content. You can do this by decoding it.

It is easy to decode the Secret by extracting the value and piping it to base64. In this case, you will use the output format -o jsonpath=<path> to extract only the Secret value using a JSONPath template.

Returns the base64 encoded secret string

```execute
kubectl get secret db-root-password -o jsonpath='{.data.password}'
```

S3ViZXJuZXRlc1JvY2tzIQ==

Pipe it to `base64 --decode -` to decode:

```execute
kubectl get secret db-root-password -o jsonpath='{.data.password}' | base64 --decode -
```

KubernetesRocks!



### Another way to create Secrets
You can also create Secrets directly using the kubectl create secret command. The db image permits setting up a regular database user with a password by setting the MYSQL_USER and MYSQL_PASSWORD environment variables. A Secret can hold more than one key/value pair, so you can create a single Secret to hold both strings. As a bonus, by using kubectl create secret, you can let Kubernetes mess with base64 so that you don't have to.

```execute
kubectl create secret generic db-user-creds \
      --from-literal=MYSQL_USER=kubeuser\
      --from-literal=MYSQL_PASSWORD=kube-still-rocks
```

secret/db-user-creds created

Note the --from-literal, which sets the key name and the value all in one. You can pass as many --from-literal arguments as you need to create one or more key/value pairs in the Secret.

Validate that the username and password were created and stored correctly with the kubectl get secrets command:

### Get the username

```execute
kubectl get secret db-user-creds -o jsonpath='{.data.MYSQL_USER}' | base64 --decode -
```

kubeuser

### Get the password
```execute
kubectl get secret db-user-creds -o jsonpath='{.data.MYSQL_PASSWORD}' | base64 --decode -
```

kube-still-rocks