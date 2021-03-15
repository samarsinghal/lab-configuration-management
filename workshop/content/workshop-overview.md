### Configuration Best Practices

By separating the configuration data, overhead is reduced to maintaining only a single image for a specific type of instance while retaining the flexibility to create instances with a wide variety of configurations.

Kubernetes has two types of objects that can inject configuration data into a container when it starts up: Secrets and ConfigMaps. Secrets and ConfigMaps behave similarly in Kubernetes, both in how they are created and because they can be exposed inside a container as mounted files or volumes or environment variables.

This exercise explained how to create Kubernetes Secrets and ConfigMaps and how to use those Secrets and ConfigMaps by adding them as environment variables or files inside of a running container instance. 