# About Security in Kubernetes

## Purpose

Goal of this project is to build a Kubernetes cluster using the [kubeadm](https://kubernetes.io/fr/docs/reference/setup-tools/kubeadm/) command, with a focus on security.

## Sources

Git repository: [k8s-by-kubeadm](https://gitlab.tech.orange/fams/k8s-by-kubeadm)

## Requirements

- [**Ubuntu Server**](https://ubuntu.com/download/server) 20.04.2,
- [**OpenSSH**](https://www.openssh.com/) 8.2p1,
- [**OpenSSL**](https://www.openssl.org/) 1.1.1f,
- [**chrony**](https://chrony.tuxfamily.org/) 3.5, as time server, with setting a cluster node (the [control plane](https://kubernetes.io/docs/concepts/overview/components/)) as a time server,
- [**haveged**](https://www.issihosts.com/haveged/) 1.9.1, as pseudo random generator, mainly for cryptography operations. As we generate certificates and massively use TLS for communicating inside and outside a Kubernetes cluster, to avoid entropy pools run dry is critical, specially on a virtual machine: [How to Setup Additional Entropy for Cloud Servers Using Haveged](https://www.digitalocean.com/community/tutorials/how-to-setup-additional-entropy-for-cloud-servers-using-haveged) or [Entropy in RHEL based cloud instances](https://developers.redhat.com/blog/2017/10/05/entropy-rhel-based-cloud-instances#).
- [**docker**](https://www.docker.com/) 20.10.6, as container runtime.
- You should have a Linux user account with root privilege on all nodes in the Kubernetes cluster to build,
- You should have a Linux user account with SSH access on all nodes in the Kubernetes cluster to build.

We use OpenSSH, OpenSSL, chrony, haveged and docker packages provided with Ubuntu distribution. We provide scripts to install and configure chrony, haveged and docker, and scripts to configure some Linux OS elements.

## Building a Kubernetes cluster

We provide following scripts:

- [`k8s-install.sh`](https://gitlab.tech.orange/fams/k8s-by-kubeadm/blob/master/k8s-install.sh), to install and configure previous required Ubuntu packages,
- [`k8s-init.sh`](https://gitlab.tech.orange/fams/k8s-by-kubeadm/blob/master/k8s-init.sh), to build a Kubernetes cluster,
- [`k8s-reset.sh`](https://gitlab.tech.orange/fams/k8s-by-kubeadm/blob/master/k8s-reset.sh), to delete the built Kubernetes cluster.

Parameters of the previous scripts are set in [`k8s-env.sh`](https://gitlab.tech.orange/fams/k8s-by-kubeadm/blob/master/k8s-env.sh). Supported parameters are:

|Name|Description|Format|Default|
|----|-----------|------|-------|
|`SUDO_USER`|SSH user used to connect to all nodes of the Kubernetes cluster to build.|String|`ubuntu`|
|`SSH_OPTS`|SSH mandatory parameters for `SUDO_USER` used to connect to all nodes of the Kubernetes cluster to build.|String<br><br>e.g. `-i ${HOME}/.ssh/id_rsa`|Empty string|
|`CTRL_PLANE`|DNS, IP or alias of the node designated as the Control Plane.|String|`master`|
|`WORKERS`|DNS, IP or alias of the nodes designated as worker nodes.|List of string, separated by spaces|`worker-1 worker-2 worker-3 worker-4`|
|`CLUSTER_NAME`|Name of the Kubernetes cluster to build.<br><br>`CLUSTER_NAME` is used as the common name of the root certificate authority for all other certificate authorities of a Kubernetes cluster (e.g. `kubernetes-ca`, `etcd-ca`, etc). The common name of the root certificate authority is constructed with string before the `-` character, if it exist, in `CLUSTER_NAME` and appended with `-ca`: e.g. the common name of the root certificate authority for `ghost-0` is `ghost-ca`. |String|`ghost-0`|
|`K8S_DOCKER_IMAGE_REPO`|Docker images repository to use for Kubernetes.|String|`k8s.gcr.io`|
|`CALICO_DOCKER_IMAGE_REPO`|Docker images repository to use for [Calico](https://www.projectcalico.org/).|String|`dockerfactory-playground.tech.orange`|
|`METRICS_SERVER_DOCKER_IMAGE_REPO`|Docker images repository to use for [Kubernetes Metrics Server](https://github.com/kubernetes-sigs/metrics-server).|String|`dockerfactory-playground.tech.orange`|
|`NET_INTERFACE`|Network interface name to use on nodes assigned to the Kubernetes cluster to build.|String|`ens3`|
|`K8S_CONF_DIR`|Directory where configuration files of Kubernetes cluster to build will be stored.|String|`/etc/kubernetes`|
|`K8S_PKI_DIR`|Directory where PKI materials (e.g. certificates, keys) of Kubernetes cluster to build will be stored.|String|`${K8S_CONF_DIR}/pki`|
|`POD_CIDR`|Specify range of IP addresses for the pod network. The control plane will automatically allocate CIDRs for every node. Take care that your Pod network must not overlap with any of the node networks|CIDR|`172.18.0.0/16`|
|`SRV_CIDR`|A CIDR notation IP range from which to assign service cluster IPs. This must not overlap with any IP ranges assigned to nodes or pods.|CIDR|`172.19.0.0/16`|
|`TLS_MIN_VERSION`|TLS protocol's version. Read [TLS Best Practices](#tls-best-practices) for details. Supported values: `VersionTLS12` and `VersionTLS13`.|String|`VersionTLS13`|
|`CIPHERS_SUITE_TLS12`|Cipher suites used with TLS v1.2. Read [TLS Best Practices](#tls-best-practices) for details.|String|`TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384`|
|`CIPHERS_SUITE_TLS13`|Cipher suites used with TLS v1.3. Read [TLS Best Practices](#tls-best-practices) for details.|String|`TLS_AES_128_GCM_SHA256,TLS_AES_256_GCM_SHA384,TLS_CHACHA20_POLY1305_SHA256`|
|`KEY_TYPE`|Type of certificate. Supported values: `ecdsa` and `rsa`.|String|`ecdsa`|
|`ECDSA_CA_KEY_CURVE`|The elliptic curve used to generate a certificate authority key. As we use `openssl` to manage certificates, supported elliptic curves are display with the command: `openssl ecparam -list_curves`. **Note**: You must use elliptic curves supported by the host  where you generate certificates **and** by Kubernetes. But we have no information, yet, on this point by Kubernetes...|String|`secp384r1`|
|`ECDSA_KEY_CURVE`|The elliptic curve used to generate a certificate key.|String|`prime256v1`|
|`RSA_CA_KEY_LENGTH`|RSA certificate authorities key length, in bit.|Integer|`4096`|
|`RSA_KEY_LENGTH`|RSA certificates key length, in bit.|Integer|`2048`|
|`CERT_DURATION`|Certificates duration, in days.|Integer|`365`|
|`CA_CERT_DURATION_FACTOR`|Used to set certificate authorities duration: it's the result of `CERT_DURATION*CA_CERT_DURATION_FACTOR`|Integer|`1000`|

## Audience

This document attempts to avoid paraphrasing the [Kubernetes documents](https://kubernetes.io/docs/reference/). At first we provide the Kubernetes references about a studied subject, then we provide focus on points of interest. We strongly encourage our readers to first consult the cited references and then only to read our remarks, comments and critiques.

## Generalities

### References

- [Security](https://kubernetes.io/docs/concepts/security/)
- [Securing a Cluster](https://kubernetes.io/docs/tasks/administer-cluster/securing-a-cluster/)

Securing hardware and software used by Kubernetes is critical but is out of the scope of this document. We limit this document to Kubernetes core components:

- [etcd](https://etcd.io/),
- [kube-apiserver](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/),
- [kube-scheduler](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-scheduler/),
- [kube-controller-manager](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/),
- [kubelet](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/).

We should provide another recommendations document for applications deployed in a Kubernetes cluster.

To be up-to-date about security vulnerabilities:

- [CVE](https://cve.mitre.org/about/index.html)
  > The mission of the CVE Program is to identify, define, and catalog publicly disclosed cybersecurity [vulnerabilities](https://cve.mitre.org/about/terminology.html#vulnerability).
- [Kubernetes bug bounty program](https://hackerone.com/kubernetes).
- [kubernetes-announce](https://groups.google.com/g/kubernetes-announce)
  > Announcements regarding [Kubernetes](http://kubernetes.io/). Subscribe if you want to be aware of major developments, including significant changes to the latest source on [github](https://github.com/kubernetes/kubernetes).

## Authenticating

### References

- [Authenticating](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)

We would like to emphasize that Kubernetes applies its authentication and authorization model only to connections to [Kubernetes components](https://kubernetes.io/docs/concepts/overview/components/): there is no way with Kubernetes API to model identity neither permissions of an user of an application deployed in Kubernetes: management of authentication and authorization of connections to deployed applications are dedicated to them.

### Anonymous access

#### References

- [Anonymous requests](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#anonymous-requests),
- [Kubelet authentication/authorization](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet-authentication-authorization/),
- [Controlling Access to the Kubernetes API](https://kubernetes.io/docs/concepts/security/controlling-access/)

We should disable anonymous access at least in production environment to forbid unwanted access. But some tasks require anonymous access, e.g. [TLS bootstrapping](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet-tls-bootstrapping/).

### Secrets

#### References

- [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/),
- [Encrypting Secret Data at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/).

### Service Accounts

#### References

- [Managing Service Accounts](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/)

## TLS

### References

- [SSL/TLS Best Practices for 2021](https://www.ssl.com/guide/ssl-best-practices/),
- [Guide to TLS Standards Compliance](https://www.ssl.com/guide/tls-standards-compliance/),
- [SSL and TLS Deployment Best Practices](https://github.com/ssllabs/research/wiki/SSL-and-TLS-Deployment-Best-Practices),
- [Security/Server Side TLS](https://wiki.mozilla.org/Security/Server_Side_TLS).

As Kubernetes use TLS to secure communications inside and outside a Kubernetes cluster, we should ensure to follow TLS best practices. We also separate two security levels requirement:

- Communications with Kubernetes core components. As a corruption of one of these components could compromise the entire cluster, we should level up the TLS security at his top,
- Communications without Kubernetes core components. The level of security of applications deployed in a Kubernetes cluster should be left to the discretion of the projects of those applications, if and only if they do not communicate with a Kubernetes core component. Obviously, it would be appreciated if the deployed applications follow TLS best practices...

### TLS Best Practices

- Certificates are keys points in TLS: we dedicate the [Certificates Management](#certificates-management) section for certificates best practices,
- Protocol version:

  - **TLS v1.3** should be set for:

    - etcd. But etcd provides no way to set the TLS protocol and imposes limitations on the ciphers to be used,
    - kube-apiserver,
    - kube-scheduler,
    - kube-controller-manager,
    - kubelet.

      **Note**:
      > Benefits of using TLS v1.3:
      >  - Improved performance i.e improved latency
      >  - Improved security
      >  - Removed obsolete/insecure features like cipher suites, compression etc.

- Ciphers for kube-apiserver, kube-scheduler, kube-controller-manager and kubelet are:

  - `TLS_AES_128_GCM_SHA256`,
  - `TLS_AES_256_GCM_SHA384`,
  - `TLS_CHACHA20_POLY1305_SHA256`,
  - `TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256`,
  - `TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256`,
  - `TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384`,
  - `TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384`.

We use Mozilla's recommanded TLS v1.2 and v1.3 ciphers because etcd limitations: The etcd shipped with Kubernetes 1.21.3 (the latest version at the time we write) is 3.4.13 compiled with go 1.12.17:

```
$ /var/lib/docker/overlay2/.../merged/usr/local/bin/etcd --version
etcd Version: 3.4.13
Git SHA: ae9734ed2
Go Version: go1.12.17
Go OS/Arch: linux/amd64
```

etcd use by default TLS v1.2. In go 1.12, TLS v1.3 is available but is not activated by default: [Go 1.12 Release Notes](https://golang.org/doc/go1.12#tls_1_3). Despite applying procedure to activate TLS v1.3 (i.e. we add the environment variable `GODEBUG` with `tls13=1` in etcd's manifest), etcd don't work with Mozilla's recommanded ciphers for TLS v1.3. So etcd's TLS version is 1.2 and etcd's ciphers are Mozilla's recommanded ciphers for TLS v1.2:

- `TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256`,
- `TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256`,
- `TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384`,
- `TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384`.

**Note**: At the time we write, the Kubernetes version is:

```
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"21", GitVersion:"v1.21.3", GitCommit:"ca643a4d1f7bfe34773c74f79527be4afd95bf39", GitTreeState:"clean", BuildDate:"2021-07-15T21:04:39Z", GoVersion:"go1.16.6", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"21", GitVersion:"v1.21.3", GitCommit:"ca643a4d1f7bfe34773c74f79527be4afd95bf39", GitTreeState:"clean", BuildDate:"2021-07-15T20:59:07Z", GoVersion:"go1.16.6", Compiler:"gc", Platform:"linux/amd64"}
```

### Certificates Management

#### Creation

##### References

- [PKI certificates and requirements](https://kubernetes.io/docs/setup/best-practices/certificates/),
- [ECDSA: The digital signature algorithm of a better internet](https://blog.cloudflare.com/ecdsa-the-digital-signature-algorithm-of-a-better-internet/),
- [SafeCurves: choosing safe curves for elliptic-curve cryptography](http://safecurves.cr.yp.to/),
- [Keylength - Cryptographic Key Length Recommendation](https://www.keylength.com/en/).

By default, `kubeadm` generate and manage RSA certificates. We can't set neither certificate's key size nor duration. This is a minor security issue because it is relatively easy to renew certificates in Kubernetes. But this is not the case for certificates authorities. However, CAs are the key points of the TLS protocol...

Certificates created by `kubeadm` are RSA 2048 bit.

At the time we write, the latest `kubeadm` can generate ECDSA certificates using `prime256v1` elliptic curve.

#### Rotation

##### References

- [Certificate Management with kubeadm](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/).

##### Certificate Authorities

###### References

- [Manual Rotation of CA Certificates](https://kubernetes.io/docs/tasks/tls/manual-rotation-of-ca-certificates/).

As any request to a Kubernetes component that presents a valid certificate signed by a Kubernetes cluster's certificate authority (CA) is considered authenticated, CA is a key point in the Kubernetes security scheme.

##### Certificate

###### References

- [Configure Certificate Rotation for the Kubelet](https://kubernetes.io/docs/tasks/tls/certificate-rotation/)
- [Certificate Signing Requests](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/),
- [TLS bootstrapping](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet-tls-bootstrapping/)

### Checking TLS settings

[Specifying TLS ciphers for etcd and Kubernetes](https://www.ibm.com/docs/en/cloud-private/3.2.x?topic=installation-specifying-tls-ciphers-etcd-kubernetes)

## Authorization

### References

- [Authorization Overview](https://kubernetes.io/docs/reference/access-authn-authz/authorization/)

### Role-Based Access Control (RBAC)

#### References

- [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
