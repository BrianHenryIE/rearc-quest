# A quest in the clouds

* https://github.com/rearc/quest
* https://jobs.ashbyhq.com/rearc/660941f6-0f49-41cd-a783-2bc9f5293f26
* http://rearc-quest-ecs-alb-1303832094.us-west-1.elb.amazonaws.com

## Overview

This is mostly handwritten / Terraform Registry / Stack Overflow / blog post Terraform with a small amount by Claude. 
GitHub Copilot auto-complete was used when it was helpful but it was sometimes wrong. And Google / DuckDuckGo AI assist 
was also used. The Claude session is available: https://claude.ai/code/cshk_01EAQ7t34SYwXNFE8DaSMx1ZQuw11koUbKC1KA1Tjv8SFU (set to public).

I used IntelliJ/Webstorm with [Jetbrains Terraform and HCL plugin](https://plugins.jetbrains.com/plugin/7808-terraform-and-hcl)
and [TFState Viewer](https://plugins.jetbrains.com/plugin/34544-tfstate-viewer) (which did not come in handy).

PRs were written by Claude, following instructions in CLAUDE.md.

This README is not a step-by-step guide, but just shows parts of what I did, how I did it, and how I verified it.
E.g. `git commit` and `terraform apply` are mostly omitted.

## Implementation

### 1. Git Setup

In bash:
```bash
git init
touch .gitignore
gh repo create rearc-quest --private --push --source=.
git submodule add https://github.com/rearc/quest rearc-quest
```
In Claude
```
/install-github-app
```
https://github.com/BrianHenryIE/rearc-quest/pull/1

`npm start` worked but loading anything at `localhost:3000` failed because of architecture.

Running it locally through Docker worked:

```bash
docker run --rm -it --platform linux/amd64 -p 3000:3000 \
 -v "$PWD":/app -w /app node:20 sh -c "npm install && npm start"
```

I asked Claude to:
```
* Add a GitHub Actions workflow that runs on every push to a PR for testing the Git Submodule. I.e. `docker run --rm -it --platform linux/amd64 -p 3000:3000 -v "$PWD":/app -w /app node:20 sh -c "npm install && npm start"` then the output of `curl http://localhost:3000` should be "You don't seem to be running in AWS or GCP or Azure"
* Change the action to test localhost:3000/docker
```

The latter because Claude said:
> GitHub’s hosted runners are Azure VMs.

[Initial runs](https://github.com/BrianHenryIE/rearc-quest/actions/runs/41558117096/job/125661880743?pr=2) of Claude 
Code review workflow did not add any comment to the PR, so I asked Claude to fix that: 

https://github.com/BrianHenryIE/rearc-quest/pull/2

#### Notes

When checking out the repo, install the submodule with:
`git submodule update --init --recursive`

To see the submodule commit, run:
`git rev-parse main:rearc-quest`
I.e.
```
open https://github.com/rearc/quest/tree/$(git rev-parse main:rearc-quest)
```

#### Given more time, I would improve...

* We should protect main branch from direct push (i.e. require pull requests) but I'm working in a free GitHub account currently as a private repo where that feature is not possible.

### 2. Infrastructure as Code Setup

I wrote the Terraform code which is mostly a `aws_instance` with a public `aws_security_group` for port 3000 and a
private `aws_security_group` for port 22 access inside AWS, i.e. to use the SSH terminal in AWS Console.

I then asked Claude to review the `aws_instance`.`user_data` script, [`2-terraform-ec2/install.sh`](https://github.com/BrianHenryIE/rearc-quest/blob/main/2-terraform-ec2/install.sh),
which it rewrote to fix mismatch Ubuntu/Amazon Linux AMI commands and to use a service.

After `terraform init` and `terraform apply`, running:
```
curl http://$(terraform output -raw public_ip):3000/aws` 
````
> Congratulations! You are running in AWS...

I was going to add a variable to distinguish between test/staging/production but when I asked Claude to add a GitHub 
Actions workflow to run automated tests on pushes to PRs, it instead used a Terraform workspace.

It also set up the [`0-github-actions-oidc`](https://github.com/BrianHenryIE/rearc-quest/tree/main/0-github-actions-oidc) 
directory to handle authentication inside GitHub Actions. This is the only Terraform code that was primarily written by 
Claude.

https://github.com/BrianHenryIE/rearc-quest/pull/3

#### Notes

* For displaying the instances:
```
aws ec2 describe-instances --region us-west-1 \
--query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType,PublicIpAddress,Tags[?Key==`Name`]|[0].Value]' \
--output table
```
* AWS does not _instantly_ delete terminated instances, they remain visible in the console for roughly one hour before completely disappearing.

#### Given more time, I would improve...

* After manually deleting resources in AWS (when the later steps were stalling) `terraform apply` is not working for this configuration.
> Error: creating EC2 Instance: operation error EC2: RunInstances, https response error StatusCode: 400, RequestID: eacdbe30-9025-4912-bd81-5560bfc676b9, api error MissingInput: No subnets found for the default VPC 'vpc-0193e316110c9c0eb'. Please specify a subnet.

### 3. Public Cloud Setup

### 3.1 Building the Docker image locally

Using just Docker, I wrote the Dockerfile and confirmed it worked locally.

```
mkdir 3-container
touch 3-container/Dockerfile

# Wrote the Dockerfile

docker build . -f ./3-container/Dockerfile -t "rearc-quest"

# List the image in the local Docker registry
# There is no way to `ls` an individual image in macOS
docker images "rearc*"

docker run -p 3000:3000 rearc-quest:latest

curl localhost:3000/docker
```

> Congratulations! You are running in a Docker container

### 3.1 Building the Docker image with Terraform

Using `kreuzwerker/docker` I built the `docker_image` ([3226c44](https://github.com/BrianHenryIE/rearc-quest/commit/3226c441974959b5fff9d913b7cc68da048d96be))

```
# First, delete the existing local image so we can confirm Terraform is in fact building it
docker image remove "rearc-quest:latest"

# Copied some of the earlier Terraform code
cp 2-terraform-ec2/{provider.tf,variables.tf,version.tf} 3-container

touch 3-container/{docker.tf,ecr.tf,main.tf,outputs.tf}

# Wrote the Docker build code.

terraform init -upgrade
terraform apply

docker images "rearc*"
```

And the local image was shown:

```
i Info →   U  In Use
IMAGE                ID             DISK USAGE   CONTENT SIZE   EXTRA
rearc-quest:latest   4ba97298fd51       1.34GB          350MB    U   
```

### 3.1 Publishing the Docker image on Elastic Container Registry

Then I pushed to `aws_ecr_repository` with `docker_registry_image`  ([104259b](https://github.com/BrianHenryIE/rearc-quest/commit/104259bf201cf0c85d55f63b67a02c2a9e6e3449)).

```
aws ecr list-images --repository-name=rearc-quest
```

Which displayed JSON with `imageIds` and `imageDigest` SHAs.

https://github.com/BrianHenryIE/rearc-quest/pull/4

#### Given more time, I would improve...

* Add a GitHub Actions workflow testing PR pushes do not break anything
* I had to run terraform apply twice here, I should figure out why
> Error: Error pushing docker image: Error pushing image. . Full error: error from registry: The repository with name 'rearc-quest' does not exist in the registry with id '520658182982'
* Add lifecycle policy for images – keep the latest and previous for rollback, don't keep everything!
* NB: add terraform.tfstate* to .gitignore, and use a remote backend or a sanitized state. Also remove these files from the PR. If a token is still unexpired, revoke the access.
* Conditionally build the docker image based on changes. I think this involves sharing all the relevant files and including that sha in the name/metadata of the saved container

### 3.1 Deploying the Docker image on Elastic Container Service
### 6. Deploy a load balancer in front of the app.

This was the longest part. It made sense to just go straight to ECS with a load balancer. I have written the code 
before at work but don't have that available to reference, so I found myself reading the following helpful blog post:
https://spacelift.io/blog/terraform-ecs

Eventually:

```
curl $(terraform output -raw alb_dns_name)/loadbalanced
```
> Congratulations! Looks like you successfully configured an AWS loadbalancer

https://github.com/BrianHenryIE/rearc-quest/pull/5

### 6.1 Add NAT Gateway

At this stage, the instances did not have egress:

```
curl $(terraform output -raw alb_dns_name)
```
was returning:
> panic: Get "https://www.rearc.io/quest001001222/": dial tcp 13.249.74.37:443: i/o timeout goroutine 1 [running]: main.main() /app/github_src/go_quest_src/src/001.go:18 +0x3a5

Rather than fix it immediately, I decided to move on to the remaining steps and returned to this later. 

When I did, I leaned on Claude more than in most other steps and Claude moved the `aws_ecs_service` `aws_autoscaling_group` 
to private subnet, added `aws_nat_gateway` using `aws_eip` on the public subnet for `us-west-1a`.

https://github.com/BrianHenryIE/rearc-quest/pull/8

#### Notes

* I had trouble with `terraform destroy` and ended up manually deleting a lot

#### Given more time, I would improve...

* I should add a diagram for this step
* This step needs a bit more review

### 4. Obtaining the Secret Word

By querying the rearc.io URL from the error message directly:
```
curl https://www.rearc.io/quest001001222
```
> OurFault*

or after the NAT gateway was added:
```
curl $(terraform output -raw alb_dns_name)
```
> OurFault*

And IIRC it is also displayed when querying the Terraform defined in `2-terraform-ec2`.

### 5. Injecting the Secret Word into the Docker container

### 5.1. Secret Word Locally

Locally, I can run the container with the environment variable:

```
docker run -p 3000:3000 -e SECRET_WORD=OurFault rearc-quest:latest

curl localhost:3000/secret_word          
```
> Congratulations. Secret word is:  OurFault

### 5.2. Secret Word in Terraform

I added a variable, `secret_word` and referenced it in `aws_ecs_task_definition` `container_definitions`.`environment`.

```
export TF_VAR_secret_word=OurFault

terraform apply -replace=docker_image.rearc_quest_docker_image

curl $(terraform output -raw alb_dns_name)/secret_word
```
> Congratulations. Secret word is:  OurFault

But it is being committed in the state file:

```
cat terraform.tfstate | jq '.resources.[] | select(.name == "ecs_task_definition") | .instances[0].attributes.container_definitions' | jq 'fromjson .[0].environment'
```
```json
[
  {
    "name": "SECRET_WORD",
    "value": "OurFault"
  }
]
```
And is stored unencrypted in the task definition and can be read in AWS Console!

https://github.com/BrianHenryIE/rearc-quest/pull/6/

#### Given more time, I would improve...

* Use AWS Secrets Manager
* Set the value in CI so it is not in the state file
* Store the state file in S3 with encryption and versioning (as Terraform remote backend)
* I noticed that the ECS instances were creating 30GB block stores for Volumes, probably the default and we do need _something_ for the image to run on, but it could be reduced

### 7. Add TLS

I added `hashicorp/tls` then I created a private key with `tls_private_key` and from it I created a self-signed 
certificate with `tls_self_signed_cert`. I was able to reference `aws_lb.rearc_quest_ecs_alb.dns_name` for the `common_name`
(domain). I added a new `aws_lb_listener` on port 443 and provided the `certificate_arn`. Then running:

```
curl --insecure https://$(terraform output -raw alb_dns_name)/tls
```
> Congratulations! Looks like you successfully configured TLS (https)

https://github.com/BrianHenryIE/rearc-quest/pull/7/

## Finally

```
terraform destroy
```