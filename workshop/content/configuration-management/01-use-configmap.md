## Define container environment variables using ConfigMap data

### Define a container environment variable with data from a single ConfigMap

1.  Define an environment variable as a key-value pair in a ConfigMap:

    ```execute
    kubectl create configmap special-config --from-literal=special.how=very
    ```

2.  Assign the `special.how` value defined in the ConfigMap to the `SPECIAL_LEVEL_KEY` environment variable in the Pod specification.

    ```execute
    cat pod-single-configmap-env-variable.yaml
    ```

    Create the Pod:

    ```execute
    kubectl create -f pod-single-configmap-env-variable.yaml
    ```

    ```execute
    kubectl logs single-configmap-env-variable 
    ```

   Now, the Pod's output includes environment variable `SPECIAL_LEVEL_KEY=very`.

## Configure all key-value pairs in a ConfigMap as container environment variables

* Create a ConfigMap containing multiple key-value pairs.

  ```execute
  cat configmap-multikeys.yaml
  ```

Create the ConfigMap:

  ```execute
  kubectl create -f configmap-multikeys.yaml
  ```

* Use `envFrom` to define all of the ConfigMap's data as container environment variables. The key from the ConfigMap becomes the environment variable name in the Pod.

  ```execute
  cat pod-configmap-envFrom.yaml
  ```

 Create the Pod:

  ```execute
  kubectl create -f pod-configmap-envFrom.yaml
  ```

  ```execute
  kubectl logs multikey-configmap-env-variable 
  ```

 Now, the Pod's output includes environment variables `SPECIAL_LEVEL=very` and `SPECIAL_TYPE=charm`.


## Add ConfigMap data to a Volume

As explained in [Create ConfigMaps from files](#create-configmaps-from-files), when you create a ConfigMap using ``--from-file``, the filename becomes a key stored in the `data` section of the ConfigMap. The file contents become the key's value.

The examples in this section refer to a ConfigMap named special-config, shown below.

  ```execute
  cat configmap-multikeys.yaml
  ```

Create the ConfigMap, if it's not created:

  ```execute
  kubectl create -f configmap-multikeys.yaml
  ```

### Populate a Volume with data stored in a ConfigMap

Add the ConfigMap name under the `volumes` section of the Pod specification.
This adds the ConfigMap data to the directory specified as `volumeMounts.mountPath` (in this case, `/etc/config`).
The `command` section lists directory files with names that match the keys in ConfigMap.

  ```execute
  cat pod-configmap-volume.yaml
  ```

Create the Pod:

  ```execute
  kubectl create -f pod-configmap-volume.yaml
  ```

When the pod runs, the command `ls /etc/config/` produces the output below:

  SPECIAL_LEVEL
  SPECIAL_TYPE

If there are some files in the `/etc/config/` directory, they will be deleted.

Text data is exposed as files using the UTF-8 character encoding. To use some other character encoding, use binaryData.

### Mounted ConfigMaps are updated automatically

When a ConfigMap already being consumed in a volume is updated, projected keys are eventually updated as well. Kubelet is checking whether the mounted ConfigMap is fresh on every periodic sync. However, it is using its local ttl-based cache for getting the current value of the ConfigMap. As a result, the total delay from the moment when the ConfigMap is updated to the moment when new keys are projected to the pod can be as long as kubelet sync period (1 minute by default) + ttl of ConfigMaps cache (1 minute by default) in kubelet. You can trigger an immediate refresh by updating one of the pod's annotations.

A container using a ConfigMap as a [subPath](/docs/concepts/storage/volumes/#using-subpath) volume will not receive ConfigMap updates.


### Restrictions

- You must create a ConfigMap before referencing it in a Pod specification (unless you mark the ConfigMap as "optional"). If you reference a ConfigMap that doesn't exist, the Pod won't start. Likewise, references to keys that don't exist in the ConfigMap will prevent the pod from starting.

- If you use `envFrom` to define environment variables from ConfigMaps, keys that are considered invalid will be skipped. The pod will be allowed to start, but the invalid names will be recorded in the event log (`InvalidVariableNames`). The log message lists each skipped key. For example:

   ```execute
   kubectl get events
   ```

   The output is similar to this:
   ```
   LASTSEEN FIRSTSEEN COUNT NAME          KIND  SUBOBJECT  TYPE      REASON                            SOURCE                MESSAGE
   0s       0s        1     dapi-test-pod Pod              Warning   InvalidEnvironmentVariableNames   {kubelet, 127.0.0.1}  Keys [1badkey, 2alsobad] from the EnvFrom configMap default/myconfig were skipped since they are considered invalid environment variable names.
   ```

- ConfigMaps reside in a specific namespace. A ConfigMap can only be referenced by pods residing in the same namespace.

- You can't use ConfigMaps for static pods, because the Kubelet does not support this.
