# Kerberos Hub

Kerberos Hub is the single pane of glass for your Agents. It comes with a best of breed open source technology stack, modular and scale first mindset, and allows you to build and maintain an everless growing video surveillance and video analytics landscape.

![Kerberos Hub Interface](assets/images/hub-dashboard.png)

## License

To use Kerberos Hub a license is required. This license will grant access the Kerberos Hub API, and allow to connect a number of cameras and Kerberos Vaults.

## Add helm repos

The Kerberos Hub installation makes use of this Helm chart. Therefore, we will add those repos to our Kubernetes cluster.

    helm repo add kerberos https://charts.kerberos.io
    helm repo update

## Prerequisites

Go and follow the Kerberos Hub installation at the [hub repository](https://github.com/kerberos-io/hub). Once you have [installed all prerequisites](https://github.com/kerberos-io/helm-charts/tree/main/charts/hub#lets-give-it-a-try) come back here.

## Kerberos Hub

So once you hit this step, you should have installed all required dependencies. Hopefully you didn't had too much pain with the certificates. Before starting, it's important to have a look at the `values.yaml` file. This includes the different parameters to configure the different deployments. Reach out to us if you would need any help with this.

Install the Kerberos Hub chart in a specific namespace and take into the values.yaml file.

    helm install hub kerberos/hub --values values.yaml -n kerberos-hub --create-namespace

Uninstall the Kerberos Hub chart

    helm uninstall hub -n kerberos-hub

### Parameters

Below all configuration options and parameters are listed.

| Name                                        | Description                                                                                                                | Value |
| ------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ----- |
| `license` | The license key you received from support@kerberos.io. If not available request one. | `"L/+DAwEBB2xpY2Vuc2UB/4QAAQIBB1BheWxvYWQBCgABCVNpZ25hdHVyZQEKAAAA/gMk/4QB/gEZ/8sQACxnaXRodWIuY29tL3V1Zy1haS9odWItbGljZW5zZS9tb2RlbHMuTGljZW5zZX8DAQEHTGljZW5zZQH/gAABDAECSWQB/4IAAQNLZXkBDAABB0NvbXBhbnkBDAABB0V4cFRpbWUBBAABBERheXMBBAABB0NhbWVyYXMBBAABBVNpdGVzAQQAAQZWYXVsdHMBBAABCk1lZGlhTGltaXQBBAABCVBlcnBldHVhbAECAAEGQWN0aXZlAQIAAQlJcEFkZHJlc3MBDAAAABj/gQEBAQhPYmplY3RJRAH/ggABBgEYAAAy/4AvAQwAAAAAAAAAAAAAAAACDGZyZWUtbGljZW5zZQH81iZi6gH+AtoBEAEUARQDAQAB/gIAfeXxQb6kaPfAgOWeSAE6qEiQviFD6sciNmNfMel1mEL53FeV0GQe4cYBip9wyJag35az8A1yppxSymZD5V4my2FckyN2zmEW4E2sO/v+8eKepiAGYEzrKtfNCLxdWLmrHd0zjYQ3qk+PNfoPyzCOefeulw3aFsqBlzg9wDkF8cRx6tUW0qNTzki6sFGOuLoxS49cWqsftAvZmt+CRWa8u0VArIAjOpywN0RIZCkEYzp5RYF3LSVyWYEyvVhjE19DDnevzpJyCHRsIHTRcpTQkhboeapOdlEz8cx+PaOvxktN8hBWceTAH+nw96FARG7y6Cpjw3xo+NV1xb0tvRXGaGoK77JnErKLhd/haXji98rGvMakDt18WSbQfTVS84+Fw+/gKGsW3uS3fROAaZw1kZj4PgsEPZDvbVkCVyuS0O87UoYqpxH8S4by8cTF3wDP7FwyIRZbEbYjN2wzHSmlADYOBtdsdb1VGm7wvtB85vML9n7ZSlIpJdqfci06mGks102mDyG2LRMhUEvpUW3D/weErIvj2WiAwf6r0EUj+LO8VmAsYkME9da7FXEN6Vg/5f1u485LOpYki332RaDOhDn2eMG9DVb/HnmQSFagX+XXc/QwfsWiehCgKYGk4jQpyklTqoGu8BAt6Sm8CaoH8ngZ3cHLQT5DcZElV36/N/wA"` |
| `licenseServer.url` | The license server for validating the license of your Kerberos Hub, by default `'"https://license.kerberos.io/verify"'`. | `""` |
| `licenseServer.token` | The license server API token to sign the license validation by default `'214%ˆ#ddfsf@#3rfdsgl_)23sffeqasSwefDSFNBM'`. | `""` |
| `environment` | A colored banner will be shown on top of the application to illustrate a non-production environment: `staging`, `demo`, .. | `"production"` |
| `isPrivate` | Global StorageClass for Persistent Volume(s) | `true` |
| `readOnly` | This will stop any write process to mongodb or any processing done in the Kerberos Hub pipeline. | `false` |
| `mode` | Deployment mode: `all`, `pipeline`, or `ui`. `all` renders everything, `pipeline` only pipeline services, `ui` only hub services. | `"all"` |
| `global.imageRegistry` | Global container registry override used for all images. | `""` |
| `ingress` | The ingress being used for `kerberoshub.api.url` and `kerberoshub.frontend.url`. | `"nginx"` |
| `mongodb.host` | MongoDB hostname (`'mongodb:27017'`) or mongodb replicas (`'mongodb-0:27017,mongodb-1:27017'`). | `"mongodb.mongodb"` |
| `mongodb.adminDatabase` | MongoDB admin database, this is named `admin` by default. | `"admin"` |
| `mongodb.authenticationMechanism` | MongoDB authentication mechanism (for example `SCRAM-SHA-256`). | `"SCRAM-SHA-256"` |
| `mongodb.username` | MongoDB user account, we are using in the hub installation `'root'`. | `"yourusername"` |
| `mongodb.password` | MongoDB user password, by default `'yourmongodbpassword'` | `"yourpassword"` |
| `mongodb.retryWrites` | Enable or disable MongoDB retryable writes. | `"true"` |
| `mongodb.flavor` | Backend engine flavor: `"mongodb"` (native MongoDB / Atlas) or `"documentdb"` (AWS DocumentDB). The `documentdb` flavor disables features DocumentDB does not support (geospatial queries/indexes, complex `$lookup` pipelines). When set to `documentdb`, also set `mongodb.retryWrites: "false"`. | `"mongodb"` |
| `mqtt.host` | MQTT (Vernemq) hostname. | `"mqtt.yourdomain.com"` |
| `mqtt.port` | MQTT (Vernemq) port for WSS (secure sockets), by default `'8443'`. | `"8443"` |
| `mqtt.protocol` | MQTT (Vernemq) protocol, by default `'wss'`. | `"wss"` |
| `mqtt.username` | MQTT (Vernemq) username, by default `'yourusername'`. | `"yourusername"` |
| `mqtt.password` | MQTT (Vernemq) password, by default `'yourpassword'`. | `"yourpassword"` |
| `mqtt.legacy.host` | Legacy MQTT broker host used for backward-compatible clients. | `""` |
| `mqtt.legacy.port` | Legacy MQTT broker port used for backward-compatible clients. | `""` |
| `queueProvider` | The queue we are using for the [pipeline](https://doc.kerberos.io/hub/pipeline/): 'SQS', 'KAFKA' or `RABBITMQ`. | `"RABBITMQ"` |
| `queueName` | The event queue which is propagating messages in the [Kerberos Hub pipeline](https://doc.kerberos.io/hub/pipeline/). | `"kcloud-event-queue"` |
| `rabbitmq.host` | RabbitMQ host, by default `'rabbitmq.yourdomain.com:5671'` | `"rabbitmq.rabbitmq:5672"` |
| `rabbitmq.username` | RabbitMQ username, by default `'yourusername'` | `"yourusername"` |
| `rabbitmq.password` | RabbitMQ password, by default `'yourpassword'` | `"yourpassword"` |
| `rabbitmq.exchange` | RabbitMQ exchange, by default `''` | `""` |
| `kafka.broker` | Kafka brokers, by default `'kafka1.yourdomain.com:9094,kafka2.yourdomain.com:9094'` | `"kafka1.yourdomain.com:9094"` |
| `kafka.username` | Kafka username, by default `'yourusername'` | `"yourusername"` |
| `kafka.password` | Kafka password, by default `'yourpassword'` | `"yourpassword"` |
| `kafka.mechanism` | Kafka mechanism, by default `'PLAIN'` | `"PLAIN"` |
| `kafka.security` | Kafka security, by default `'SASL_PLAINTEXT'` | `"SASL_PLAINTEXT"` |
| `turn.host` | TURN/STUN hostname, by default `'turn:turn.yourdomain.com:8443'` | `"turn:turn.yourdomain.com:8443"` |
| `turn.username` | TURN/STUN username, by default `'username1'` | `"username1"` |
| `turn.password` | TURN/STUN password, by default `'password1'` | `"password1"` |
| `opentelemetry.enabled` | Enable or disable OpenTelemetry instrumentation. | `false` |
| `opentelemetry.routingEnabled` | Enable or disable OpenTelemetry routing/export behavior. | `false` |
| `opentelemetry.collector.endpoint` | OpenTelemetry collector endpoint used for trace export. | `"http://otel-collector:4317"` |
| `openai.enabled` | Enable or disable OpenAI-backed semantic features. | `false` |
| `openai.apikey` | OpenAI API key used when OpenAI integration is enabled. | `"xxx"` |
| `kerberosvault.uri` | The default Kerberos Vault uri (you can add multiple within the app), by default `'https://api.storage.yourdomain.com'` | `"https://api.vault.yourdomain.com"` |
| `kerberosvault.provider` | The default Kerberos Vault provider`'a-provider'` | `"a-provider"` |
| `kerberosvault.accesskey` | The default Kerberos Vault access key, by default `'xxx'` | `"xxx"` |
| `kerberosvault.secretkey` | The default Kerberos Vault secret key, by default `'xxx'` | `"xxx"` |
| `kerberosvault.archive.provider` | When a task is created, the relevant recording is moved to this provider `'an-archive-provider'` | `"an-archive-provider"` |
| `kerberosvault.archive.accesskey` | When a task is created, the relevant recording is moved to another provider, using this access key `'xxx'` | `"xxx"` |
| `kerberosvault.archive.secretkey` | When a task is created, the relevant recording is moved to another provider, using this secret key`'xxx'` | `"xxx"` |
| `kerberosvault.thumbnail.provider` | Configuration value for `kerberosvault.thumbnail.provider`. | `"a-thumbnail-provider"` |
| `kerberosvault.thumbnail.accessKey` | Access key for `kerberosvault.thumbnail`. | `"xxx"` |
| `kerberosvault.thumbnail.secretKey` | Secret key for `kerberosvault.thumbnail`. | `"xxx"` |
| `kerberosvault.sprite.provider` | Configuration value for `kerberosvault.sprite.provider`. | `"a-sprite-provider"` |
| `kerberosvault.sprite.accessKey` | Access key for `kerberosvault.sprite`. | `"xxx"` |
| `kerberosvault.sprite.secretKey` | Secret key for `kerberosvault.sprite`. | `"xxx"` |
| `admin.repository` | Container image repository for `admin`. | `"uugai/admin"` |
| `admin.pullPolicy` | Image pull policy for `admin`. | `"IfNotPresent"` |
| `admin.tag` | Container image tag/version for `admin`. | `"v1.3.0"` |
| `admin.replicas` | Number of replicas for `admin`. | `2` |
| `admin.logLevel` | Log verbosity level for `admin`. | `"info"` |
| `admin.resources.requests.memory` | Memory request for `admin`. | `"100Mi"` |
| `admin.resources.requests.cpu` | CPU request for `admin`. | `"250m"` |
| `admin.url` | URL for `admin`. | `"admin.yourdomain.com"` |
| `admin.tls.secretName` | Kubernetes Secret name used by `admin.tls`. | `""` |
| `admin.oauth2Proxy.enabled` | Enable or disable `admin.oauth2Proxy`. | `false` |
| `admin.oauth2Proxy.github.clientId` | Client ID used by `admin.oauth2Proxy.github`. | `"github-client-id"` |
| `admin.oauth2Proxy.github.clientSecret` | Client secret used by `admin.oauth2Proxy.github`. | `"github-client-secret"` |
| `admin.oauth2Proxy.github.cookieSecret` | Cookie secret used by `admin.oauth2Proxy.github`. | `"generate-a-random-cookie-secret"` |
| `admin.oauth2Proxy.github.organization` | Organization value used by `admin.oauth2Proxy.github`. | `"github-organization"` |
| `admin.oauth2Proxy.github.team` | Team value used by `admin.oauth2Proxy.github`. | `"github-team"` |
| `kerberoshub.extraEnv` | Additional environment variables injected into Kerberos Hub pods. | `[]` |
| `kerberoshub.serviceAccount.create` | Create or manage `kerberoshub.serviceAccount` resources. | `false` |
| `kerberoshub.serviceAccount.name` | Name value for `kerberoshub.serviceAccount`. | `""` |
| `kerberoshub.serviceAccount.annotations` | Annotations applied to `kerberoshub.serviceAccount` resources. | `""` |
| `kerberoshub.serviceAccount.labels` | Labels applied to `kerberoshub.serviceAccount` resources. | `""` |
| `kerberoshub.api.repository` | The Docker registry where the Kerberos Hub API container is hosted. | `"ghcr.io/uug-ai/hub-api"` |
| `kerberoshub.api.pullPolicy` | The Docker registry pull policy. | `"IfNotPresent"` |
| `kerberoshub.api.tag` | The Docker image tag/version. | `"v1.9.8"` |
| `kerberoshub.api.replicas` | The number of pods/replicas running for the Kerberos Hub API deployment. | `2` |
| `kerberoshub.api.logLevel` | Log verbosity level for `kerberoshub.api`. | `"info"` |
| `kerberoshub.api.jwtSecret` | A secret that is for generating JWT tokens. | `"this-is-a-secret-please-change-to-random-string"` |
| `kerberoshub.api.schema` | The protocol to serve the Kerberos Hub API, `'http'` or `'https'`. | `"https"` |
| `kerberoshub.api.url` | The Kerberos Hub API ingress to access the API. | `"api.yourdomain.com"` |
| `kerberoshub.api.resources.requests.memory` | Memory request for `kerberoshub.api`. | `"100Mi"` |
| `kerberoshub.api.resources.requests.cpu` | CPU request for `kerberoshub.api`. | `"250m"` |
| `kerberoshub.api.resources.limits.memory` | Memory limit for `kerberoshub.api`. | `"100Mi"` |
| `kerberoshub.api.resources.limits.cpu` | CPU limit for `kerberoshub.api`. | `"250m"` |
| `kerberoshub.api.serverTLS.enabled` | Enable or disable `kerberoshub.api.serverTLS`. | `false` |
| `kerberoshub.api.serverTLS.secretName` | Kubernetes Secret name used by `kerberoshub.api.serverTLS`. | `""` |
| `kerberoshub.api.serverTLS.mountPath` | Filesystem path where the Hub API TLS secret is mounted. | `"/etc/hub-api/tls"` |
| `kerberoshub.api.serverTLS.certFile` | Path to the TLS certificate file used by Hub API server-side TLS. | `"/etc/hub-api/tls/tls.crt"` |
| `kerberoshub.api.serverTLS.keyFile` | Path to the TLS private key file used by Hub API server-side TLS. | `"/etc/hub-api/tls/tls.key"` |
| `kerberoshub.api.mfaIssuer` | When enabling the MFA access, this is the name that will be shown in the MFA app. | `"yourdomain.com"` |
| `kerberoshub.api.apiKey` | API key for `kerberoshub.api`. | `"a-random-admin-api-key"` |
| `kerberoshub.api.defaultTaskRetentionDays` | Default retention (in days) applied to tasks without an explicit `retention_days`. New tasks are stamped with this value. Set to `"0"` or a negative value to keep tasks indefinitely. Must match `kerberoshub.cleanup.defaultTaskRetentionDays`. | `"0"` |
| `kerberoshub.api.tls` | Bring your own TLS certificates for Kerberos Hub API ingress. | `<list>` |
| `kerberoshub.api.tls.secretName` | Kubernetes Secret name used by `kerberoshub.api.tls`. | `""` |
| `kerberoshub.api.language` | The language of Kerberos Hub API responses, error messages will be communicated in the specified language. | `"english"` |
| `kerberoshub.api.fallbackLanguage` | The fallback language, if a specific translation is not available. | `"english"` |
| `kerberoshub.api.aws.region` | AWS region used by the Hub API legacy S3 integration. | `"xxx"` |
| `kerberoshub.api.aws.bucket` | AWS S3 bucket used by the Hub API legacy S3 integration. | `"xxx"` |
| `kerberoshub.api.aws.accessKey` | Access key for `kerberoshub.api.aws`. | `"xxx"` |
| `kerberoshub.api.aws.secretKey` | Secret key for `kerberoshub.api.aws`. | `"xxx"` |
| `kerberoshub.api.stripe.privateKey` | Private key for `kerberoshub.api.stripe`. | `"xxx"` |
| `kerberoshub.api.slack.enabled` | Slack integration for sending events and notifications coming from the Kerberos Hub API, `'true'` or `'false'`. | `"true"` |
| `kerberoshub.api.slack.hook` | Slack integration hook url. | `"yourslackhook"` |
| `kerberoshub.api.slack.username` | Slack integration username. | `"Kerberos Hub"` |
| `kerberoshub.api.elasticsearch.enabled` | Elasticsearch for storing events coming from the Kerberos Hub API, `'true'` or `'false'` | `"false"` |
| `kerberoshub.api.elasticsearch.protocol` | Elasticsearch protocol, `'http'` or `'https'`. | `"http"` |
| `kerberoshub.api.elasticsearch.host` | Elasticsearch host. | `"yourelasticsearchinstance.com"` |
| `kerberoshub.api.elasticsearch.port` | Elasticsearch port. | `"9200"` |
| `kerberoshub.api.elasticsearch.index` | Elasticsearch index which is used to store the events. | `"kerberos-cloud"` |
| `kerberoshub.api.elasticsearch.username` | Elasticsearch username. | `""` |
| `kerberoshub.api.elasticsearch.password` | Elasticsearch password. | `""` |
| `kerberoshub.api.sso.redirectUrl` | The OIC redirectUrl, once the authentication is validated. | `""` |
| `kerberoshub.api.sso.forceSSO` | Force SSO login for users of the configured domain. | `""` |
| `kerberoshub.api.sso.issuer` | Kerberos Hub can be linked to OpenID Connect for SSO. Specify the OIC issuer. | `""` |
| `kerberoshub.api.sso.claimId` | OIDC claim used to uniquely identify the authenticated user. | `""` |
| `kerberoshub.api.sso.clientId` | The OIC client id. | `""` |
| `kerberoshub.api.sso.clientSecret` | The OIC client secret. | `""` |
| `kerberoshub.api.sso.clientVerificationId` | Optional client verification ID used for SSO chaining scenarios. | `""` |
| `kerberoshub.api.sso.extraHeaders` | Additional headers appended to outbound SSO provider requests. | `""` |
| `kerberoshub.api.sso.extraHeaders.value` | Header value for each configured SSO extra header entry. | `""` |
| `kerberoshub.frontend.repository` | The Docker registry where the Kerberos Hub frontend is hosted. | `"ghcr.io/uug-ai/hub-frontend"` |
| `kerberoshub.frontend.pullPolicy` | The Docker registry pull policy. | `"IfNotPresent"` |
| `kerberoshub.frontend.tag` | The Docker image tag/version. | `"v1.9.11"` |
| `kerberoshub.frontend.replicas` | The number of pods/replicas running for the Kerberos Hub frontend deployment. | `2` |
| `kerberoshub.frontend.logLevel` | Log verbosity level for `kerberoshub.frontend`. | `"info"` |
| `kerberoshub.frontend.schema` | The protocol to serve the Kerberos Hub frontend, `'http'` or `'https'`. | `"https"` |
| `kerberoshub.frontend.url` | The Kerberos Hub frontend ingress to access the frontend. | `"yourdomain.com"` |
| `kerberoshub.frontend.resources.requests.memory` | Memory request for `kerberoshub.frontend`. | `"50Mi"` |
| `kerberoshub.frontend.resources.requests.cpu` | CPU request for `kerberoshub.frontend`. | `"50m"` |
| `kerberoshub.frontend.resources.limits.memory` | Memory limit for `kerberoshub.frontend`. | `"50Mi"` |
| `kerberoshub.frontend.resources.limits.cpu` | CPU limit for `kerberoshub.frontend`. | `"50m"` |
| `kerberoshub.frontend.tls` | Bring your own TLS certificates for Kerberos Hub frontend ingress. | `<list>` |
| `kerberoshub.frontend.tls.secretName` | Kubernetes Secret name used by `kerberoshub.frontend.tls`. | `""` |
| `kerberoshub.frontend.mixpanel.apikey` | No longer used. | `"xxx"` |
| `kerberoshub.frontend.sentry.url` | No longer used. | `"https://xxx@sentry.io/xxx"` |
| `kerberoshub.frontend.stripe.publicKey` | Public key for `kerberoshub.frontend.stripe`. | `""` |
| `kerberoshub.frontend.googlemaps.apikey` | Within Kerberos Hub frontend a couple of maps are being used, the google maps is leveraged for that. | `"xxxx"` |
| `kerberoshub.frontend.zendesk.url` | No longer used. | `"yourdomain.zendesk.com"` |
| `kerberoshub.frontend.posthog.key` | The API key retrieved from the Posthog instance. | `"xxx"` |
| `kerberoshub.frontend.posthog.url` | Posthog's endpoint (http/https). | `"https://posthog.domain.com"` |
| `kerberoshub.frontend.hideAddAgent` | Configuration value for `kerberoshub.frontend.hideAddAgent`. | `"false"` |
| `kerberoshub.frontend.multiTenant` | Configuration value for `kerberoshub.frontend.multiTenant`. | `false` |
| `kerberoshub.frontend.title` | Title text used for `kerberoshub.frontend`. | `"Kerberos Hub - Video surveillance as it should be"` |
| `kerberoshub.frontend.logo` | The logo being used in the Kerberos Hub frontend, set to 'custom' if you want to mount your own stylesheet. | `"custom"` |
| `kerberoshub.frontend.navigationLinkTitle1` | Custom navigation item (title 1) | `""` |
| `kerberoshub.frontend.navigationLinkUrl1` | Custom navigation item (url 1) | `""` |
| `kerberoshub.frontend.navigationLinkTitle2` | Custom navigation item (title 2) | `""` |
| `kerberoshub.frontend.navigationLinkUrl2` | Custom navigation item (url 2) | `""` |
| `kerberoshub.frontend.navigationLinkTitle3` | Custom navigation item (title 3) | `""` |
| `kerberoshub.frontend.navigationLinkUrl3` | Custom navigation item (url 3) | `""` |
| `kerberoshub.frontend.navigationLinkTitle4` | Custom navigation item (title 4) | `""` |
| `kerberoshub.frontend.navigationLinkUrl4` | Custom navigation item (url 4) | `""` |
| `kerberoshub.frontend.navigationLinkTitle5` | Custom navigation item (title 5) | `""` |
| `kerberoshub.frontend.navigationLinkUrl5` | Custom navigation item (url 5) | `""` |
| `kerberoshub.frontend.caseFilterAssigneesDefault` | Default assignee filter behavior for cases in the frontend. | `"false"` |
| `kerberoshub.frontend.features.case.enabled` | Enable or disable the case feature in the frontend. | `"true"` |
| `kerberoshub.frontend.features.darkModeEnabled` | Enable or disable dark mode in the frontend. | `"true"` |
| `kerberoshub.frontend.features.landingPage` | Frontend landing page configuration. | `"/dashboard"` |
| `kerberoshub.frontend.features.i18n.enabled` | Enable or disable the runtime language switcher in the front-end. When `"false"`, `defaultLanguage` is forced and users cannot change it. | `"true"` |
| `kerberoshub.frontend.features.i18n.defaultLanguage` | Default language code used by the front-end (e.g. `en`, `nl`, `pl`, `tr`, `fr`, `sv`, `de`). | `"en"` |
| `kerberoshub.frontend.features.workflows.enabled` | Enable or disable the workflows feature in the frontend. | `"false"` |
| `kerberoshub.frontend.features.map.tileUrlLight` | Tile URL used by the map in light mode. | `"https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png"` |
| `kerberoshub.frontend.features.map.tileUrlDark` | Tile URL used by the map in dark mode. | `"https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"` |
| `kerberoshub.frontend.features.map.attribution` | Attribution text displayed on the map tiles. | `"&copy; <a href='https://www.openstreetmap.org/copyright' target='_blank'>OpenStreetMap</a>"` |
| `kerberoshub.frontend.features.liveview.defaultStreamMode` | Liveview behavior setting: `defaultStreamMode`. | `"SD"` |
| `kerberoshub.frontend.features.liveview.paginationMode` | Liveview behavior setting: `paginationMode` (`scroll`, `numbered` or `maxStreams`). | `"scroll"` |
| `kerberoshub.frontend.features.liveview.pageSize` | Liveview behavior setting: `pageSize` (max streams shown per page in `numbered` mode). | `"6"` |
| `kerberoshub.frontend.features.liveview.maxStreams` | Liveview behavior setting: `maxStreams`. | `"-1"` |
| `kerberoshub.frontend.features.chart.colorChartSelectionFill` | Fill color for chart selection regions. | `"rgba(132, 86, 159, 0.07)"` |
| `kerberoshub.frontend.features.chart.colorChartSelectionStroke` | Stroke color for chart selection regions. | `"rgba(132, 86, 159, 0.4)"` |
| `kerberoshub.frontend.features.chart.colorChartGridStroke` | Stroke color for chart grid lines. | `"rgba(0, 106, 255, 0.18)"` |
| `kerberoshub.frontend.features.devices.hideAgent` | Hide agent controls in the devices section of the frontend. | `"false"` |
| `kerberoshub.frontend.features.media.filter.date.enabled` | Enable or disable `kerberoshub.frontend.features.media.filter.date`. | `"true"` |
| `kerberoshub.frontend.features.media.filter.sites.enabled` | Enable or disable `kerberoshub.frontend.features.media.filter.sites`. | `"true"` |
| `kerberoshub.frontend.features.media.filter.groups.enabled` | Enable or disable `kerberoshub.frontend.features.media.filter.groups`. | `"true"` |
| `kerberoshub.frontend.features.media.filter.devices.enabled` | Enable or disable `kerberoshub.frontend.features.media.filter.devices`. | `"true"` |
| `kerberoshub.frontend.features.media.filter.objectDetection.enabled` | Enable or disable `kerberoshub.frontend.features.media.filter.objectDetection`. | `"true"` |
| `kerberoshub.frontend.features.media.filter.star.enabled` | Enable or disable `kerberoshub.frontend.features.media.filter.star`. | `"true"` |
| `kerberoshub.frontend.features.media.filter.region.enabled` | Enable or disable `kerberoshub.frontend.features.media.filter.region`. | `"true"` |
| `kerberoshub.frontend.features.media.filter.sort.enabled` | Enable or disable `kerberoshub.frontend.features.media.filter.sort`. | `"true"` |
| `kerberoshub.frontend.features.media.filter.category.enabled` | Enable or disable `kerberoshub.frontend.features.media.filter.category`. | `"true"` |
| `kerberoshub.frontend.features.media.filter.markers.enabled` | Enable or disable `kerberoshub.frontend.features.media.filter.markers`. | `"true"` |
| `kerberoshub.frontend.features.media.filter.events.enabled` | Enable or disable `kerberoshub.frontend.features.media.filter.events`. | `"true"` |
| `kerberoshub.frontend.features.liveview.defaultStreamMode` | Default live stream mode: `SD` or `HD`. | `"SD"` |lter.tags`. | `"true"` |
| `kerberoshub.frontend.features.media.filter.defaultView` | Default view for the media page: `timeline` or `grid`. | `"timeline"` |
| `kerberoshub.frontend.features.floorplan.enabled` | Enable or disable `kerberoshub.frontend.features.floorplan`. | `"true"` |
| `kerberoshub.frontend.features.floorplan.colorDeviceActive` | Color customization for `floorplan` in the frontend. | `"hsla(131, 31%, 52%, 1)"` |
| `kerberoshub.frontend.features.floorplan.colorDeviceInactive` | Color customization for `floorplan` in the frontend. | `"hsla(0, 3%, 41%, 1)"` |
| `kerberoshub.frontend.features.floorplan.colorDeviceIdle` | Color customization for `floorplan` in the frontend. | `"hsla(47, 86%, 47%, 1)"` |
| `kerberoshub.frontend.features.floorplan.colorDeviceMotion` | Color customization for `floorplan` in the frontend. | `"hsla(2, 58%, 48%, 1)"` |
| `kerberoshub.frontend.features.floorplan.colorLiveViewControlActive` | Color customization for `floorplan` in the frontend. | `"hsla(131, 31%, 52%, 1)"` |
| `kerberoshub.frontend.features.floorplan.colorLiveViewControlMotion` | Color customization for `floorplan` in the frontend. | `"hsla(2, 58%, 48%, 1)"` |
| `kerberoshub.frontend.features.floorplan.colorFloorPlanLabelText` | Color customization for `floorplan` in the frontend. | `"hsla(0, 0%, 100%, 1)"` |
| `kerberoshub.frontend.features.floorplan.colorFloorPlanLabelBackground` | Color customization for `floorplan` in the frontend. | `"hsla(0, 0%, 0%, 0.8)"` |
| `kerberoshub.frontend.features.floorplan.colorDeviceMarkerBorder` | Color customization for `floorplan` in the frontend. | `"hsla(0, 0%, 100%, 1)"` |
| `kerberoshub.frontend.features.floorplan.colorTrackBox` | Color customization for `floorplan` in the frontend. | `"hsla(278, 30%, 48%, 1)"` |
| `kerberoshub.frontend.features.floorplan.colorTrackBoxHover` | Color customization for `floorplan` in the frontend. | `"hsla(47, 86%, 47%, 1)"` |
| `kerberoshub.frontend.features.floorplan.colorTrackBoxDrawing` | Color customization for `floorplan` in the frontend. | `"hsla(204, 100%, 50%, 1)"` |
| `kerberoshub.frontend.features.floorplan.colorTrackBoxControlsDelete` | Color customization for `floorplan` in the frontend. | `"hsla(219, 100%, 94%, 1)"` |
| `kerberoshub.frontend.features.faceRedaction.enabled` | Enable or disable `kerberoshub.frontend.features.faceRedaction`. | `"false"` |
| `kerberoshub.support.enabled` | Enable or disable in-app support features. | `false` |
| `kerberoshub.oauth2Proxy.enabled` | Enable or disable `kerberoshub.oauth2Proxy`. | `false` |
| `kerberoshub.oauth2Proxy.github.clientId` | Client ID used by `kerberoshub.oauth2Proxy.github`. | `"github-client-id"` |
| `kerberoshub.oauth2Proxy.github.clientSecret` | Client secret used by `kerberoshub.oauth2Proxy.github`. | `"github-client-secret"` |
| `kerberoshub.oauth2Proxy.github.cookieSecret` | Cookie secret used by `kerberoshub.oauth2Proxy.github`. | `"generate-a-random-cookie-secret"` |
| `kerberoshub.oauth2Proxy.github.organization` | Organization value used by `kerberoshub.oauth2Proxy.github`. | `"github-organization"` |
| `kerberoshub.oauth2Proxy.github.team` | Team value used by `kerberoshub.oauth2Proxy.github`. | `"github-team"` |
| `kerberoshub.cleanup.repository` | The Docker container that is responsible for cleaning up the Kerberos Hub API content and related MongoDB collections. | `"ghcr.io/uug-ai/hub-cleanup"` |
| `kerberoshub.cleanup.pullPolicy` | The Docker registry pull policy. | `"IfNotPresent"` |
| `kerberoshub.cleanup.tag` | The Docker image tag/version. | `"v1.4.13"` |
| `kerberoshub.cleanup.replicas` | Number of replicas for `kerberoshub.cleanup`. | `1` |
| `kerberoshub.cleanup.mode` | Cleanup service mode: `serve`, `dry-run`, or `version`. | `"serve"` |
| `kerberoshub.cleanup.logLevel` | Log verbosity level for `kerberoshub.cleanup`. | `"info"` |
| `kerberoshub.cleanup.maxDays` | Hard maximum age (in days) used by the optional global cleanup pass. | `"365"` |
| `kerberoshub.cleanup.runIntervalMinutes` | Minutes between cleanup cycles. | `"10"` |
| `kerberoshub.cleanup.cleanupUsernames` | Optional comma-separated usernames to target. | `""` |
| `kerberoshub.cleanup.batchSize` | Delete batch size per collection operation. | `"250"` |
| `kerberoshub.cleanup.userBatchSize` | Number of users processed per inner batch. | `"100"` |
| `kerberoshub.cleanup.maxUsersPerRun` | Maximum users processed per run. | `"100"` |
| `kerberoshub.cleanup.progressEvery` | Print progress every N processed users. | `"100"` |
| `kerberoshub.cleanup.activeUserRescanHours` | Rescan interval for active users. | `"6"` |
| `kerberoshub.cleanup.inactiveUserRescanHours` | Rescan interval for inactive users. | `"24"` |
| `kerberoshub.cleanup.readTimeoutSeconds` | Timeout for MongoDB read operations. | `"30"` |
| `kerberoshub.cleanup.deleteTimeoutSeconds` | Timeout for delete operations. | `"120"` |
| `kerberoshub.cleanup.reportIncludeStats` | Include richer per-user dry-run summary stats. | `"false"` |
| `kerberoshub.cleanup.dryRun` | Force dry-run behavior through env var. | `"false"` |
| `kerberoshub.cleanup.debug` | Enable extra cleanup debug logging. | `"false"` |
| `kerberoshub.cleanup.globalPassEnabled` | Enable optional global orphan cleanup pass. | `"false"` |
| `kerberoshub.cleanup.globalPassIntervalHours` | Minimum hours between global cleanup passes. | `"0"` |
| `kerberoshub.cleanup.globalPassDeleteBudget` | Max documents deleted during a global pass. | `"0"` |
| `kerberoshub.cleanup.defaultTaskRetentionDays` | Default retention (in days) applied to tasks without an explicit `retention_days`. Tasks older than this (anchored on `creation_date`) are deleted with their `case_media` rows. Set to `"0"` or a negative value to keep tasks forever. Must match `kerberoshub.api.defaultTaskRetentionDays`. | `"0"` |
| `kerberoshub.cleanup.resources.requests.memory` | Memory request for `kerberoshub.cleanup`. | `"10Mi"` |
| `kerberoshub.cleanup.resources.requests.cpu` | CPU request for `kerberoshub.cleanup`. | `"10m"` |
| `kerberoshub.monitordevice.repository` | The monitoring microservice, following up the status of your cameras and Agents. | `"ghcr.io/uug-ai/hub-monitor-device"` |
| `kerberoshub.monitordevice.pullPolicy` | The Docker registry pull policy. | `"IfNotPresent"` |
| `kerberoshub.monitordevice.tag` | The Docker image tag/version. | `"v1.4.0"` |
| `kerberoshub.monitordevice.replicas` | Number of replicas for `kerberoshub.monitordevice`. | `1` |
| `kerberoshub.monitordevice.logLevel` | Log verbosity level for `kerberoshub.monitordevice`. | `"info"` |
| `kerberoshub.monitordevice.resources.requests.memory` | Memory request for `kerberoshub.monitordevice`. | `"10Mi"` |
| `kerberoshub.monitordevice.resources.requests.cpu` | CPU request for `kerberoshub.monitordevice`. | `"10m"` |
| `kerberoshub.reactivate.repository` | Container image repository for `kerberoshub.reactivate`. | `"uugai/hub-reactivatesubscriptions"` |
| `kerberoshub.reactivate.pullPolicy` | Image pull policy for `kerberoshub.reactivate`. | `"IfNotPresent"` |
| `kerberoshub.reactivate.tag` | Container image tag/version for `kerberoshub.reactivate`. | `"v1.0.2"` |
| `kerberoshub.reactivate.replicas` | Number of replicas for `kerberoshub.reactivate`. | `1` |
| `kerberoshub.reactivate.logLevel` | Log verbosity level for `kerberoshub.reactivate`. | `"info"` |
| `kerberoshub.reactivate.resources.requests.memory` | Memory request for `kerberoshub.reactivate`. | `"10Mi"` |
| `kerberoshub.reactivate.resources.requests.cpu` | CPU request for `kerberoshub.reactivate`. | `"10m"` |
| `kerberoshub.forwarder.enabled` | Enable or disable the Hub forwarder component. | `false` |
| `kerberoshub.proxy.repository` | Container image repository for `kerberoshub.proxy`. | `"uugai/hub-proxy"` |
| `kerberoshub.proxy.pullPolicy` | Image pull policy for `kerberoshub.proxy`. | `"IfNotPresent"` |
| `kerberoshub.proxy.tag` | Container image tag/version for `kerberoshub.proxy`. | `"v1.0.0"` |
| `kerberoshub.proxy.replicas` | Number of replicas for `kerberoshub.proxy`. | `1` |
| `kerberoshub.proxy.logLevel` | Log verbosity level for `kerberoshub.proxy`. | `"info"` |
| `kerberoshub.proxy.resources.requests.memory` | Memory request for `kerberoshub.proxy`. | `"10Mi"` |
| `kerberoshub.proxy.resources.requests.cpu` | CPU request for `kerberoshub.proxy`. | `"10m"` |
| `kerberospipeline.event.repository` | The [event orchestration](https://doc.kerberos.io/hub/pipeline/#orchestrator) microservice. | `"ghcr.io/uug-ai/hub-pipeline-event"` |
| `kerberospipeline.event.pullPolicy` | The Docker registry pull policy. | `"IfNotPresent"` |
| `kerberospipeline.event.tag` | The Docker image tag/version. | `"v1.3.0"` |
| `kerberospipeline.event.replicas` | Number of replicas for `kerberospipeline.event`. | `1` |
| `kerberospipeline.event.logLevel` | Log verbosity level for `kerberospipeline.event`. | `"info"` |
| `kerberospipeline.event.resources.requests.memory` | Memory request for `kerberospipeline.event`. | `"10Mi"` |
| `kerberospipeline.event.resources.requests.cpu` | CPU request for `kerberospipeline.event`. | `"10m"` |
| `kerberospipeline.monitor.repository` | The [monitoring microservice](https://doc.kerberos.io/hub/pipeline/#monitoring), calculating metrics of incoming messages. | `"ghcr.io/uug-ai/hub-pipeline-monitor"` |
| `kerberospipeline.monitor.pullPolicy` | The Docker registry pull policy. | `"IfNotPresent"` |
| `kerberospipeline.monitor.tag` | The Docker image tag/version. | `"v1.3.9"` |
| `kerberospipeline.monitor.replicas` | Number of replicas for `kerberospipeline.monitor`. | `1` |
| `kerberospipeline.monitor.resources.requests.memory` | Memory request for `kerberospipeline.monitor`. | `"10Mi"` |
| `kerberospipeline.monitor.resources.requests.cpu` | CPU request for `kerberospipeline.monitor`. | `"10m"` |
| `kerberospipeline.sequence.repository` | The [sequencer microservice](https://doc.kerberos.io/hub/pipeline/#sequencer), grouping recordings in chunks/groups. | `"ghcr.io/uug-ai/hub-pipeline-sequence"` |
| `kerberospipeline.sequence.pullPolicy` | The Docker registry pull policy. | `"IfNotPresent"` |
| `kerberospipeline.sequence.tag` | The Docker image tag/version. | `"v1.6.18"` |
| `kerberospipeline.sequence.replicas` | Number of replicas for `kerberospipeline.sequence`. | `1` |
| `kerberospipeline.sequence.resources.requests.memory` | Memory request for `kerberospipeline.sequence`. | `"10Mi"` |
| `kerberospipeline.sequence.resources.requests.cpu` | CPU request for `kerberospipeline.sequence`. | `"10m"` |
| `kerberospipeline.throttler.repository` | The [throttler microservice](https://doc.kerberos.io/hub/pipeline/#throttler), throttling events. | `"uugai/hub-pipeline-throttler"` |
| `kerberospipeline.throttler.pullPolicy` | The Docker registry pull policy. | `"IfNotPresent"` |
| `kerberospipeline.throttler.tag` | The Docker image tag/version. | `"v1.2.0"` |
| `kerberospipeline.throttler.replicas` | Number of replicas for `kerberospipeline.throttler`. | `1` |
| `kerberospipeline.throttler.logLevel` | Log verbosity level for `kerberospipeline.throttler`. | `"info"` |
| `kerberospipeline.throttler.resources.requests.memory` | Memory request for `kerberospipeline.throttler`. | `"10Mi"` |
| `kerberospipeline.throttler.resources.requests.cpu` | CPU request for `kerberospipeline.throttler`. | `"10m"` |
| `kerberospipeline.notify.repository` | The [notification microservice](https://doc.kerberos.io/hub/pipeline/#notification), sending notifications on events. | `"ghcr.io/uug-ai/hub-pipeline-notification"` |
| `kerberospipeline.notify.pullPolicy` | The Docker registry pull policy. | `"IfNotPresent"` |
| `kerberospipeline.notify.tag` | The Docker image tag/version. | `"v1.3.9"` |
| `kerberospipeline.notify.replicas` | Number of replicas for `kerberospipeline.notify`. | `1` |
| `kerberospipeline.notify.logLevel` | Log verbosity level for `kerberospipeline.notify`. | `"info"` |
| `kerberospipeline.notify.resources.requests.memory` | Memory request for `kerberospipeline.notify`. | `"10Mi"` |
| `kerberospipeline.notify.resources.requests.cpu` | CPU request for `kerberospipeline.notify`. | `"10m"` |
| `kerberospipeline.notifyTest.repository` | The notification service for testing, the different channels. | `"uugai/hub-pipeline-notification-test"` |
| `kerberospipeline.notifyTest.pullPolicy` | The Docker registry pull policy. | `"IfNotPresent"` |
| `kerberospipeline.notifyTest.tag` | The Docker image tag/version. | `"v1.2.1"` |
| `kerberospipeline.notifyTest.replicas` | Number of replicas for `kerberospipeline.notifyTest`. | `1` |
| `kerberospipeline.notifyTest.resources.requests.memory` | Memory request for `kerberospipeline.notifyTest`. | `"10Mi"` |
| `kerberospipeline.notifyTest.resources.requests.cpu` | CPU request for `kerberospipeline.notifyTest`. | `"10m"` |
| `kerberospipeline.analysis.repository` | The [analysis microservices](https://doc.kerberos.io/hub/pipeline/#analyser) which executed specific analysis in parallel. | `"ghcr.io/uug-ai/hub-pipeline-analysis"` |
| `kerberospipeline.analysis.pullPolicy` | The Docker registry pull policy. | `"IfNotPresent"` |
| `kerberospipeline.analysis.tag` | The Docker image tag/version. | `"v1.7.8"` |
| `kerberospipeline.analysis.replicas` | Number of replicas for `kerberospipeline.analysis`. | `1` |
| `kerberospipeline.analysis.logLevel` | Log verbosity level for `kerberospipeline.analysis`. | `"info"` |
| `kerberospipeline.analysis.resources.requests.memory` | Memory request for `kerberospipeline.analysis`. | `"10Mi"` |
| `kerberospipeline.analysis.resources.requests.cpu` | CPU request for `kerberospipeline.analysis`. | `"10m"` |
| `kerberospipeline.dominantColor.repository` | The dominant color microservices is computing a top 3 color histogram. | `"ghcr.io/uug-ai/hub-pipeline-dominantcolors"` |
| `kerberospipeline.dominantColor.pullPolicy` | The Docker registry pull policy. | `"IfNotPresent"` |
| `kerberospipeline.dominantColor.tag` | The Docker image tag/version. | `"v2.0.2"` |
| `kerberospipeline.dominantColor.replicas` | Number of replicas for `kerberospipeline.dominantColor`. | `3` |
| `kerberospipeline.dominantColor.logLevel` | Log verbosity level for `kerberospipeline.dominantColor`. | `"info"` |
| `kerberospipeline.dominantColor.resources.requests.memory` | Memory request for `kerberospipeline.dominantColor`. | `"512Mi"` |
| `kerberospipeline.dominantColor.resources.requests.cpu` | CPU request for `kerberospipeline.dominantColor`. | `"500m"` |
| `kerberospipeline.dominantColor.resources.limits.memory` | Memory limit for `kerberospipeline.dominantColor`. | `"2Gi"` |
| `kerberospipeline.dominantColor.resources.limits.cpu` | CPU limit for `kerberospipeline.dominantColor`. | `"1000m"` |
| `kerberospipeline.thumbnail.repository` | The thumbnail microservices generated a thumbnail for a recordings. | `"ghcr.io/uug-ai/hub-pipeline-thumbnail"` |
| `kerberospipeline.thumbnail.pullPolicy` | The Docker registry pull policy. | `"IfNotPresent"` |
| `kerberospipeline.thumbnail.tag` | The Docker image tag/version. | `"v1.3.4"` |
| `kerberospipeline.thumbnail.replicas` | Number of replicas for `kerberospipeline.thumbnail`. | `2` |
| `kerberospipeline.thumbnail.logLevel` | Log verbosity level for `kerberospipeline.thumbnail`. | `"info"` |
| `kerberospipeline.thumbnail.quality` | Configuration value for `kerberospipeline.thumbnail.quality`. | `"1"` |
| `kerberospipeline.thumbnail.width` | Configuration value for `kerberospipeline.thumbnail.width`. | `"600"` |
| `kerberospipeline.thumbnail.height` | Configuration value for `kerberospipeline.thumbnail.height`. | `"-1"` |
| `kerberospipeline.thumbnail.kerberosvault.enabled` | Enable or disable `kerberospipeline.thumbnail.kerberosvault`. | `true` |
| `kerberospipeline.thumbnail.resources.requests.memory` | Memory request for `kerberospipeline.thumbnail`. | `"512Mi"` |
| `kerberospipeline.thumbnail.resources.requests.cpu` | CPU request for `kerberospipeline.thumbnail`. | `"500m"` |
| `kerberospipeline.thumbnail.resources.limits.memory` | Memory limit for `kerberospipeline.thumbnail`. | `"2Gi"` |
| `kerberospipeline.thumbnail.resources.limits.cpu` | CPU limit for `kerberospipeline.thumbnail`. | `"1000m"` |
| `kerberospipeline.counting.repository` | The counting microservices computes objects passing different line segments. | `"uugai/hub-pipeline-counting"` |
| `kerberospipeline.counting.pullPolicy` | The Docker registry pull policy. | `"IfNotPresent"` |
| `kerberospipeline.counting.tag` | The Docker image tag/version. | `"v1.6.3"` |
| `kerberospipeline.counting.replicas` | Number of replicas for `kerberospipeline.counting`. | `1` |
| `kerberospipeline.counting.logLevel` | Log verbosity level for `kerberospipeline.counting`. | `"info"` |
| `kerberospipeline.counting.resources.requests.memory` | Memory request for `kerberospipeline.counting`. | `"10Mi"` |
| `kerberospipeline.counting.resources.requests.cpu` | CPU request for `kerberospipeline.counting`. | `"10m"` |
| `kerberospipeline.sprite.enabled` | Enable or disable `kerberospipeline.sprite`. | `false` |
| `kerberospipeline.sprite.repository` | Container image repository for `kerberospipeline.sprite`. | `"ghcr.io/uug-ai/hub-pipeline-sprite"` |
| `kerberospipeline.sprite.pullPolicy` | Image pull policy for `kerberospipeline.sprite`. | `"IfNotPresent"` |
| `kerberospipeline.sprite.tag` | Container image tag/version for `kerberospipeline.sprite`. | `"v1.1.12"` |
| `kerberospipeline.sprite.replicas` | Number of replicas for `kerberospipeline.sprite`. | `5` |
| `kerberospipeline.sprite.logLevel` | Log verbosity level for `kerberospipeline.sprite`. | `"info"` |
| `kerberospipeline.sprite.interval` | Configuration value for `kerberospipeline.sprite.interval`. | `"1"` |
| `kerberospipeline.sprite.width` | Configuration value for `kerberospipeline.sprite.width`. | `"240"` |
| `kerberospipeline.sprite.height` | Configuration value for `kerberospipeline.sprite.height`. | `"135"` |
| `kerberospipeline.sprite.resources.requests.memory` | Memory request for `kerberospipeline.sprite`. | `"512Mi"` |
| `kerberospipeline.sprite.resources.requests.cpu` | CPU request for `kerberospipeline.sprite`. | `"500m"` |
| `kerberospipeline.sprite.resources.limits.memory` | Memory limit for `kerberospipeline.sprite`. | `"2Gi"` |
| `kerberospipeline.sprite.resources.limits.cpu` | CPU limit for `kerberospipeline.sprite`. | `"1000m"` |
| `kerberospipeline.export.repository` | Container image repository for `kerberospipeline.export`. | `"ghcr.io/uug-ai/hub-pipeline-export"` |
| `kerberospipeline.export.pullPolicy` | Image pull policy for `kerberospipeline.export`. | `"IfNotPresent"` |
| `kerberospipeline.export.tag` | Container image tag/version for `kerberospipeline.export`. | `"v1.2.4"` |
| `kerberospipeline.export.replicas` | Number of replicas for `kerberospipeline.export`. | `2` |
| `kerberospipeline.export.logLevel` | Log verbosity level for `kerberospipeline.export`. | `"info"` |
| `kerberospipeline.export.resources.requests.memory` | Memory request for `kerberospipeline.export`. | `"10Mi"` |
| `kerberospipeline.export.resources.requests.cpu` | CPU request for `kerberospipeline.export`. | `"10m"` |
| `kerberospipeline.redaction.repository` | Container image repository for `kerberospipeline.redaction`. | `"ghcr.io/uug-ai/hub-pipeline-redaction"` |
| `kerberospipeline.redaction.pullPolicy` | Image pull policy for `kerberospipeline.redaction`. | `"IfNotPresent"` |
| `kerberospipeline.redaction.tag` | Container image tag/version for `kerberospipeline.redaction`. | `"v1.0.0"` |
| `kerberospipeline.redaction.replicas` | Number of replicas for `kerberospipeline.redaction`. | `2` |
| `kerberospipeline.redaction.logLevel` | Log verbosity level for `kerberospipeline.redaction`. | `"info"` |
| `kerberospipeline.redaction.resources.requests.memory` | Memory request for `kerberospipeline.redaction`. | `"512Mi"` |
| `kerberospipeline.redaction.resources.requests.cpu` | CPU request for `kerberospipeline.redaction`. | `"500m"` |
| `kerberospipeline.redaction.resources.limits.memory` | Memory limit for `kerberospipeline.redaction`. | `"2Gi"` |
| `kerberospipeline.redaction.resources.limits.cpu` | CPU limit for `kerberospipeline.redaction`. | `"1000m"` |
| `email.provider` | The email service provider for sending out messages over email , use `'mailgun'` or `'smtp'`. | `"mailgun"` |
| `email.from` | The email address that is sending messages in name of, by default `'support@yourdomain.com'`. | `"support@yourdomain.com"` |
| `email.displayName` | The display name that is sending messages in name of, by default `'yourdomain.com'` | `"yourdomain.com"` |
| `email.mailgun.domain` | While using `mailgun` as email service provider, you will need to provide your Mailgun domain. | `"mg.yourdomain.com"` |
| `email.mailgun.apikey` | Mailgun API key (lowercase variant) used when provider is `mailgun`. | `"xxxx"` |
| `email.smtp.server` | While using `smtp` as email service provider, use the SMTP server. | `"smtp.yourdomain.com"` |
| `email.smtp.port` | SMTP port specified by your SMTP server, by default `'456'`. | `"465"` |
| `email.smtp.username` | SMTP username. | `"yourusername"` |
| `email.smtp.password` | SMTP password. | `"yourpassword"` |
| `email.templates.welcome` | The template which is send when a new user registered on the platform (`IS_PRIVATE='false'`), by default `'disabled'`. | `"welcome"` |
| `email.templates.welcomeTitle` | The welcome title use in the subject of the email. | `"Welcome to Kerberos Hub"` |
| `email.templates.activate` | The template which is send when a user is required to activate his account , by default `'activate'`. | `"activate"` |
| `email.templates.activateTitle` | The activation title use in the subject of the email. | `"Wonderful! Your Kerberos Hub is now active"` |
| `email.templates.forgot` | The template which is send when an account is requesting a forgot password, by default `'forgot'`. | `"forgot"` |
| `email.templates.forgotTitle` | The forgot title use in the subject of the email. | `"Password reset Kerberos Hub. You forgot your password"` |
| `email.templates.share` | Email template name/key for `share` notifications. | `"share"` |
| `email.templates.shareTitle` | Email subject title for the `share` template. | `"[Action] You received a recording from Kerberos Hub"` |
| `email.templates.assignTask` | Email template name/key for `assign task` notifications. | `"assign_task"` |
| `email.templates.assignTaskTitle` | Email subject title for the `assign task` template. | `"[Action] You've been assigned to a task"` |
| `email.templates.detection` | We use templates to send notifications, this allow you to bring your own `Mailgun` templates, by default `'detection'`. | `"detection"` |
| `email.templates.disabled` | The template which is send when an account is disabled due to reaching its upload limit, by default `'disabled'`. | `"disabled"` |
| `email.templates.highupload` | The template which is send when an account is reaching a specific upload threshold, by default `'threshold'`. | `"highupload"` |
| `email.templates.device` | The template which is send when a camera goes online or offline, by default `'device'`. | `"device"` |
| `email.templates.alertTitle` | Email subject title for the `alert` template. | `"[Alert] Kerberos Hub detected something an event"` |
| `email.templates.deviceTitle` | Email subject title for the `device` template. | `"[Device] An Agent's status has been changed"` |
| `email.mailgun.apiKey` | The Mailgun API key linked to your Mailgun domain. | `""` |
| `imagePullSecrets.name` | Docker registry secret name, which is also granted with the license. This allows you to download the Docker images. | `""` |
| `kerberoshub.forwarder.pullPolicy` | The Docker registry pull policy. | `""` |
| `kerberoshub.forwarder.repository` | The Docker container which orchestrates forwarding coming from different Kerberos Vaults. | `""` |
| `kerberoshub.forwarder.tag` | The Docker image tag/version. | `""` |
| `kerberoshub.frontend.ssoDomain` | The domain that's being used to activate SSO from the login page. | `""` |
| `kerberoshub.frontend.stripe.apikey` | If using the public version, `stripe` can be used for automated billing and subscriptions. | `""` |

### Post installation

After the installation you'll need to initialise the Mongodb with some objects. Have a look at the `mongodb/` folder, you'll find three files available:

- settings.nosql
- subscriptions.nosql
- users.nosql

Open your favourite Mongodb client (or cli) and connect to your Mongodb database as previously created (or have already installed). Import the previous mentioned `.nosql` files into a new database called `Kerberos`.

![Open the Mongodb client](assets/images/mongodb-client.png)

Once done you should be able to sign in with following credentials:

- username: youruser
- password: yourpassword

Please note that the default username and password can be changed [by the changing the related username and password hash](https://github.com/kerberos-io/hub/blob/master/mongodb/users.nosql#L3-L5). The password hash is a bcrypt computed hash, which you can compute yourself [using a bcrypt client](https://bcrypt-generator.com/).

### Subscription settings

Once the collections are loaded in the Mongodb instance, you should see the `user`, `subscriptons` and `settings` collections. Those three collections will allow a user to login into the Kerberos Hub web interface, using the previously mentioned username and password.

Next to that, in the `subscriptions` collection you will find a subscription for that specific user. The subscription specifies which kind of access the user has in terms of features and upload quota.

Building further on those `subscriptions`, you will find a `settings` collection that contains the quota for each `subscription`.

### Settings collection

As mentioned during the Post installation step, you'll import some `.nosql` files. The `settings.nosql` file includes all the relevant configurations and parameters that allow you to tweak the Kerberos Hub deployment (dynamically).

#### Classifications

Within the Kerberos Hub front-end you'll see the option to filter through classifications. This filtered is stored in the `settings` collection. By changing the entries of the `classifications` object, you can add, edit or remove items from the filters.

### Indexing

Following indexes should be executed on the MongoDB database (Kerberos) to improve future performance. Within Kerberos Hub several queries are executed, following indexes will improve the loading times. If not applied you might experience application timeouts or reduced performance when storing lots of data.

#### Sequences collection

    db.getCollection('sequences').createIndex({start:1})
    db.getCollection('sequences').createIndex({user_id:1, "images.key":1})
    db.getCollection('sequences').createIndex({user_id:1, end:1, start: -1, devices: 1})
    db.getCollection('sequences').createIndex({user_id:1, end:1, start: 1, "images.instanceName": 1})

#### Notifications collection

    db.getCollection("notifications").createIndex({userid:1})
    db.getCollection("notifications").createIndex({userid:1, timestamp:1})
    db.getCollection("notifications").createIndex({alert_master_user:1, media_key: 1})

#### Analysis collection

    db.getCollection("analysis").createIndex({start:1})
    db.getCollection("analysis").createIndex({userid:1, key:1})
    db.getCollection("analysis").createIndex({userid:1, start:1})

#### Heatmap collection

    db.getCollection("heatmap").createIndex({timestamp:1})
    db.getCollection("heatmap").createIndex({user_id:1, timestamp: 1})

# Upgrade

After installation, you might want to upgrade Kerberos Hub to the latest version, or change some settings. With Helm charts all settings are configured through the `values.yaml` file. After you made modifications to the `values.yaml` file, for example the version tag, or a new DNS name, you can run the `helm upgrade` command as following.

    helm upgrade hub kerberos/hub -f values.yaml -n kerberos-hub

The first argument is the helm project name, you could find this out by running `helm ls -n kerberos`. The following element is the helm chart name, and the last one is the `values.yaml` file with the new configuration.

# Building

To build a new release the following steps needs to be executed. Please note that this repository has a Github action which automatically releases new a Helm chart version.

    cd hub
    helm lint

    cd ..
    helm package hub
    mv hub-*.tgz hub

    helm repo index hub --url https://charts.kerberos.io/hub
    cd hub
    cat index.yaml
