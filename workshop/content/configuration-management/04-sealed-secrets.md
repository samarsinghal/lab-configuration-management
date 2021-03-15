# Sealed Secrets

Sealed Secrets is composed of two parts: an operator deployed into your cluster and a command-line tool designed to interact with it called kubeseal.


A cluster-side controller / operator
A client-side utility: kubeseal
The kubeseal utility uses asymmetric crypto to encrypt secrets that only the controller can decrypt.

These encrypted secrets are encoded in a SealedSecret resource, which you can see as a recipe for creating a secret. Here is how it looks:

When the operator starts, it generates a private and public key.

The private key stays in the cluster, but you can retrieve the public key with the kubeseal CLI:

kubeseal --fetch-cert > mycert.pem

Once you have the public key, you can encrypt all your secrets.

Storing the public key and the secrets in the repository are safe, even if the repo is public, as the public key is used only for encryption.

The mechanism described above is usually called asymmetric encryption.

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

kubeseal <mysecret.json >mysealedsecret.json

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

You can use the above file to create a SealedSecret in your cluster.


kubectl create -f mysealedsecret.json

The operator is watching for resources.

As soon as it finds a SealedSecret, it uses the private key to decrypt the values and create a standard Kubernetes secret.


You can verify that the secret was created successfully with:

kubectl get secrets mysecret -o yaml

Please notice that the secret created by the operator has the same name as the SealedSecret.

You can use the Secrets in your Pods to inject environment variables or mount them as files.

Since you can only decrypt the secrets with the private key (and that is safely stored in the cluster), you can sleep sweet dreams.

Also, Kubeseal supports secrets rotation.

You can generate a new public and private key and re-encrypt your secrets.

There are some downsides to consider, though:

First, you can't see what's inside the secret. Every time you want to add a new value, you might need to re-encrypt all values or create a separate secret. In Git, you will see the content of the secret changed in full. It's hard to tell if a single entry or all them changed.
Second, Sealed Secret use one key pair to encrypt all your secrets. Also, the key is kept inside the cluster - without any additional protection (for example, using Hardware Security Model).
There are alternative tools to Sealed Secrets that address those two shortcomings.

Helm Secrets
While the underlying mechanism to secure the secrets is similar to Sealed Secrets, there are some noteworthy differences.

Helm secrets is capable of leveraging Helm to template secrets resources.

If you work in a large team with several namespaces and you use Helm already, you might find Helm secrets more convenient than Sealed secrets.

Helm secret has another advantage over Sealed Secrets - it's using the popular open-source project SOPS (developed by Mozilla) for encrypting secrets.

SOPS supports external key management systems, like AWS KMS, making it more secure as it's a lot harder to compromise the keys.

With that said, Helm Secrets and Sealed Secrets share the same issues - to use them, you must have permissions to decrypt the secrets.

If you work as part of a small team this could be a minor issue.

However, if you want to reduce your blast radius, you might not want to hand over the keys to your secrets to every DevOps and Developer in your team.

Also, Helm Secrets is a Helm plugin, and it is strongly coupled to Helm, making it harder to change to other templating mechanisms such as kustomize.

You can learn more about Helm secrets on the official project page.

Kamus
Full disclosure - the author is the lead developer.

The architecture is similar to Sealed Secrets and Helm Secrets. However, Kamus lets you encrypt a secret for a specific application, and only this application can decrypt it.

The more granular permissions make Kamus more suitable to zero-trust environments with a high standard of security.

Kamus works by associating a service account to your secrets.

Only applications running with this service account are allowed to decrypt it.

You can install Kamus in your cluster with the official Helm chart:

bash
helm repo add soluto https://charts.soluto.io
helm upgrade --install kamus soluto/kamus
And you can install the Kamus CLI with:

bash
npm install -g @soluto-asurion/kamus-cli
You can create a secret with the Kamus CLI:

bash
kamus-cli encrypt \
  --secret super-secret \
  --sa kamus-example-sa \
  --namespace default \
  --kamus-url <Kamus URL>
The output is the encrypted secret.

You can store the value safely your repository even if public.

Only the Kamus API has the private key to decrypt it.

To use the secret in your app, you need to add a particular init container to your pod.

The init container is responsible for reading the secrets, decrypting them and producing files in various formats.

Your application can then consume this file to consume the decrypted secrets.

Being able to encrypt and store one secret at the time is convenient if you gradually need to add more secrets to your app.

You can find more examples of how to use Kamus on the official project page.



