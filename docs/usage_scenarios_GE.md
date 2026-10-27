[Русский](usage_scenarios_RU.md) · [English](usage_scenarios.md) · [Español](usage_scenarios_ES.md) · [Français](usage_scenarios_FR.md) · [Deutsch](usage_scenarios_DE.md) · ქართული · [繁體中文](usage_scenarios_TW.md) · [日本語](usage_scenarios_JP.md) · [მთავარი გვერდი](../README_GE.MD)

<a id="usage"></a>

# გამოყენების სცენარები და ვიდეოები

<details>
<summary>CKA + CKAD-ისა და CKS-ის სამუშაოები: გაშვებიდან შემოწმებამდე</summary>

1. აირჩიეთ სამუშაო [კატალოგში](labs.MD) და წაიკითხეთ აღწერა: `tasks/cka/labs/<number>/README_GE.MD` ან `tasks/cks/labs/<number>/README_GE.MD` ნათარგმნი სამუშაოებისთვის.
2. შეამოწმეთ `env.hcl`: რეგიონი, instance-ების ტიპები და პარამეტრები. ხელით მითითებული `ami_id` რეგიონისა და არქიტექტურის შესაბამისი უნდა იყოს; ავტომატური შერჩევისას მიჰყევით სცენარის პარამეტრებს.
3. შექმენით გარემო: `TASK=101 make run_cka_task` ან `TASK=101 make run_cks_task`.
4. Terraform-ის შედეგებში იპოვეთ SSH-ბრძანება. კომპლექსური სამუშაოები ჩვეულებრივ `worker` მანქანაზე იწყება, ზოგი სცენარი კი control plane-ის ნოდზე. გამოიყენეთ კონკრეტული სცენარის `worker_pc_ip`, `master_external_ip` ან მზა დაკავშირების ბრძანება.
5. დაუკავშირდით `ubuntu` მომხმარებლით. გასაღებისთვის გამოიყენეთ `ssh ubuntu@<IP> -i <key_path>`; თუ გარემო პაროლს აჩვენებს, დაუკავშირდით `ssh ubuntu@<IP>`-ით და მოთხოვნისას შეიყვანეთ პაროლი.
6. საჭიროების შემთხვევაში შეამოწმეთ დაყენების დასრულება შესაბამის მანქანაზე: `tail -f /var/log/cloud-init-output.log`.
7. შეასრულეთ დავალებები. კომპლექსურ სამუშაოებში სამუშაო მანქანაზე გაუშვით `check_result` და აღწერილ შემოწმების მეთოდს მიჰყევით.
8. განიხილეთ ეტალონური გადაწყვეტა. სამუშაო 101-ისთვის: [CKA + CKAD](../tasks/cka/labs/101/worker/files/solutions/1_GE.MD) და [CKS](../tasks/cks/labs/101/worker/files/solutions/1_GE.MD). სხვაგან მდებარეობა შეიძლება განსხვავდებოდეს; გამოიყენეთ კატალოგის ან აღწერის ბმული.
9. შეასრულეთ წაშლის განყოფილების წინასწარი გასუფთავება და წაშალეთ გარემო: `TASK=101 make delete_cka_task` ან `TASK=101 make delete_cks_task`.

ლოკალური დირექტორიის გასუფთავებით ხელახლა გაშვებისთვის გამოიყენეთ `run_cka_task_clean` ან `run_cks_task_clean`. ღრუბლოვანი რესურსები `delete_*` ბრძანებებით იშლება.

</details>

<details>
<summary>CKA, CKAD, CKS, ICA და HR პრაქტიკული საცდელი გამოცდები</summary>

საერთო თანმიმდევრობა:

1. აირჩიეთ გამოცდის ნომერი და გახსენით README `tasks/<track>/mock/<number>/`-ში.
2. საჭიროებისას შეცვალეთ `env.hcl`-ის გათვალისწინებული პარამეტრები: ოპერაციული სისტემა (`ubuntu_version`), EC2-ის შეძენის რეჟიმი (`spot` ან `ondemand`) და instance-ების ტიპები.
3. გაუშვით `TASK=<number> make run_<track>_mock`. ლოკალური დირექტორიის გასუფთავებით გაშვებისთვის გამოიყენეთ `run_<track>_mock_clean`.
4. Terraform-ის შედეგებში იპოვეთ `worker_pc_ip` ან SSH-ბრძანება და დაუკავშირდით სამუშაო მანქანას `ubuntu` მომხმარებლით, შესაბამისი გასაღებით ან პაროლით.
5. გახსენით დავალებები და იმუშავეთ სამუშაო მანქანიდან. ნოდზე გადასასვლელად გამოიყენეთ `ssh <node_name>` გამოცდის აღწერის მიხედვით.
6. დარჩენილი დრო შეამოწმეთ `time_left`-ით, შედეგი კი `check_result`-ით, თუ გარემო მათ ითვალისწინებს.
7. მცდელობის შემდეგ განიხილეთ ქვემოთ მოცემული გადაწყვეტები და ტესტები.
8. წაშალეთ გარემო `TASK=<number> make delete_<track>_mock` ბრძანებით.

| მიმართულება | გამოცდა 01-ის დავალებები | გადაწყვეტები | ავტომატური შემოწმებები |
|---|---|---|---|
| CKA | [აღწერა](../tasks/cka/mock/01) | [გადაწყვეტები](../tasks/cka/mock/01/worker/files/solutions) | [tests.bats](../tasks/cka/mock/01/worker/files/tests.bats) |
| CKAD | [აღწერა](../tasks/ckad/mock/01) | [გადაწყვეტები](../tasks/ckad/mock/01/worker/files/solutions) | [tests.bats](../tasks/ckad/mock/01/worker/files/tests.bats) |
| CKS | [აღწერა](../tasks/cks/mock/01) | [გადაწყვეტები](../tasks/cks/mock/01/worker/files/solutions) | [tests.bats](../tasks/cks/mock/01/worker/files/tests.bats) |
| ICA | [აღწერა](../tasks/ica/mock/01) | [გადაწყვეტები](../tasks/ica/mock/01/worker/files/solutions) | [ტესტების დირექტორია](../tasks/ica/mock/01/worker/files/tests) |
| HR | [აღწერა](../tasks/hr/mock/01) | [გადაწყვეტები](../tasks/hr/mock/01/worker/files/solutions) | [tests.bats](../tasks/hr/mock/01/worker/files/tests.bats) |

ვიდეოინსტრუქციები და განხილვები:

- CKA: [საცდელი გამოცდის გაშვება](https://www.youtube.com/watch?v=P-YYX4CTWIg), [გამოცდა 01-ის გადაწყვეტები](https://youtu.be/IZsqAPpbBxM).
- CKS: [საცდელი გამოცდის გაშვება](https://youtu.be/_GbsBOMaJ9Q), [გადაწყვეტების განხილვა](https://youtu.be/I8CPwcGbrG8).
- CKAD: [საცდელი გამოცდის გაშვება](https://youtu.be/7X4Y9QhbTsk), [გადაწყვეტების განხილვა](https://youtu.be/yQK7Ca8d-yw).
- HR: [სცენარის ვიდეო](https://youtu.be/4CTC1jl8lxE).

</details>

<details>
<summary>Amazon EKS: ლაბორატორიული სამუშაოს გავლა</summary>

1. აირჩიეთ ნომერი [EKS-ის კატალოგში](labs.MD#eks-labs) და წაიკითხეთ აღწერა.
2. შეამოწმეთ `env.hcl` და გაუშვით `TASK=101 make run_eks_task` არჩეული სამუშაოს ნომრით.
3. Terraform-ის შედეგებში იპოვეთ `worker_pc_ip` ან SSH-ბრძანება. დაუკავშირდით `ubuntu` მომხმარებლით, გასაღებით ან პაროლით აღწერის მიხედვით.
4. შეასრულეთ დავალებები და შეამოწმეთ შედეგი. კომპლექსურ სამუშაოებში ხელმისაწვდომია `check_result`.
5. განიხილეთ აღწერაში ან კატალოგში მოცემული გადაწყვეტა, მაგალითად [სამუშაო 101-ის გადაწყვეტა](../tasks/eks/labs/101/worker/files/solutions/1_GE.MD).
6. შეასრულეთ წაშლის განყოფილების წინასწარი გასუფთავება და გაუშვით `TASK=101 make delete_eks_task` შესაბამისი ნომრით.

</details>

სხვა სცენარები: [Istio / ICA-ს სამუშაოები](../tasks/ica/README_GE.MD), [LFCS-ის საცდელი გამოცდა № 01](../tasks/lfcs/mock/01), [KCSA-ს სატესტო მასალები](../tasks/kcsa/README_GE.md), [KCNA-ს საცდელი გამოცდა № 01](../tasks/kcna/mock/01/README.MD), [AWS Certified AI Practitioner-ის საცდელი გამოცდა № 01](../tasks/aws_AI_practitioner/mock/01/README.MD).
