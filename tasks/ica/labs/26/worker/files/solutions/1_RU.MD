[Eng version](1.MD) · [Versión en español](1_ES.MD) · [Version française](1_FR.MD) · [Deutsche Version](1_DE.MD) · [ქართული ვერსია](1_GE.MD) · [繁體中文版](1_TW.MD) · [日本語版](1_JP.MD)

# Лабораторная работа 26 - Эталонное решение

Платформа уже настроена для динамической выдачи сертификатов:
- **cert-manager** установлен;
- самоподписанный корневой CA и CA `Issuer` с именем `istio-ca` существуют в `istio-system`;
- **istio-csr** (`cert-manager-istio-csr`) запущен в `cert-manager` и обслуживает gRPC API Istio CA,
  используя `Issuer` `istio-ca`;
- **Istio** установлен со **встроенным CA**, который **отключен** (`ENABLE_CA_SERVER=false`), а
  `global.caAddress` указывает на istio-csr, поэтому istiod передает все операции подписания cert-manager.

`istioctl` доступен на рабочем ПК.

## Цель

Развернуть рабочую нагрузку и подтвердить, что ее сертификат идентификации (`SVID`) выдан
**cert-manager** через istio-csr, а не самоподписанным CA istiod.

## Шаг 1. Разверните приложение

```bash
kubectl apply -f https://raw.githubusercontent.com/ViktorUJ/cks/refs/heads/master/tasks/ica/labs/26/k8s-1/scripts/1.yaml
kubectl rollout status deploy/ping-pong -n app
```

## Шаг 2. Наблюдайте, как cert-manager выдает сертификат

```bash
# Every sidecar cert request becomes a CertificateRequest in istio-system
kubectl get certificaterequests.cert-manager.io -n istio-system

# istio-csr logs show the CSRs it forwards to cert-manager
kubectl logs -n cert-manager deploy/cert-manager-istio-csr --tail=20
```

## Шаг 3. Убедитесь, что сертификат рабочей нагрузки получен от cert-manager

```bash
POD=$(kubectl get pod -n app -l app=ping-pong -o jsonpath='{.items[0].metadata.name}')
istioctl proxy-config secret "$POD" -n app -o json \
  | jq -r '.dynamicActiveSecrets[] | select(.name=="default") | .secret.tlsCertificate.certificateChain.inlineBytes' \
  | base64 -d | openssl x509 -noout -issuer -ext subjectAltName
# issuer=O = cluster.local, O = cert-manager, CN = istio-ca
# X509v3 Subject Alternative Name: URI:spiffe://cluster.local/ns/app/sa/default
```

В издателе указаны `cert-manager` / `istio-ca` - SVID рабочей нагрузки подписан вашим
CA cert-manager, а идентификация SPIFFE сохранена.

## Как это работает

```
sidecar (istio-agent)
    │  CSR over gRPC
    ▼
istio-csr (cert-manager-istio-csr)      # implements the Istio CA API
    │  creates CertificateRequest
    ▼
cert-manager  ──uses──►  Issuer "istio-ca"  ──►  signs the cert
    │
    ▼
sidecar receives its SVID (rotated automatically)
```

- istiod больше не подписывает сертификаты (`ENABLE_CA_SERVER=false`); он направляет агентов на
  `caAddress: cert-manager-istio-csr.cert-manager.svc:443`.
- **istio-csr** реализует gRPC API Istio CA. Для каждого CSR рабочей нагрузки он создает
  `CertificateRequest` cert-manager, который cert-manager подписывает с настроенным
  `Issuer`.
- Ключ подписания хранится в `Issuer` cert-manager (здесь в секрете самоподписанного CA, но он
  может находиться в **Vault**, **ACME** CA или корпоративном PKI), а не в istiod.

## Почему это лучше статического `cacerts` (лабораторная работа 19)

| | Лабораторная работа 19 (секрет `cacerts`) | Эта лабораторная работа (cert-manager + istio-csr) |
|---|---|---|
| Расположение ключа подписания | промежуточный ключ находится в istiod | остается в `Issuer` cert-manager (Vault/PKI) |
| Ротация CA | вручную (пересоздать секрет + перезапустить) | автоматизирована cert-manager |
| Бэкенды | только статический PEM | Vault, ACME, корпоративный PKI и т. д. |
| Аудит | отсутствует | каждый сертификат является объектом `CertificateRequest` |

Оба подхода формируют цепочку mesh до CA, который вы контролируете; istio-csr является готовым
к промышленной эксплуатации и автоматизируемым развитием.
