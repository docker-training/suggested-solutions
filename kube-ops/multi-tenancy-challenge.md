# Suggested Solution: Launch Multiple Workloads

While a variety of methods could be used to reach a solution, the following is a suggested solution, complete with the steps to launch another Ghost application instance using the same MySQL DB backend.  As you review or work through the following steps, you will see that multi-tenancy inherently means duplication of similar Kubernetes objects across the cluster.  A point of consideration for multi-tenancy in Kubernetes is how to ease the friction of reusing cluster object configuration across tenant boundaries.  In any solution, what is paramount is that all involved in the software lifecycle (e.g. developers, integrators, operators, etc.) are aware of and in consensus with the selected solution. 

The following steps start just after the creation the creation of the `yourblog-secrets.txt`.

## Create a Kubernetes Work Context

To ensure our work is committed to the correct namespace, we will create a workspace context that enables the creation of Kubernetes objects into the `yourblog` namespace.


1.  Make and move to a `yourblog` directory to store our YAML and configuration files for setting up a second instance of Ghost:
    
    ```bash
    ubuntu@master0:~/multitenant$ mkdir yourblog ; cd yourblog/
    ubuntu@master0:~/multitenant/yourblog$
    ```

2.  Per multi-tenant best practice, create a new Kubernetes namespace called `yourblog` and a new `kubectl` context for it:

    ```bash
    ubuntu@master0:~/multitenant/yourblog$ kubectl create namespace yourblog
    namespace/yourblog created

    ubuntu@master0:~/multitenant/yourblog$ kubectl config set-context yourblog \
        --cluster=kubernetes.local --user=kubernetes-admin --namespace=yourblog
    
    Context "yourblog" created.

    ubuntu@master0:~/multitenant/yourblog$ kubectl config use-context yourblog
    Switched to context "yourblog".
    ```

    With the kubectl context switched, we can focus on creating Kubernetes objects knowing that they will be created in the `yourblog` namespace without the need for additional parameters.

## Resource Quota Allocation

In the following exercises, we will create both `ResourceQuota` and `LimitRange` objects for the `yourblog` namespace.  Recall our logic for configuring these objects is for lab purposes, a production-grade cluster most likely will require additional, custom configuration to fit your organization's workload requirements.  As such, we will reuse our existing YAML files to create these objects within the `yourblog` namespace.

1.  Create the `compute-quota` object in the `yourblog` namespace:

    ```bash
    ubuntu@master0:~/multitenant/yourblog$ kubectl create -f ~/multitenant/compute-quota.yaml
    
    resourcequota/compute-quota created
    ```

2.  Check the details of the `compute-quota`:

    ```bash
    ubuntu@master0:~/multitenant/yourblog$ kubectl describe quota
    
    Name:            compute-quota
    Namespace:       yourblog
    Resource         Used  Hard
    --------         ----  ----
    limits.cpu       0     5
    limits.memory    0     2Gi
    requests.cpu     0     1
    requests.memory  0     1Gi
    ```

3.  Create the object quotas to the `yourblog` namespace:

    ```bash
    ubuntu@master0:~/multitenant/yourblog$ kubectl create -f ~/multitenant/object-quota.yaml

    resourcequota/object-quota created
    ```

4.  Check on the `object-counts` object status:

    ```bash
    ubuntu@master0:~/multitenant$ kubectl describe quota object-counts

    Name:                   object-counts
    Namespace:              yourblog
    Resource                Used  Hard
    --------                ----  ----
    configmaps              0     5
    persistentvolumeclaims  0     4
    pods                    0     10
    secrets                 1     10
    services                0     10
    services.nodeports      0     2
    ```

    With our ResourceQuota objects created, let's now look at implementing `LimitRange` objects.

## Limit Range Allocation

In the following exercises, we will configure a default `LimitRange` object for containers running in the  `yourblog` namespace.  Specifically, we will define specs for cpu, memory, and persistent volume claims.  Considering our purpose, we will reuse the previously created YAML to create the `LimitRange` object.

1.  Create the `resource-limit-range` object:

    ```bash
    ubuntu@master0:~/multitenant/yourblog$ kubectl apply -f ~/multitenant/lr-resource-defaults.yaml
    
    limitrange/resource-limit-range created
    ```

3.  Verify `resource-limit-range` object status:

    ```bash
    ubuntu@master0:~/multitenant$ kubectl describe limitranges
    
    Name:                  resource-limit-range
    Namespace:             yourblog
    Type                   Resource  Min    Max  Default Request  Default Limit  ....
    ----                   --------  ---    ---  ---------------  -------------  
    Container              cpu       -      -    200m             500m           
    Container              memory    -      -    200Mi            512Mi          
    PersistentVolumeClaim  storage   100Mi  1Gi  -                -              
    ```

    As we have declared defaults for container specs, we have covered off any unintentional absent declarations sent to the API server. Our next step is to create the objects needed for our second `ghost` application.

## Create a Secrets Object

 Recall that `Secret` objects are namespace-bound, which means we will need to create a separate `Secret` object for our second Ghost instance.  We will need to place our `yourblog-secrets.txt` file into our new `yourblog` directory to simplify object creation.

1.  Move the `yourblog-secrets.txt` into the `yourblog` directory:
    
    ```bash
    ubuntu@master0:~/multitenant/yourblog$ mv ~/multitenant/yourblog-secrets.txt .
    ```

2.  Create a Kubernetes secret from the `yourblog-secrets.txt` file:

    ```bash
    ubuntu@master0:~/multitenant/yourblog$ kubectl create generic yourblog-secrets \
        --from-env-file=yourblog-secrets.txt
    
    secret/yourblog-secrets created
    ```

## Create a Service Object for the Second Ghost Instance

1.  Similarly, we will need a `service` object for our second Ghost instance.  Define a service type of `NodePort` for our second Ghost deployment in the file `~/multitenant/yourblog/ghost-custom-service.yaml`:

    ```yaml
    apiVersion: v1
    kind: Service
      metadata:
        name: yourblog
    spec:
      type: NodePort
      ports:
      - port: 8080
        targetPort: 8080
      selector:
        app: ghost
        track: custom
    ```

2.  Create the `NodePort` service:

    ```bash
    ubuntu@master0:~/multitenant/yourblog$ kubectl apply -f ghost-custom-service.yaml

    service/yourblog created
    ```

3.  Verify the service status and assign the `NodePort` number (in this case 32267) to a variable:

    <pre>
    ubuntu@master0:~/multitenant/yourblog$ kubectl describe svc yourblog

    Name:                     yourblog
    Namespace:                default
    Labels:                   <none>
    Annotations:              kubectl.kubernetes.io/last-applied-configuration:
    Selector:                 app=ghost,track=custom
    Type:                     NodePort
    IP:                       10.233.54.79
    Port:                     <unset>  8080/TCP
    TargetPort:               8080/TCP<font color=green>
    NodePort:                 <unset>  32267/TCP</font>
    Endpoints:                <none>
    Session Affinity:         None
    External Traffic Policy:  Cluster
    Events:                   <none>

    ubuntu@master0:~/multitenant/yourblog$ export GhostPort=$(kubectl get svc yourblog -o jsonpath={..nodePort})

    ubuntu@master0:~/multitenant/yourblog$ echo $GhostPort
    32267
    </pre>

## Create a Config Map for the Second Ghost Instance

We need to create a `configMap` for our second Ghost instance.  We can use the `nginx-ghost.conf` and `docker-entrypoint.sh` files we created previously as is, but, in order to use the `ghost-config.js`, we will need to make the following configuration changes: 

- Configure the `url` key-value pair to use the `NodePort` number from the previous step (i.e. 32267)
- Configure the MySQL `host` key-value pair to use the MySQL instance in the `myblog` namespace

1.  Create a sub-directory to hold all the configuration files for the `ConfigMap`:

    ```bash
    ubuntu@master0:~/multitenant/yourblog$ mkdir yourblog-configs
    ```

2.  Copy ghost configuration files to the `yourblog-configs` directory:

    ```bash
    ubuntu@master0:~/multitenant/yourblog$ cp ~/multitenant/ghost-configs/* ./yourblog-configs
    ```

3.  Modify the `ghost-config.js` file with the required configuration changes as shown in <font color=orange>orange</font>:

    <pre>
    var path = require('path'),
        config;
    ....
    development: {
        ...<font color=orange>
        url: 'http://{public IP of master0}:{NodePort of yourblog service}'</font>

        database: {
            ...<font color=orange>
            host    : 'mysql-internal.myblog',</font>
        ....
    </pre>

4. Create the `ConfigMap` for our second Ghost instance:

    ```bash
    ubuntu@master0:~/multitenant/yourblog$ kubectl create configmap yourblog-cm \ 
        --from-file=~/multitenant/yourblog/yourblog-configs
    
    configmap/yourblog-cm created
    ```

5. Verify the settings of the `ConfigMap`:

    ```bash
    ubuntu@master0:~/multitenant/yourblog$ kubectl descrbe cm yourblog-cm

    Name:         yourblog-cm
    Namespace:    yourblog
    Labels:       <none>
    Annotations:  <none>

    Data
    ====
    docker-entrypoint.sh:
    ....

    ghost-config.js:
    ----
    ....

    nginx-ghost.conf:
    ----
    ....

    Events: <none>

## Create a Deployment for the Second Ghost Instance

We are now ready to declare and create a Deployment object for our second Ghost instance.  

1.  The following YAML is similar to our first Ghost deployment, however, the appropriate changes to refer to our `yourblog` Kubernetes objects have been used instead of the original declarations.  Declare a the second ghost deployment in the file `~/multitenant/yourblog/yourblog-deployment.yaml`:

    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: yourblog
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: ghost
          track: custom
      strategy:
        type: RollingUpdate
      template:
        metadata:
          labels:
            app: ghost
            track: custom
        spec:
          containers:
          - name: nginx
            image: nginx:1.15
            ports:
            - containerPort: 8080
            volumeMounts:
            - name: nginx-conf
            mountPath: /etc/nginx/conf.d
          - name: ghost
            image: ghost:0.11
            command:
            - /tmp/ghost/bin/docker-entrypoint.sh
            args: ["npm", "start"]
            ports:
            - containerPort: 2368
            env:
            - name: GHOST_DB_USER
              valueFrom:
                secretKeyRef:
                  name: yourblog-secrets
                  key: username
            - name: GHOST_DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: yourblog-secrets
                  key: password
            - name: GHOST_DB_NAME
              valueFrom:
                secretKeyRef:
                  name: yourblog-secrets
                  key: dbname
            volumeMounts:
            - name: config-js
              mountPath: /tmp/ghost
            - name: docker-entrypoint
              mountPath: /tmp/ghost/bin
          volumes:
          - name: nginx-conf
            configMap:
              name: yourblog-cm
              items:
              - key: nginx-ghost.conf
                path: ghost.conf
          - name: docker-entrypoint
            configMap:
              name: yourblog-cm
              defaultMode: 0777
              items:
              - key:  docker-entrypoint.sh
                path:  docker-entrypoint.sh
          - name: config-js
            configMap:
              name: yourblog-cm
              defaultMode: 0777
              items:
              - key: ghost-config.js
                path: config.js
    ```

2.  Create and verify the deployment:

    ```bash
    ubuntu@master0:~/multitenant/yourblog$ kubectl apply -f yourblog-deployment.yaml
    deployment.apps/yourblog created

    ubuntu@master0:~/multitenant/yourblog$ kubectl get deploy

    NAME               READY   UP-TO-DATE   AVAILABLE   AGE
    yourblog           1/1     1            1           29s
    ```

3.  Open up your local web browser and navigate to http://`<master0 PublicIP>:<yourblog NodePort>` (you can look these up quickly from the command line on `master0` with `echo 'http://'${PublicIP}:${GhostPort}`). You can also administer your ghost application at http://`<Public IP>:<ghost-service NodePort>`/ghost.

## Conclusion

How does your solution compare to the one suggested here?  Perhaps your went a different route and got the same outcome?  Regardless, realize that Kubernetes provides flexibilty with how applications are deployed.  In this suggested solution, much of the YAML and the existing MySQL server created previously was reused with only slight modifications, and this pattern of reusing, not recreating, where possible follows best practice.  Tools such as Helm follow this same pattern with variable substitutions.  When ready return to the multi-tenant lab, and complete the `Clean Up` exercises if remaining. 