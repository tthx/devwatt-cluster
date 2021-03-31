#!/bin/sh
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.1.0/deploy/longhorn.yaml && \
longhorn_user='longhorn-basic'; \
longhorn_passwd='D@$#H0le99*'; \
echo "${longhorn_user}:$(openssl passwd -stdin -apr1 <<< ${longhorn_passwd})" > auth && \
kubectl -n longhorn-system create secret generic basic-auth --from-file=auth && 
rm -f auth && \
echo "
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: longhorn-ingress
  namespace: longhorn-system
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    # type of authentication
    nginx.ingress.kubernetes.io/auth-type: basic
    # prevent the controller from redirecting (308) to HTTPS
    nginx.ingress.kubernetes.io/ssl-redirect: 'false'
    # name of the secret that contains the user/password definitions
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    # message to display with an appropriate context why the authentication is required
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required '
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: longhorn-frontend
            port:
              number: 80
" | kubectl -n longhorn-system create -f -