[Русский](commands_RU.md) · [English](commands.md) · [Español](commands_ES.md) · [Français](commands_FR.md) · [Deutsch](commands_DE.md) · ქართული · [繁體中文](commands_TW.md) · [日本語](commands_JP.md) · [მთავარი გვერდი](../README_GE.MD)

<a id="commands"></a>

# ბრძანებების ცნობარი

ყველა ბრძანება რეპოზიტორიის ძირეულ დირექტორიაში შეასრულეთ. `TASK` არჩეული სამუშაოს ან საცდელი გამოცდის ნომერია. გაშვების, Terraform-ის შედეგების ნახვისა და წაშლისას გამოიყენეთ იგივე `TASK`, `USER_ID` და `ENV_ID`.

`_clean` დაბოლოების მქონე ბრძანებები ოპერაციამდე შესაბამისი გარემოს ლოკალურ დირექტორიას ასუფთავებს. ისინი ღრუბლოვანი რესურსების `delete_*`-ით წაშლას არ ცვლის.

<details>
<summary>CKA + CKAD: ლაბორატორიული სამუშაოები და CKA-ს საცდელი გამოცდები</summary>

CKA + CKAD-ის ერთობლივი კურსის კომპლექსური სამუშაოები `cka_task` ბრძანებებით ეშვება.

| ბრძანება | მოქმედება |
|---|---|
| `TASK=101 make run_cka_task` | შექმნა: [ლაბორატორიული სამუშაო CKA + CKAD 101](labs.MD#cka-labs) |
| `TASK=101 make delete_cka_task` | ლაბორატორიული გარემოს წაშლა |
| `TASK=101 make run_cka_task_clean` | სამუშაოს გაშვება გარემოს ლოკალური დირექტორიის გასუფთავების შემდეგ |
| `TASK=101 make output_cka_task` | Terraform-ის გამოტანილი მნიშვნელობების ნახვა |
| `TASK=01 make run_cka_mock` | შექმნა: [საცდელი გამოცდა CKA 01](../tasks/cka/mock/01) |
| `TASK=01 make delete_cka_mock` | საცდელი გამოცდის გარემოს წაშლა |
| `TASK=01 make run_cka_mock_clean` | გამოცდის გაშვება გარემოს ლოკალური დირექტორიის გასუფთავების შემდეგ |
| `TASK=01 make output_cka_mock` | Terraform-ის გამოტანილი მნიშვნელობების ნახვა |

</details>

<details>
<summary>CKAD: საცდელი გამოცდები</summary>

| ბრძანება | მოქმედება |
|---|---|
| `TASK=01 make run_ckad_mock` | შექმნა: [საცდელი გამოცდა CKAD 01](../tasks/ckad/mock/01) |
| `TASK=01 make delete_ckad_mock` | საცდელი გამოცდის გარემოს წაშლა |
| `TASK=01 make run_ckad_mock_clean` | გამოცდის გაშვება გარემოს ლოკალური დირექტორიის გასუფთავების შემდეგ |
| `TASK=01 make output_ckad_mock` | Terraform-ის გამოტანილი მნიშვნელობების ნახვა |

</details>

<details>
<summary>CKS: ლაბორატორიული სამუშაოები და საცდელი გამოცდები</summary>

| ბრძანება | მოქმედება |
|---|---|
| `TASK=101 make run_cks_task` | შექმნა: [ლაბორატორიული სამუშაო CKS 101](labs.MD#cks-labs) |
| `TASK=101 make delete_cks_task` | ლაბორატორიული გარემოს წაშლა |
| `TASK=101 make run_cks_task_clean` | სამუშაოს გაშვება გარემოს ლოკალური დირექტორიის გასუფთავების შემდეგ |
| `TASK=101 make output_cks_task` | Terraform-ის გამოტანილი მნიშვნელობების ნახვა |
| `TASK=01 make run_cks_mock` | შექმნა: [საცდელი გამოცდა CKS 01](../tasks/cks/mock/01) |
| `TASK=01 make delete_cks_mock` | საცდელი გამოცდის გარემოს წაშლა |
| `TASK=01 make run_cks_mock_clean` | გამოცდის გაშვება გარემოს ლოკალური დირექტორიის გასუფთავების შემდეგ |
| `TASK=01 make output_cks_mock` | Terraform-ის გამოტანილი მნიშვნელობების ნახვა |

</details>

<details>
<summary>Istio / ICA: ლაბორატორიული სამუშაოები და საცდელი გამოცდები</summary>

| ბრძანება | მოქმედება |
|---|---|
| `TASK=01 make run_ica_task` | შექმნა: [ლაბორატორიული სამუშაო ICA 01](labs.MD#ica-labs-istio-certified-associate) |
| `TASK=01 make delete_ica_task` | ლაბორატორიული გარემოს წაშლა |
| `TASK=01 make run_ica_task_clean` | სამუშაოს გაშვება გარემოს ლოკალური დირექტორიის გასუფთავების შემდეგ |
| `TASK=01 make output_ica_task` | Terraform-ის გამოტანილი მნიშვნელობების ნახვა |
| `TASK=01 make run_ica_mock` | შექმნა: [საცდელი გამოცდა ICA 01](../tasks/ica/mock/01) |
| `TASK=01 make delete_ica_mock` | საცდელი გამოცდის გარემოს წაშლა |
| `TASK=01 make run_ica_mock_clean` | გამოცდის გაშვება გარემოს ლოკალური დირექტორიის გასუფთავების შემდეგ |
| `TASK=01 make output_ica_mock` | Terraform-ის გამოტანილი მნიშვნელობების ნახვა |

</details>

<details>
<summary>Amazon EKS: ლაბორატორიული სამუშაოები</summary>

| ბრძანება | მოქმედება |
|---|---|
| `TASK=101 make run_eks_task` | შექმნა: [ლაბორატორიული სამუშაო EKS 101](labs.MD#eks-labs) |
| `TASK=101 make delete_eks_task` | ლაბორატორიული გარემოს წაშლა |
| `TASK=101 make run_eks_task_clean` | სამუშაოს გაშვება გარემოს ლოკალური დირექტორიის გასუფთავების შემდეგ |
| `TASK=101 make output_eks_task` | Terraform-ის გამოტანილი მნიშვნელობების ნახვა |

EKS გარემოს წაშლამდე შეასრულეთ სამუშაოს აღწერაში მითითებული წინასწარი გასუფთავება. ზოგი რესურსი Kubernetes-კონტროლერებით ან ხელით იქმნება და Terraform destroy-მდე უნდა წაიშალოს.

</details>

<details>
<summary>LFCS: საცდელი გამოცდები</summary>

| ბრძანება | მოქმედება |
|---|---|
| `TASK=01 make run_lfcs_mock` | შექმნა: [საცდელი გამოცდა LFCS 01](../tasks/lfcs/mock/01) |
| `TASK=01 make delete_lfcs_mock` | საცდელი გამოცდის გარემოს წაშლა |
| `TASK=01 make run_lfcs_mock_clean` | გამოცდის გაშვება გარემოს ლოკალური დირექტორიის გასუფთავების შემდეგ |
| `TASK=01 make delete_lfcs_mock_clean` | გამოცდის წაშლა გარემოს ლოკალური დირექტორიის გასუფთავების შემდეგ |
| `TASK=01 make output_lfcs_mock` | Terraform-ის გამოტანილი მნიშვნელობების ნახვა |

</details>

<details>
<summary>HR: პრაქტიკული სცენარები</summary>

| ბრძანება | მოქმედება |
|---|---|
| `TASK=01 make run_hr_mock` | შექმნა: [HR-სცენარი 01](../tasks/hr/mock/01) |
| `TASK=01 make delete_hr_mock` | სცენარის გარემოს წაშლა |
| `TASK=01 make run_hr_mock_clean` | სცენარის გაშვება გარემოს ლოკალური დირექტორიის გასუფთავების შემდეგ |
| `TASK=01 make output_hr_mock` | Terraform-ის გამოტანილი მნიშვნელობების ნახვა |

</details>

<details>
<summary>KCNA, KCSA და AWS Certified AI Practitioner: სატესტო მასალები</summary>

გახსენით შესაბამისი განყოფილება და მიჰყევით მის ინსტრუქციებს:

- [KCNA: საცდელი გამოცდა № 01](../tasks/kcna/mock/01/README.MD).
- [KCSA: კურსი, კითხვები და საცდელი გამოცდები](../tasks/kcsa/README_GE.md).
- [AWS Certified AI Practitioner: საცდელი გამოცდა № 01](../tasks/aws_AI_practitioner/mock/01/README.MD).

</details>

<details>
<summary>შემუშავება და შემოწმება</summary>

`make lint` - პროექტის გამართული შემოწმებების გაშვება pre-commit-ით.

</details>
