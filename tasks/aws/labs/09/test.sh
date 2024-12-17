#!/bin/bash
git clone https://github.com/ViktorUJ/terraform-aws-vpc.git
cd terraform-aws-vpc/examples/simple
terraform init

curl -e "sysadminas.eu" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36" https://github.com/ViktorUJ/terraform-aws-vpc/tree/master/examples/custom >/dev/null
sleep 1
curl -e "https://www.google.com/" -H "User-Agent: Mozilla/5.0 (Macintosh; ARM64 Mac OS X 15_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Safari/605.1.15" https://github.com/ViktorUJ/terraform-aws-vpc/tree/master/examples/nat_gateway_subnet >/dev/null

cd /tmp/
git clone https://github.com/ViktorUJ/terraform-aws-vpc.git
cd terraform-aws-vpc/examples/simple
terraform init

curl -e "linkedin.com" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36" https://github.com/ViktorUJ/terraform-aws-vpc/tree/master/examples/nat_gateway_subnet >/dev/null
sleep 1
curl -e "google.com" -H "User-Agent: Mozilla/5.0 (Macintosh; ARM64 Mac OS X 15_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Safari/605.1.15" https://github.com/ViktorUJ/terraform-aws-vpc/tree/master/examples/output_private_subnet_by_type >/dev/null

cd /tmp/
rm -rf terraform-aws-vpc
git clone https://github.com/ViktorUJ/terraform-aws-vpc.git
cd terraform-aws-vpc/examples/simple
terraform init

curl -e "com.linkedin.android" -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36" https://github.com/ViktorUJ/terraform-aws-vpc/tree/master/examples/nacl_subnet >/dev/null
sleep 1
curl -e "youtube.com" -H "User-Agent: Mozilla/5.0 (Macintosh; ARM64 Mac OS X 15_1) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.1 Safari/605.1.15" https://github.com/ViktorUJ/terraform-aws-vpc/blob/master/examples/simple/main.tf >/dev/null
