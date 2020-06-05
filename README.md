

## I. - Testing

Access an existing RHEL host with an active entitlement and copy down these files… or generate a new host with an active entitlement and use its cert/key .pem files.

/etc/rhsm/rhsm.conf \
/etc/pki/entitlement/35759179968490-key.pem \
/etc/pki/entitlement/35759179968490.pem

Create the secret and configmaps

`oc create configmap rhsm-conf --from-file rhsm.conf` \
`oc -n test create secret generic etc-pki-entitlement --from-file 35759179968490-key.pem --from-file 35759179968490.pem`

Modify the Dockerfile to use these entitlements:
```
USER root
### OCP4 ENTITLEMENTS
COPY ./etc-pki-entitlement /etc/pki/entitlement
COPY ./rhsm-conf /etc/rhsm
COPY ./rhsm-ca /etc/rhsm/ca
# Delete /etc/rhsm-host to use entitlements from the build container
RUN rm /etc/rhsm-host
```

## II. - MachineConfig

If the build test is successful, create a MachineConfig instead of secrets/configmaps so any worker node / job can use these resources. _*this helps with migrations of workloads from OCP 3.11 (RHEL) to OCP 4.x (RHCOS)_.

Encode these 3 files…

`base64 -w0 rhsm.conf > rhsm.64` \
`base64 -w0 35759179968490-key.pem > 35759179968490-key.64` \
`base64 -w0 35759179968490.pem > 35759179968490.64`

Use these base64 values as inputs in your MachineConfig

```
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 99-rhsm-conf
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,<ENCODED_VALUE>
        filesystem: root
        mode: 0644
        path: /etc/rhsm/rhsm.conf

---
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 99-entitlement-pem
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,<ENCODED_VALUE>
        filesystem: root
        mode: 0644
        path: /etc/pki/entitlement/entitlement.pem


--- 
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: worker
  name: 99-entitlement-key-pem
spec:
  config:
    ignition:
      version: 2.2.0
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,<ENCODED_VALUE>
        filesystem: root
        mode: 0644
        path: /etc/pki/entitlement/entitlement-key.pem
```

