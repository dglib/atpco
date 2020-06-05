###### Note: Customers of Red Hat OCP generally receive subs for RHEL, these may be used for buildconfigs on the platform.

## I Testing

Access an existing RHEL host with an active entitlement and copy down these files or generate a new host with an active entitlement and use its cert/key .pem files.

/etc/rhsm/rhsm.conf \
/etc/pki/entitlement/35759179968490-key.pem \
/etc/pki/entitlement/35759179968490.pem

1. Create a test namespace \
` oc create ns test `

2. Create the secret and configmaps \
`oc -n test create configmap rhsm-conf --from-file rhsm.conf` \
`oc -n test create secret generic etc-pki-entitlement --from-file 35759179968490-key.pem --from-file 35759179968490.pem`

3. For this test, create a pull-secret with your registry.redhat.io account credentials stored \
` oc -n test create secret docker-registry redhat-registry --docker-server=registry.redhat.io --docker-username=<YOURUSERNAME> --docker-password=<YOURPASSWORD> --docker-email=<YOUREMAIL> `

4. Install the ImageStream; I'm doing this in the `test` namespace, but you can easily install it in the `openshift` namespace to provide global access. \
` oc -n test create -f is-openjre18-171.yaml `

5. Install the BuildConfig \
` oc -n test create -f openjre18-171-build-config.yaml `

6. Modify the Dockerfile to use these entitlements:
    ```
    USER root
    ### OCP4 ENTITLEMENTS
    COPY ./etc-pki-entitlement /etc/pki/entitlement
    COPY ./rhsm-conf /etc/rhsm
    COPY ./rhsm-ca /etc/rhsm/ca
    # Delete /etc/rhsm-host to use entitlements from the build container
    RUN rm /etc/rhsm-host
    ```

7. Run the test from a local directory uploading the Dockerfile \
` oc start-build openjre18-171 --from-dir=. --follow `

## II MachineConfig

If the build test is successful, create a MachineConfig instead of secrets/configmaps so any worker node / job can use these resources. _*this helps with migrations of workloads from OCP 3.11 (RHEL) to OCP 4.x (RHCOS)_.

1. Encode these 3 files \
`base64 -w0 rhsm.conf > rhsm.64` \
`base64 -w0 35759179968490-key.pem > 35759179968490-key.64` \
`base64 -w0 35759179968490.pem > 35759179968490.64`

2. Use these base64 `ENCODED_VALUE`'s as inputs in your MachineConfig below 
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
##### _NOTE: Adding these MachineConfigs will cause the worker nodes to recycle; although workloads should be configured for HA, it is recommened to perform these during a maintenance window._

3. Remove the Dockerfile modifcations from the above test
    ```
    USER root
    ### OCP4 ENTITLEMENTS
    # REMOVE # COPY ./etc-pki-entitlement /etc/pki/entitlement
    # REMOVE # COPY ./rhsm-conf /etc/rhsm
    # REMOVE # COPY ./rhsm-ca /etc/rhsm/ca
    # REMOVE # Delete /etc/rhsm-host to use entitlements from the build container
    # REMOVE # RUN rm /etc/rhsm-host
    ```
4. Remove the ConfigMap and Secret from the above test
` oc -n test delete secret etc-pki-entitlement `
` oc -n test delete configmap rhsm-conf `

5. If you accidently removed the redhat-registry secret, this BuildConfig requires it, let's put it back \
` oc -n test create secret docker-registry redhat-registry --docker-server=registry.redhat.io --docker-username=<YOURUSERNAME> --docker-password=<YOURPASSWORD> --docker-email=<YOUREMAIL> `

6. Run your test using the MachineConfigs \
` oc start-build openjre18-171 --from-dir=. --follow `