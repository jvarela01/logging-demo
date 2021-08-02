# Send application logs to EFK on OpenShift

This example provides two mechanism to sending applications logs to logging instance deployed on OpenShift v4 Cluster.

The sample application used in this example it's a simple container Hello World web page runnig on Apache HTTP Server with the ubi 8 base image.

For the exercise, it is proposed to record the access log output generated by the apache web server using 2 techniques:

- In the first scenario, a sidecar is generated that directly displays the access log output to stdout using the operating system tail command.
- In the second scenario, the Dockerfile file is modified, adding the instructions to replace the access and error log outputs to the standard output in the httpd.conf file. The modified Dockerfile is located in the logs-to-stdout branch

## Prerequisites

- Access to an OCP v4 Cluster.
- oc client installed.
- RedHat OpenShift Logging Operator deployed on OCP v4 Cluster.
- Access to Kibana UI (for validation only).

## Create the demo project

Login to your OCP Cluster via ocp

```bash
$ oc login -u youruser -p yourpassword cluster_api_url
```

Create the logging-demo-project

```bash
$ oc new-project logging-demo
Now using project "logging-demo" on server "cluster_api_url".

You can add applications to this project with the 'new-app' command. For example, try:

    oc new-app rails-postgresql-example

to build a new example application in Ruby. Or use kubectl to deploy a simple Kubernetes application:

    kubectl create deployment hello-node --image=k8s.gcr.io/serve_hostname
```

## First scenario: Sending logs with a sidecar container

Create simple-apache application from git via oc

```bash
$ oc new-app --name simple-apache https://github.com/jvarela01/logging-demo --strategy=docker -n logging-demo
--> Found container image 11f9dba (22 months old) from registry.access.redhat.com for "registry.access.redhat.com/ubi8/ubi:8.0"

    Red Hat Universal Base Image 8 
    ------------------------------ 
    The Universal Base Image is designed and engineered to be the base layer for all of your containerized applications, middleware and utilities. This base image is freely redistributable, but Red Hat only supports Red Hat technologies through subscriptions for Red Hat products. This image is maintained by Red Hat and updated regularly.

    Tags: base rhel8

    * An image stream tag will be created as "ubi:8.0" that will track the source image
    * A Docker build using source code from https://github.com/jvarela01/logging-demo will be created
      * The resulting image will be pushed to image stream tag "simple-apache:latest"
      * Every time "ubi:8.0" changes a new build will be triggered

--> Creating resources ...
    imagestream.image.openshift.io "ubi" created
    imagestream.image.openshift.io "simple-apache" created
    buildconfig.build.openshift.io "simple-apache" created
    deployment.apps "simple-apache" created
    service "simple-apache" created
--> Success
    Build scheduled, use 'oc logs -f buildconfig/simple-apache' to track its progress.
    Application is not exposed. You can expose services to the outside world by executing one or more of the commands below:
     'oc expose service/simple-apache' 
    Run 'oc status' to view your app.
```

Monitor the build process

```bash
$ oc logs -f bc/simple-apache -n logging-demo
Cloning "https://github.com/jvarela01/logging-demo" ...
	Commit:	3a817140c973bde4088ef3c9b3feade4b8ec737c (Updated Dockerfile)
	Author:	Jorge Varela <jvarela@redhat.com>
	Date:	Fri Jul 30 13:08:20 2021 -0500
Replaced Dockerfile FROM image registry.access.redhat.com/ubi8/ubi:8.0
Caching blobs under "/var/cache/blobs".

Pulling image registry.access.redhat.com/ubi8/ubi@sha256:8275e2ad7f458e329bdc8c0e7543cff1729998fe515a281d49638246de8e39ee ...
Getting image source signatures
Copying blob sha256:c65691897a4d140d441e2024ce086de996b1c4620832b90c973db81329577274
Copying blob sha256:641d7cc5cbc48a13c68806cf25d5bcf76ea2157c3181e1db4f5d0edae34954ac
Copying config sha256:11f9dba4d1bc7bbead64adb8fd73ea92dca5fac88a9b5c2c9796abcf2e97846d
Writing manifest to image destination
... skipped
Pushing image image-registry.openshift-image-registry.svc:5000/logging-demo/simple-apache:latest ...
Getting image source signatures
Copying blob sha256:4513190c599b3f9610b8d25bee9ba8ae462fa47b2e5520857e840fc39cdcdf99
Copying blob sha256:f18f7963b05b6f4bbea9ca56421351b1c3362c81fae78e51222aba7ee5b9445a
Copying blob sha256:c65691897a4d140d441e2024ce086de996b1c4620832b90c973db81329577274
Copying blob sha256:641d7cc5cbc48a13c68806cf25d5bcf76ea2157c3181e1db4f5d0edae34954ac
Copying config sha256:e99133c22c8c2f34025088e6bd0e3cfcef47db0958b5cfd7d7a6127e3ab85ea9
Writing manifest to image destination
Storing signatures
Successfully pushed image-registry.openshift-image-registry.svc:5000/logging-demo/simple-apache@sha256:a0ce38cd4d0581a3061a2033d908aea4377e561a849c3e7b75c8a2b89cc279de
Push successful
```

Wait for pod on Running State

```bash
$ oc get pods -n logging-demo
NAME                            READY   STATUS      RESTARTS   AGE
simple-apache-1-build           0/1     Completed   0          3m26s
simple-apache-654f5fdf7-679h7   1/1     Running     0          2m55s
```

In a separated terminal, get and follow the pod logs

```bash
$ oc logs -f simple-apache-654f5fdf7-679h7 -n logging-demo
```

On one more terminal, follow the access_log generated by simple-apache container
```bash
$ oc rsh -n logging-demo simple-apache-654f5fdf7-679h7 tail -f /var/log/httpd/access_log
```

Create a route for the simple-apache service

```bash
$ oc expose service simple-apache -n logging-demo
route.route.openshift.io/simple-apache exposed
```

Test the application a few times and validate the output from log pod and access_log on container

```bash
$ for i in $(seq 1 5)
> do
> curl $(oc get route simple-apache -o jsonpath='{.spec.host}' -n logging-demo)
> done
<html>
  <head>
    <title>Hola Mundo Apache OCP</title>
  </head>
  <body>
    <center>
      <h1>Hola Mundo Apache OCP</h1>
    </center>
  </body>
</html>
(x5)

####Pod Log Output (Empty)
$ oc logs -f simple-apache-654f5fdf7-679h7 -n logging-demo

####File var/log/httpd/access_log file on Container simple-apache Output
$ oc rsh -n logging-demo simple-apache-654f5fdf7-679h7 tail -f /var/log/httpd/access_log
10.128.2.18 - - [30/Jul/2021:20:03:07 +0000] "GET / HTTP/1.1" 200 158 "-" "curl/7.76.1"
10.129.2.6 - - [30/Jul/2021:20:04:53 +0000] "GET / HTTP/1.1" 200 158 "-" "curl/7.76.1"
10.129.2.6 - - [30/Jul/2021:20:04:53 +0000] "GET / HTTP/1.1" 200 158 "-" "curl/7.76.1"
10.129.2.6 - - [30/Jul/2021:20:04:54 +0000] "GET / HTTP/1.1" 200 158 "-" "curl/7.76.1"
10.128.2.18 - - [30/Jul/2021:20:04:54 +0000] "GET / HTTP/1.1" 200 158 "-" "curl/7.76.1"
```

Close the two additional terminals.

Confirm in the OpenShift Kibana GUI that the logs have not been captured yet

![No Register Logs On Kibana](https://raw.githubusercontent.com/jvarela01/logging-demo/main/images/kibana-no-logs.png)

Generate apache-logs empty dir volume for simple-apache deployment mounted on /var/log/httpd dir.

```bash
$ oc set volumes deployment/simple-apache --add --type emptyDir --mount-path /var/log/httpd --name apache-logs -n logging-demo
deployment.apps/simple-apache volume updated
```

Edit simple-apache deployment and add apache-log-sidecar sidecar container wich print the access_log file to stdout with the tail command. Add this lines to containers section:


```bash
$ oc edit deployment simple-apache -n logging-demo

...skipped
    spec:
      containers:
      - image: registry.access.redhat.com/ubi8/ubi:8.0
        name: apache-log-sidecar
        command:
        - /bin/bash
        - -c
        - tail -f /var/log/httpd/access_log
        volumeMounts:
        - mountPath: /var/log/httpd
          name: apache-logs
...skipped

deployment.apps/simple-apache edited
```

Wait for pod on Running state, note that the pod already has 2 containers.

```bash
$ oc get pods -n logging-demo
NAME                             READY   STATUS      RESTARTS   AGE
simple-apache-1-build            0/1     Completed   0          2d20h
simple-apache-7d7f4847df-c79xr   2/2     Running     1          2m5s
```

In a separated terminal, get and follow apache-log-sidecar container on apache-log-sidecar pod logs

```bash
$ oc logs -f simple-apache-7d7f4847df-c79xr -c apache-log-sidecar -n logging-demo
```

Test the application a few times and validate the output from log pod and access_log on container

```bash
$ for i in $(seq 1 5)
> do
> curl $(oc get route simple-apache -o jsonpath='{.spec.host}' -n logging-demo)
> done
<html>
  <head>
    <title>Hola Mundo Apache OCP</title>
  </head>
  <body>
    <center>
      <h1>Hola Mundo Apache OCP</h1>
    </center>
  </body>
</html>
(x5)

####Container apache-log-sidecar log output
$ oc logs -f simple-apache-7d7f4847df-c79xr -c apache-log-sidecar -n logging-demo
10.128.2.18 - - [02/Aug/2021:16:18:15 +0000] "GET / HTTP/1.1" 200 158 "-" "curl/7.76.1"
10.129.2.6 - - [02/Aug/2021:16:18:17 +0000] "GET / HTTP/1.1" 200 158 "-" "curl/7.76.1"
10.129.2.6 - - [02/Aug/2021:16:18:18 +0000] "GET / HTTP/1.1" 200 158 "-" "curl/7.76.1"
10.128.2.18 - - [02/Aug/2021:16:18:19 +0000] "GET / HTTP/1.1" 200 158 "-" "curl/7.76.1"
10.129.2.6 - - [02/Aug/2021:16:18:21 +0000] "GET / HTTP/1.1" 200 158 "-" "curl/7.76.1"
```

Close the aditional terminal

Validate the captured logs on OpenShift Kibana GUI

![No Register Logs On Kibana](https://raw.githubusercontent.com/jvarela01/logging-demo/main/images/kibana-sidecar.png)