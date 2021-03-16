Sealed Secrets are a "one-way" encrypted Secret that can be created by anyone, but can only be decrypted by the controller running in the target cluster. The Sealed Secret is safe to share publicly, upload to git repositories, post to twitter, etc. Once the SealedSecret is safely uploaded to the target Kubernetes cluster, the sealed secrets controller will decrypt it and recover the original Secret.

The SealedSecrets implementation consists of two components:

  A controller that runs in-cluster, and implements a new SealedSecret Kubernetes API object via the "third party resource" mechanism.
    
  A kubeseal command line tool that encrypts a regular Kubernetes Secret object (as YAML or JSON) into a SealedSecret.

The kubeseal utility uses asymmetric crypto to encrypt secrets that only the controller can decrypt. These encrypted secrets are encoded in a SealedSecret resource, which you can see as a recipe for creating a secret. Here is how it looks:

When the operator starts, it generates a private and public key. The private key stays in the cluster, but you can retrieve the public key with the kubeseal CLI:

  kubeseal --fetch-cert > mycert.pem

Once you have the public key, you can encrypt all your secrets. Storing the public key and the secrets in the repository are safe, even if the repo is public, as the public key is used only for encryption.

Assuming you have a secret in JSON format like this:

  {
    "kind": "Secret",
    "apiVersion": "v1",
    "metadata": {
        "name": "mysecret",
        "creationTimestamp": null
    },
    "data": {
        "foo": "YmFy"
    }
  }

You can encrypt the secret with:

  ```execute
  kubeseal < mysecret.json > mysealedsecret.json
  ```

The kubeseal tool reads the JSON/YAML representation of a Secret on stdin, and produces the equivalent (encrypted) SealedSecret on stdout. 

  ```execute
  cat mysealedsecret.json
  ```

The new file contains a Custom Resourced Definition (CRD):

    {
      "kind": "SealedSecret",
      "apiVersion": "bitnami.com/v1alpha1",
      "metadata": {
        "name": "mysecret",
        "namespace": "default",
        "creationTimestamp": null
      },
      "spec": {
        "template": {
          "metadata": {
            "name": "mysecret",
            "namespace": "default",
            "creationTimestamp": null
          }
        },
        "encryptedData": {
          "foo": "<encrypted data here>"
        }
      }
    }

You can use the above file to create a SealedSecret in your cluster. On workshop you don't have permission to create SealedSecret resource 

  ```
  kubectl create -f mysealedsecret.json
  ```

Output 

  Error from server (Forbidden): error when creating "mysealedsecret.json": sealedsecrets.bitnami.com is forbidden: User "system:serviceaccount:portal-w03:portal-w03-s001" cannot create resource "sealedsecrets" in API group "bitnami.com" in the namespace "portal-w03-s001"

The operator is watching for resources. As soon as it finds a SealedSecret, it uses the private key to decrypt the values and create a standard Kubernetes secret. Once decrypted by the controller, the enclosed Secret can be used exactly like a regular K8s Secret (it is a regular K8s Secret at this point!). If the SealedSecret object is deleted, the controller will garbage collect the generated Secret.


Please notice that the secret created by the operator has the same name as the SealedSecret. You can use the Secrets in your Pods to inject environment variables or mount them as files.

There are some downsides to consider, though:

  First, you can't see what's inside the secret. Every time you want to add a new value, you might need to re-encrypt all values or create a separate secret. In Git, you will see the content of the secret changed in full. It's hard to tell if a single entry or all them changed.

  Second, Sealed Secret use one key pair to encrypt all your secrets. Also, the key is kept inside the cluster - without any additional protection (for example, using Hardware Security Model).

There are alternative tools to Sealed Secrets that address those two shortcomings.

## Helm Secrets

While the underlying mechanism to secure the secrets is similar to Sealed Secrets, there are some noteworthy differences. Helm secrets is capable of leveraging Helm to template secrets resources. Helm secret has another advantage over Sealed Secrets - it's using the popular open-source project SOPS (developed by Mozilla) for encrypting secrets. SOPS supports external key management systems, like AWS KMS, making it more secure as it's a lot harder to compromise the keys.

If you work in a large team with several namespaces and you use Helm already, you might find Helm secrets more convenient than Sealed secrets.
With that said, Helm Secrets and Sealed Secrets share the same issues - to use them, you must have permissions to decrypt the secrets.

If you work as part of a small team this could be a minor issue. However, if you want to reduce your blast radius, you might not want to hand over the keys to your secrets to every DevOps and Developer in your team.

Also, Helm Secrets is a Helm plugin, and it is strongly coupled to Helm, making it harder to change to other templating mechanisms such as kustomize.


## Kamus

The architecture is similar to Sealed Secrets and Helm Secrets. However, Kamus lets you encrypt a secret for a specific application, and only this application can decrypt it. The more granular permissions make Kamus more suitable to zero-trust environments with a high standard of security.

Kamus works by associating a service account to your secrets. Only applications running with this service account are allowed to decrypt it.

Same concept You can store the value safely your repository even if public. Only the Kamus API has the private key to decrypt it. To use the secret in your app, you need to add a particular init container to your pod. The init container is responsible for reading the secrets, decrypting them and producing files in various formats.

Your application can then consume this file to consume the decrypted secrets. Being able to encrypt and store one secret at the time is convenient if you gradually need to add more secrets to your app.
