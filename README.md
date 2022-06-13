## Helm charts

Kerberos.io ecosystem can be deployed through Helm charts. Use one of the following charts to boost the installation:

- [Hub](https://github.com/kerberos-io/helm-charts/tree/main/charts/hub) chart

## Prerequisite

[Helm](https://helm.sh) must be installed to use the charts. Please refer to Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

    helm repo add kerberos https://charts.kerberos.io

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages. You can then run `helm search repo kerberos` to see the charts.

To install the `kerberos` chart:

    helm install my-hub kerberos/hub

To uninstall the chart:

    helm delete my-hub
