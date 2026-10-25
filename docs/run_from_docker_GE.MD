[Русский](run_from_docker_RU.MD) · [English](run_from_docker.MD) · [Español](run_from_docker_ES.MD) · [Français](run_from_docker_FR.MD) · [Deutsch](run_from_docker_DE.MD) · ქართული · [繁體中文](run_from_docker_TW.MD) · [日本語](run_from_docker_JP.MD) · [მთავარი გვერდი](../README_GE.MD)

# სწრაფი დაწყება Docker-ით

მომზადებული Docker image შეიცავს დამოკიდებულებებსა და ხელსაწყოებს პრაქტიკული ლაბორატორიული სამუშაოებისა და საცდელი გამოცდების გასაშვებად. ქვემოთ მოცემული მაგალითი CKA-ს საცდელ გამოცდას № 01 უშვებს.

[ვიდეოინსტრუქცია](https://youtu.be/Xh6sWzafBmw)

## 1. გაუშვით კონტეინერი

კომპიუტერზე, სადაც Docker დაყენებულია, შეასრულეთ:

```bash
sudo docker run -it viktoruj/runner
```

ყველა შემდეგი ბრძანება კონტეინერის შიგნით შეასრულეთ.

## 2. დააკლონეთ რეპოზიტორია

```bash
git clone https://github.com/ViktorUJ/cks.git
cd cks
```

## 3. დააყენეთ Terraform-ის მდგომარეობის შენახვა

გახსენით [terraform/environments/terragrunt.hcl](../terraform/environments/terragrunt.hcl). `backend_bucket` შეცვალეთ თქვენი საკუთარი S3 bucket-ის სახელით, სადაც Terraform-ის მდგომარეობა შეინახება. საჭიროების შემთხვევაში შეცვალეთ ინფრასტრუქტურის რეგიონი `region` და მდგომარეობის შენახვის რეგიონი `backend_region`:

```hcl
locals {
  region                 = "eu-north-1"
  backend_region         = "eu-north-1"
  backend_bucket         = "your-platform-state-bucket"
  backend_dynamodb_table = "${local.backend_bucket}-lock"
}
```

ასევე შეამოწმეთ არჩეული სცენარის `env.hcl` ფაილში მითითებული რეგიონი და პარამეტრები.

## 4. დააყენეთ AWS-ზე წვდომა

მაგალითის მნიშვნელობები თქვენი საკუთარი წვდომის გასაღებებით შეცვალეთ:

```bash
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY
```

დროებითი ავტორიზაციის მონაცემების გამოყენებისას ასევე მიუთითეთ `AWS_SESSION_TOKEN`.

## 5. შეამოწმეთ AWS-ის კვოტები

გარემოს შეიძლება რამდენიმე EC2 instance დასჭირდეს. AWS-ის კონსოლში გახსენით **Service Quotas → AWS services → Amazon Elastic Compute Cloud (Amazon EC2)** და შეამოწმეთ გამოყენებული რეგიონისა და instance-ების ოჯახის კვოტები:

- **Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances** On-Demand-ისთვის.
- **All Standard (A, C, D, H, I, M, R, T, Z) Spot Instance Requests** Spot-ისთვის.

ეს კვოტები vCPU-ებით იზომება და არა instance-ების რაოდენობით. თუ ხელმისაწვდომი კვოტა არჩეული სცენარისთვის საკმარისი არ არის, მოითხოვეთ მისი გაზრდა. სხვა instance-ების ოჯახებისთვის შესაბამისი კვოტები შეამოწმეთ.

## 6. გაუშვით სცენარი

ერთი გარემოსთვის:

```bash
TASK=01 make run_cka_mock
```

კონკრეტული მომხმარებლისთვის ან რამდენიმე დამოუკიდებელი გარემოსთვის:

```bash
USER_ID='user1' ENV_ID='01' TASK=01 make run_cka_mock
```

Terraform-ის გამოტანილი მონაცემებით დაუკავშირდით სამუშაო მანქანას და მიჰყევით [გამოცდის აღწერას](../tasks/cka/mock/01/README.MD).

სხვა სამუშაოსთვის მიმართულება და ნომერი აირჩიეთ [ლაბორატორიული სამუშაოების კატალოგში](labs.MD) ან [მთავარ გვერდზე](../README_GE.MD). გაშვების ბრძანებები მოცემულია [ბრძანებების ცნობარში](commands_GE.md).

## 7. სამუშაოს დასრულების შემდეგ წაშალეთ გარემო

შექმნილი რესურსების საფასური თქვენს AWS ანგარიშს ერიცხება. შეასრულეთ სცენარის README-ში მითითებული წინასწარი გასუფთავება და შემდეგ წაშალეთ გარემო.

ერთი გარემოსთვის:

```bash
TASK=01 make delete_cka_mock
```

კონკრეტული მომხმარებლის გარემოსთვის:

```bash
USER_ID='user1' ENV_ID='01' TASK=01 make delete_cka_mock
```

გამოიყენეთ `TASK`, `USER_ID` და `ENV_ID` ცვლადების იგივე მნიშვნელობები, რომლებითაც სცენარი გაუშვით.

[დამოუკიდებელი გარემოები და CMDB](environments_GE.md) · [გამოყენების სცენარები](usage_scenarios_GE.md)
