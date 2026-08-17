[Русская версия](README_RU.MD) · [Eng version](README.MD) · [Versión en español](README_ES.MD) · [Version française](README_FR.MD) · [Deutsche Version](README_DE.MD) · [繁體中文版](README_TW.MD) · [日本語版](README_JP.MD)

# Lab 121 — დრილები: RBAC

## აღწერა

სიჩქარის ტრენაჟორი RBAC-ზე: მოკლე დამოუკიდებელი დავალებები ServiceAccount-ზე,
Role/RoleBinding-ზე, ClusterRole/ClusterRoleBinding-ზე და ეფექტური უფლებების შემოწმება
`kubectl auth can-i`-ით. namespace `rbac` წინასწარ შექმნილია.

დავალებები გამოცდის სტილშია გაფორმებული და ავტომატურად შემოწმდება ბრძანებით
`check_result`. დრილის მიზანი თეორიის განხილვა არაა, არამედ სიჩქარე და კუნთოვანი მეხსიერება:
„ხელის მომარჯვება“ RBAC-ობიექტების იმპერატიულ შექმნაზე და გამოცდის ტემპში ჩაჯდომა.

## მიზანი

განამტკიცოთ კურსის თავების მასალა:

- [თავი 21. ServiceAccount; ავთენტიფიკაცია, ავტორიზაცია, admission](../../course/21/ge.md) — ServiceAccount, ჯაჭვი authn/authz/admission
- [თავი 38. RBAC: Role, ClusterRole და binding-ები](../../course/38/ge.md) — Role/ClusterRole, RoleBinding/ClusterRoleBinding, უფლებების შემოწმება `auth can-i`-ით

## რას ვაკეთებთ და რისთვის

| ბლოკი | ამოცანები | უნარი |
|-------|-----------|-------|
| **Namespace-ის დონის RBAC** | ServiceAccount `app-sa`, Role `pod-reader`, RoleBinding `read-pods` | უფლებები namespace-ის ფარგლებში Role + binding-ის მეშვეობით (თავი 38) |
| **კლასტერული RBAC** | ClusterRole `cr-viewer`, ClusterRoleBinding `crb-viewer` | წვდომა კლასტერულ რესურსებზე (nodes) ClusterRole-ის მეშვეობით (თავი 38) |
| **უფლებების შემოწმება** | `kubectl auth can-i` `app-sa`-სთვის | ServiceAccount-ის ეფექტური უფლებების სწრაფი ვალიდაცია (თავი 21) |

## ინფრასტრუქტურა

გარემო იშლება AWS-ში (`eu-central-1`) Terragrunt-ის მეშვეობით და შედგება:

| კომპონენტი | აღწერა                                                                          |
|------------|---------------------------------------------------------------------------------|
| `vpc`      | VPC `10.10.0.0/16` საჯარო ქვექსელებით                                           |
| `ssh-keys` | SSH-გასაღებები node-ებზე წვდომისთვის                                             |
| `k8s-1`    | Kubernetes `1.35.2` (kubeadm), CNI Calico, metrics-server, ერთკვანძიანი; namespace `rbac` წინასწარ შექმნილია |
| `worker`   | სამუშაო მანქანა `kubectl`-ით და `check_result`-ით                               |

ინსტანსები: `t4g.medium` (master), Ubuntu `22.04`. კლასტერი ერთკვანძიანია — master-ს
მოშორებულია taint `control-plane`, ამიტომ pod-ები პირდაპირ მასზე იგეგმება.

## განთავსება

```bash
TASK=121 make run_cka_task
```

შექმნის შემდეგ დაუკავშირდით სამუშაო მანქანას (worker) SSH-ით და დავალებები შეასრულეთ
იქიდან. `kubectl` უკვე კონფიგურირებულია კონტექსტზე `cluster1-admin@cluster1`.

სასარგებლო ბრძანებები სამუშაო მანქანაზე:

```bash
time_left       # რამდენი დრო დარჩა
check_result    # ამოხსნის შემოწმება
```

## დავალებები

---
|        **1**        | **ServiceAccount**                                          |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | შექმენით ServiceAccount `app-sa` namespace `rbac`-ში (`kubectl -n rbac create serviceaccount app-sa`). |
| მიღების კრიტერიუმები | - ServiceAccount `app-sa` არსებობს namespace `rbac`-ში. |
---
|        **2**        | **Role**                                                    |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | შექმენით Role `pod-reader` namespace `rbac`-ში უფლებებით `get,list,watch` რესურსზე `pods` (`kubectl -n rbac create role pod-reader --verb=get,list,watch --resource=pods`). |
| მიღების კრიტერიუმები | - Role `pod-reader` აძლევს `get`/`list`/`watch`-ს `pods`-ზე. |
---
|        **3**        | **RoleBinding**                                             |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | შექმენით RoleBinding `read-pods` namespace `rbac`-ში და დააკავშირეთ Role `pod-reader` სუბიექტთან ServiceAccount `app-sa` (`kubectl -n rbac create rolebinding read-pods --role=pod-reader --serviceaccount=rbac:app-sa`). |
| მიღების კრიტერიუმები | - RoleBinding `read-pods` მიუთითებს Role `pod-reader`-ზე და სუბიექტ `app-sa`-ზე. |
---
|        **4**        | **ClusterRole**                                             |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | შექმენით ClusterRole `cr-viewer` უფლებებით `get,list` კლასტერულ რესურსზე `nodes` (`kubectl create clusterrole cr-viewer --verb=get,list --resource=nodes`). |
| მიღების კრიტერიუმები | - ClusterRole `cr-viewer` აძლევს `get`/`list`-ს `nodes`-ზე. |
---
|        **5**        | **ClusterRoleBinding**                                      |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | შექმენით ClusterRoleBinding `crb-viewer` და დააკავშირეთ ClusterRole `cr-viewer` სუბიექტთან ServiceAccount `app-sa` namespace `rbac`-იდან (`kubectl create clusterrolebinding crb-viewer --clusterrole=cr-viewer --serviceaccount=rbac:app-sa`). |
| მიღების კრიტერიუმები | - ClusterRoleBinding `crb-viewer` მიუთითებს ClusterRole `cr-viewer`-ზე და სუბიექტ `rbac/app-sa`-ზე. |
---
|        **6**        | **უფლებების შემოწმება (auth can-i)**                        |
| :-----------------: | :----------------------------------------------------------- |
| რას ვაკეთებთ        | შეამოწმეთ `app-sa`-ის ეფექტური უფლებები `kubectl auth can-i ... --as=system:serviceaccount:rbac:app-sa`-ით: `get pods` `rbac`-ში, `get nodes` და `delete pods` `rbac`-ში. დარწმუნდით, რომ კავშირები კორექტულად გაცემულია. |
| მიღების კრიტერიუმები | - `get pods` namespace `rbac`-ში = `yes`;<br/>- `get nodes` = `yes`;<br/>- `delete pods` namespace `rbac`-ში = `no`. |
---

## შედეგის შემოწმება

სამუშაო მანქანაზე გაუშვით ავტომატური შემოწმება:

```bash
check_result
```

სკრიპტი გაატარებს ტესტებს და აჩვენებს, რამდენი დავალებაა შესრულებული.

## ამოხსნა

ეტალონური ამოხსნა: [worker/files/solutions/1_GE.MD](worker/files/solutions/1_GE.MD)

## Mock-გამოცდების დაფარვა

დომენი Cluster Architecture (RBAC) CKA-სთვის და Application Security CKAD-სთვის —
Role/ClusterRole-ისა და ServiceAccount-თან კავშირების გამეორებები.

## კლასტერისა და რესურსების წაშლა

```bash
TASK=121 make delete_cka_task
```
