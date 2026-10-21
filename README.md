# Three-Tier DevSecOps Project on AWS: Beginner Guide (about 2 hours)

This guide is customised for:

| Item | Value |
|---|---|
| GitHub user | `shravani-dhaktode` |
| GitHub repo | `https://github.com/shravani-dhaktode/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project` (branch `master`) |
| AWS account | `747456040606` |
| AWS region | `us-east-1` (N. Virginia) |
| EC2 key pair name | `project` (your file is `project.pem`) |
| Domain | none. You'll use the load balancer address instead |

## What you are building

```
You push code ──► Jenkins (on an EC2 server)
                    ├─ SonarQube code scan (first build only)
                    ├─ Trivy security scan
                    ├─ docker build ──► push image to Amazon ECR
                    └─ updates image tag in GitHub
                                   │
GitHub repo ◄──────────────────────┘
     │  ArgoCD watches the repo
     ▼
Amazon EKS (Kubernetes) ──► Frontend (React) + Backend (Node.js) + MongoDB
     ▲
Internet ──► AWS Application Load Balancer
```

## What is automatic and what you do by hand

| Created automatically | Tool |
|---|---|
| VPC, subnet, security group, IAM role, Jenkins EC2 server | Terraform |
| ECR repositories `frontend` and `backend` | Terraform |
| Jenkins, Docker, SonarQube, AWS CLI, kubectl, eksctl, Helm, Trivy, Node.js | `tools-install.sh` (runs on first boot) |
| EKS cluster, Load Balancer Controller, ArgoCD | `scripts/1-create-eks.sh` |
| Deploying the app | `scripts/2-deploy-app.sh` + ArgoCD |
| Deleting everything | `scripts/3-cleanup.sh` + `terraform destroy` |

By hand you only do these things: create a GitHub token, click through the Jenkins and SonarQube setup screens, and press **Build**.

## Cost (read this first)

This is **not free**. If you finish in about 2–3 hours and run the cleanup, it costs about **US $1–3**.

| Item | Approx. cost |
|---|---|
| EKS control plane | $0.10 / hour |
| Jenkins server t3.large | $0.083 / hour |
| 2 × t3.medium Spot worker nodes | ~$0.03 / hour |
| NAT gateway (made by eksctl) | $0.045 / hour |
| 2 load balancers (app + ArgoCD) | ~$0.05 / hour |

> ⚠️ **If you forget Part 14 (cleanup), it keeps charging about $0.30/hour (about $220/month).**

### Your plan: practise now, show the examiner later

| Phase | What you do | Time |
|---|---|---|
| **Today: practise** | Parts 1–13 (full setup, once) | ~2 hours |
| **Today: pause** | Part 14A deletes the Kubernetes cluster and **stops** (doesn't delete) the Jenkins server | ~15 min |
| **While paused** | Jenkins, SonarQube results, credentials, pipelines, images and GitHub history are **all kept** | ~US $2.50/month |
| **Exam day: resume** | Part 15 starts the server, recreates the cluster and redeploys | ~40 min (start 1 hour before the exam) |
| **After the exam** | Part 14B deletes everything for good | ~20 min |

---

## Timeline

| Part | What | Time |
|---|---|---|
| 1 | Prepare AWS account | 10 min |
| 2 | GitHub token | 5 min |
| 3 | Upload code to GitHub (CloudShell) | 10 min |
| 4 | Create Jenkins server (Terraform) | 5 min (+8 min auto-install) |
| 5 | Connect to the server | 5 min |
| 6 | Start EKS creation (runs 25 min in background) | 2 min |
| 7–9 | Jenkins + SonarQube setup | 20 min |
| 10 | Run the two pipelines | 20 min |
| 11–12 | Deploy the app and open it | 10 min |
| 14 | Delete everything | 20 min |

---

## PART 1: Prepare your AWS account (10 min)

**1.1 Sign in.** Go to https://console.aws.amazon.com and sign in.

**1.2 Pick the region.** In the top-right corner, click the region name and choose **US East (N. Virginia) us-east-1**. Every step happens in this region.

**1.3 Set a budget alarm (safety net).**
1. In the top search bar type **Budgets** and open **AWS Budgets**.
2. Click **Create budget**, choose **Use a template**, then **Monthly cost budget**.
3. Set the amount to `10` (USD), enter your email, and click **Create budget**.

**1.4 Check your key pair.**
1. Search **EC2**, open it, and in the left menu click **Key Pairs**.
2. You should see a key named **`project`**. The name has no `.pem` on the end.
3. If it is not there, click **Create key pair**. Set Name to `project`, Type to RSA, and Format to `.pem`, then click **Create**. Keep the downloaded file safe.

**1.5 Free plan accounts.** If a later step fails with an error that mentions your *account plan* or *free plan*, open **Billing → Account plan** (or the banner at the top) and click **Upgrade to paid plan**. Any free credits you have are still used first.

---

## PART 2: Create a GitHub token (5 min)

Jenkins needs this token to push the new image version into your repo.

1. Go to https://github.com/settings/tokens. You must be logged in as `shravani-dhaktode`.
2. Click **Generate new token**, then **Generate new token (classic)**.
3. Set Note to `jenkins`. For **Expiration**, pick **Custom** and choose a date **a few days after your exam**. Then tick the **`repo`** box.
   (If the token expires before the exam, the pipeline's last stage fails.)
4. Click **Generate token**. **Copy the token (it starts with `ghp_`) into Notepad.** GitHub only shows it once.

---

## PART 3: Put the updated code into your GitHub repo (10 min)

You'll use **AWS CloudShell**, a free terminal inside the AWS website, so you don't install anything on your laptop.

1. In the AWS console top bar, click the **CloudShell icon** (a `>_` square), or search "CloudShell". Wait about 30 seconds for the terminal to load.
2. In CloudShell click **Actions → Upload file** and pick **`three-tier-project-updated.zip`**.
3. Copy and paste these commands. You can paste the whole block at once.

```bash
cd ~
git clone https://github.com/shravani-dhaktode/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project.git
unzip -o -q three-tier-project-updated.zip -d ~/updated
cp -r ~/updated/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project-master/. ~/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project/
rm -rf ~/updated
cd ~/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project
git config user.name "shravani-dhaktode"
git config user.email "shravanidhaktode46@gmail.com"
git add -A
git commit -m "Customize project for my AWS account"
git push origin master
```

4. When asked:
   - **Username:** `shravani-dhaktode`
   - **Password:** paste your **GitHub token** from Part 2. Nothing appears on screen while you paste; that's normal. Press Enter.
5. Open your repo on GitHub and refresh. You should see a `scripts/` folder and an `argocd/` folder.

---

## PART 4: Create the Jenkins server with Terraform (5 min + 8 min wait)

Still in CloudShell. First install Terraform. This takes about 10 seconds.

```bash
mkdir -p ~/bin
ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
curl -sLo /tmp/tf.zip "https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_${ARCH}.zip"
unzip -o -q /tmp/tf.zip -d ~/bin
export PATH=$HOME/bin:$PATH
terraform -version
```

Then create everything:

```bash
cd ~/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project/Jenkins-Server-TF
export TF_DATA_DIR=/tmp/tfdata
terraform init
terraform apply -var-file=variables.tfvars -auto-approve
```

> **Why `TF_DATA_DIR`?** CloudShell only gives you 1 GB of storage. Terraform's AWS plugin is big, so it goes to `/tmp`. Your **state file** (Terraform's memory of what it created) still stays safely in this folder, and you need it to delete everything later.

After about 2 minutes you'll see **Outputs**, for example:

```
jenkins_url   = "http://54.12.34.56:8080"
sonarqube_url = "http://54.12.34.56:9000"
```

**Copy these into Notepad.** The server now spends about **8–10 minutes** installing tools by itself.

---

## PART 5: Connect to the Jenkins server (5 min)

You don't need the `.pem` file or PuTTY. You can connect from the browser.

1. AWS console → **EC2 → Instances**. Tick **Jenkins-server**.
2. Click **Connect** (top right), open the **EC2 Instance Connect** tab, check that Username is `ubuntu`, and click **Connect**.
3. A black terminal opens. Check whether the tool install has finished:

```bash
ls ~/SETUP_DONE
```

- If it says **No such file**, it's still installing. Watch progress with `sudo tail -f /var/log/tools-install.log`. Press **Ctrl + C** to stop watching. Wait until `ls ~/SETUP_DONE` shows the file.
- When it's done, check the tools:

```bash
docker ps            # should show the "sonar" container
aws --version
kubectl version --client
eksctl version
trivy --version
```

> If the browser terminal disconnects (it times out when idle), click **Connect** again. Anything started with `nohup` keeps running.

---

## PART 6: Start creating the Kubernetes cluster (2 min, then it runs 25 min by itself)

In the same Instance Connect terminal:

```bash
cd ~
git clone https://github.com/shravani-dhaktode/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project.git
cd End-to-End-Kubernetes-Three-Tier-DevSecOps-Project
nohup bash scripts/1-create-eks.sh > ~/eks-setup.log 2>&1 &
tail -f ~/eks-setup.log
```

This creates the EKS cluster, installs the AWS Load Balancer Controller, and installs ArgoCD. **Don't wait for it.** Press **Ctrl + C** to stop watching. The job keeps running. Continue with Part 7 now.

---

## PART 7: Set up Jenkins (10 min)

1. In your browser, open **`http://<JENKINS-IP>:8080`** (your `jenkins_url`).
2. Jenkins asks for an **Administrator password**. In the server terminal, run:
   ```bash
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   ```
   Copy the long code, paste it into Jenkins, and click **Continue**.
3. Click **Install suggested plugins** and wait 3–5 minutes.
4. Create the first admin user. Pick any username and password (write them down). Click **Save and Continue**, then **Save and Finish**, then **Start using Jenkins**.

You don't need any extra plugins. This version of the pipeline was simplified to work with the suggested ones.

---

## PART 8: Get a SonarQube token (5 min)

1. Open **`http://<JENKINS-IP>:9000`**. If it says "starting", wait 1–2 minutes and refresh.
2. Log in with **admin / admin**. It forces you to set a new password, so choose one and write it down.
3. Click the **A** avatar (top right), then **My Account**, then the **Security** tab.
4. Under **Generate Tokens**, set Name to `jenkins`, Type to **Global Analysis Token**, and Expires in to **No expiration**. Click **Generate**.
5. **Copy the token (starts with `sqa_`) into Notepad.**

---

## PART 9: Add 2 credentials in Jenkins (5 min)

In Jenkins: **Manage Jenkins → Credentials → System → Global credentials (unrestricted) → + Add Credentials**.

**Credential 1: GitHub token**

| Field | Value |
|---|---|
| Kind | **Secret text** |
| Secret | your GitHub token (`ghp_...`) |
| ID | `github` |
| Description | GitHub token |

Click **Create**, then **+ Add Credentials** again.

**Credential 2: SonarQube token**

| Field | Value |
|---|---|
| Kind | **Secret text** |
| Secret | your SonarQube token (`sqa_...`) |
| ID | `sonar-token` |
| Description | SonarQube token |

> The IDs must be **exactly** `github` and `sonar-token`, in lowercase.

---

## PART 10: Create and run the two pipelines (20 min)

### 10.1 Backend pipeline

1. Jenkins home → **+ New Item**. Name it `three-tier-backend`, choose **Pipeline**, and click **OK**.
2. Scroll down to the **Pipeline** section:

| Field | Value |
|---|---|
| Definition | **Pipeline script from SCM** |
| SCM | **Git** |
| Repository URL | `https://github.com/shravani-dhaktode/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project.git` |
| Credentials | `- none -` (the repo is public) |
| Branch Specifier | `*/master` |
| Script Path | `Jenkins-Pipeline-Code/Jenkinsfile-Backend` |

3. Click **Save**, then **Build Now** (left menu).
4. Click the build **#1** (bottom left), then **Console Output** to watch. It takes about 5–8 minutes and should end with **Finished: SUCCESS**.

### 10.2 Frontend pipeline (start it after the backend finishes)

Repeat 10.1 with:
- Name: `three-tier-frontend`
- Script Path: `Jenkins-Pipeline-Code/Jenkinsfile-Frontend`

The frontend takes longer (about 8–12 minutes) because it installs the React packages.

> ⚠️ Run the pipelines **one at a time**. Both push to GitHub, and running them together can cause a push conflict.

### 10.3 Check that it worked

- **GitHub:** open `Kubernetes-Manifests-file/Backend/deployment.yaml`. The image now ends with `backend:1` instead of `backend:latest`.
- **AWS → ECR → Repositories:** `frontend` and `backend` each have an image.
- **SonarQube (port 9000) → Projects:** `three-tier-backend` and `three-tier-frontend` appear with their results.
- **Jenkins:** each build has the Trivy reports (`trivyfs.txt`, `trivyimage.txt`) under **Build Artifacts**.

**For later builds** (SonarQube only once, as you wanted): click **Build with Parameters**, **untick RUN_SONAR**, and click **Build**.

---

## PART 11: Check the cluster is ready (2 min)

Back in the Instance Connect terminal (reconnect if needed):

```bash
tail -n 8 ~/eks-setup.log
```

You should see:

```
 ALL DONE
 ArgoCD URL : https://a1b2c3....elb.us-east-1.amazonaws.com
 Username   : admin
 Password   : xxxxxxxx
```

**Copy the ArgoCD URL and password into Notepad.** Also run:

```bash
kubectl get nodes      # 2 nodes, STATUS = Ready
```

If the log doesn't say ALL DONE yet, wait and check again. If it shows an error, see Troubleshooting.

---

## PART 12: Deploy the app and open it (10 min)

```bash
cd ~/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project
git pull
bash scripts/2-deploy-app.sh
```

At the end it prints:

```
 Your app: http://k8s-threetie-mainlb-xxxx.us-east-1.elb.amazonaws.com
```

1. Open that link. If it doesn't load, wait 2–3 minutes; new load balancers take a moment. You'll see the **To-Do app**: add a task, tick it, delete it. That proves frontend, backend and MongoDB all work together.
2. Open the **ArgoCD URL**. The browser warns "Not secure"; click **Advanced → Proceed**. Log in as `admin` with the printed password. You'll see the **three-tier** app as **Healthy** and **Synced**, with a tree of all the pods.

Useful check commands:

```bash
kubectl get pods -n three-tier       # mongodb, api, frontend should be Running 1/1
kubectl get ingress -n three-tier    # ADDRESS = your app link
```

---

## PART 13 (optional, 10 min): See the automation work

1. In Jenkins, run **three-tier-backend** again using **Build with Parameters** with RUN_SONAR unticked.
2. When it finishes, GitHub shows `backend:2`.
3. Within about 3 minutes, ArgoCD automatically rolls out the new version (watch it in the ArgoCD UI). That's GitOps.

Take your screenshots for your portfolio now, before cleanup.

---

## PART 14: Stop the charges

You have two choices:
- **14A Pause:** use this after practising. You can bring everything back on exam day.
- **14B Delete forever:** use this after the exam.

### 14A Pause (keep Jenkins for exam day)

**Step 1: On the Jenkins server (Instance Connect), delete the Kubernetes cluster.** This is the expensive part (~$0.25/hour).

```bash
cd ~/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project
bash scripts/3-cleanup.sh
```

Wait until it says **Cluster deleted** (10–15 min).

**Step 2: Stop the Jenkins server (don't terminate it).**
AWS console → **EC2 → Instances** → tick **Jenkins-server** → **Instance state → Stop instance**.
> ⚠️ Click **Stop**, NOT **Terminate**. Terminate deletes Jenkins and all your setup.

**Step 3: Check that nothing expensive is left** (us-east-1):

| Page | Should be |
|---|---|
| EKS → Clusters | empty |
| EC2 → Load Balancers | empty |
| VPC → NAT gateways | **Deleted** |
| CloudFormation → Stacks | no `eksctl-...` stacks |
| EC2 → Instances | Jenkins-server = **Stopped** |

While paused you only pay for the server's 30 GB disk and the stored images, about **US $2.50/month**.

> Don't delete the project folder in CloudShell. It holds the Terraform state file needed for 14B. (CloudShell keeps your files unless you don't open it for 120 days.)

### 14B Delete forever (after the exam)

1. Do **14A Step 1** (`bash scripts/3-cleanup.sh`) if the cluster is running. The Jenkins server must be **running** to do this.
2. In CloudShell:

```bash
export PATH=$HOME/bin:$PATH
export TF_DATA_DIR=/tmp/tfdata
cd ~/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project/Jenkins-Server-TF
terraform init
terraform destroy -var-file=variables.tfvars -auto-approve
```

It ends with `Destroy complete!`. If CloudShell says `terraform: command not found`, repeat the Terraform install lines from Part 4.

3. Check the AWS console (us-east-1):

| Page | Should be |
|---|---|
| EC2 → Instances | all **Terminated** |
| EC2 → Load Balancers | empty |
| VPC → NAT gateways | **Deleted** |
| VPC → Elastic IPs | empty |
| EKS → Clusters | empty |
| CloudFormation → Stacks | no `eksctl-...` stacks |
| ECR → Repositories | empty |

4. Delete the GitHub token at https://github.com/settings/tokens.

---

## PART 15: Exam day (resume in ~40 minutes)

**Start about 1 hour before the examiner arrives.** Creating the cluster takes ~25 minutes, and you don't want them watching that.

**15.1 Start the Jenkins server.** EC2 → Instances → tick **Jenkins-server** → **Instance state → Start instance**. Wait until it shows **Running** with **2/2 checks passed** (~2 min).

**15.2 Note the NEW public IP.** The IP **changes** every time you stop and start the server. Copy the new **Public IPv4 address**. Jenkins is now `http://<NEW-IP>:8080` and SonarQube is `http://<NEW-IP>:9000`.

**15.3 Connect and recreate the cluster.** Click **Connect → EC2 Instance Connect → Connect**, then run:

```bash
cd ~/End-to-End-Kubernetes-Three-Tier-DevSecOps-Project
git pull
nohup bash scripts/1-create-eks.sh > ~/eks-setup.log 2>&1 &
```

**15.4 While you wait (~25 min),** open Jenkins and SonarQube in the browser and log in. Everything is still there. If SonarQube doesn't open, run `docker start sonar` on the server and wait 2 minutes.

**15.5 When `tail -n 8 ~/eks-setup.log` shows ALL DONE,** copy the **new** ArgoCD URL and password (they change each time). Then run:

```bash
git pull
bash scripts/2-deploy-app.sh
```

Open the printed app link and check you can add a task. ✅ You're ready.

### What to show the examiner (suggested order, ~15 min)

1. **GitHub repo:** the code, the Terraform folder (infrastructure as code), the Jenkinsfiles and the Kubernetes manifests.
2. **Jenkins:** run **three-tier-backend → Build with Parameters**. Tick **RUN_SONAR** to show the code scan live (adds ~3 min), or untick it to save time. Walk through the stages as they turn green: SonarQube → Trivy scan → Docker build → push to ECR → update GitHub.
3. **SonarQube:** the project's code-quality results.
4. **Trivy reports:** in the Jenkins build → **Build Artifacts**.
5. **AWS ECR:** the image versions.
6. **GitHub:** the new commit from Jenkins with the image tag changed.
7. **ArgoCD:** the app syncing the new version automatically (GitOps). Click **Refresh** to speed it up.
8. **Terminal:** `kubectl get pods -n three-tier` and `kubectl get ingress -n three-tier`.
9. **The live app** in the browser: add, complete and delete a task.

**After the exam**, do **Part 14B** (delete forever), or **14A** again if you need it once more.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `terraform apply`: *InvalidKeyPair.NotFound* | The key pair isn't in **us-east-1** or the name isn't `project`. Fix it in Part 1.4. |
| `terraform apply`: error about account plan / not eligible | Upgrade the account plan (Part 1.5), then run `terraform apply` again. |
| Jenkins page doesn't open | Install isn't finished. Check `ls ~/SETUP_DONE`. |
| SonarQube page doesn't open | Run `docker ps -a`. If `sonar` isn't running, run `docker start sonar` and wait 2 minutes. |
| Pipeline fails at **Checkout** | Check the repo URL and that the branch is `master`. |
| Pipeline fails at **ECR Image Pushing** | Make sure `terraform apply` finished (it creates the ECR repos). |
| Pipeline fails at **Update Deployment file** with 403 | The GitHub token is wrong or doesn't have the `repo` scope. Edit the `github` credential. |
| `got permission denied ... docker.sock` | On the server, run `sudo chmod 777 /var/run/docker.sock && sudo systemctl restart jenkins`. |
| EKS script error: *Spot capacity* or *insufficient capacity* | Run `nohup bash scripts/1-create-eks.sh > ~/eks-setup.log 2>&1 &` again. It skips steps already done. |
| Pods show `ImagePullBackOff` | Pipelines haven't run yet, or ArgoCD hasn't seen the new tag. Wait 3 minutes, or in ArgoCD click **Refresh**, then **Sync**. |
| Pod `api` shows `0/1` | It waits for MongoDB and retries every 5 seconds. Give it about 1 minute. |
| App link shows 503 | The load balancer is still registering pods. Wait 2–3 minutes. |
| App shows 404 | Run `kubectl get ingress -n three-tier`. ADDRESS must not be empty. Check the controller with `kubectl get pods -n kube-system`. |

## What was changed from the original project

- Terraform uses local state, so you don't need an S3 bucket or DynamoDB table. It also creates the ECR repos, uses a t3.large on Ubuntu 24.04 with Java 21 (needed by current Jenkins), and prints outputs.
- `tools-install.sh` uses the 2026 Jenkins signing key, the current SonarQube Community image, a pinned Trivy version, Node.js 20, and a 4 GB swap file.
- The Jenkinsfiles need no extra plugins and only 2 credentials. SonarQube runs through Docker and can be switched off with the `RUN_SONAR` option. The slow OWASP Dependency-Check stage was removed.
- Kubernetes:
  - The manifests use your account ID and 1 backend replica.
  - The frontend calls `/api/tasks` (a relative path), so no domain is needed.
  - The ingress has no host, the backend has a proper health check, and unused `imagePullSecrets` were removed.
- The backend retries the MongoDB connection until the database is ready.
- New `scripts/` handle EKS, deploying and cleanup, and `argocd/application.yaml` is the GitOps app.
