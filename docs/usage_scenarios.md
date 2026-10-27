[Русский](usage_scenarios_RU.md) · English · [Español](usage_scenarios_ES.md) · [Français](usage_scenarios_FR.md) · [Deutsch](usage_scenarios_DE.md) · [ქართული](usage_scenarios_GE.md) · [繁體中文](usage_scenarios_TW.md) · [日本語](usage_scenarios_JP.md) · [Home](../README.MD)

<a id="usage"></a>

# Usage scenarios and videos

<details>
<summary>CKA + CKAD and CKS labs: from launch to validation</summary>

1. Choose an exercise in the [lab catalog](labs.MD) and read its description: `tasks/cka/labs/<number>/README.MD` or `tasks/cks/labs/<number>/README.MD` for translated exercises.
2. Check `env.hcl`: the region, instance types, and environment settings. If setting `ami_id` manually, the image must match the region and instance architecture; for automatic selection, follow the scenario settings.
3. Create the environment: `TASK=101 make run_cka_task` or `TASK=101 make run_cks_task`.
4. Find the SSH command in the Terraform output. Composite labs usually start on the `worker` workstation, while some scenarios start on a control-plane node. Use the `worker_pc_ip`, `master_external_ip`, or ready-to-run connection command provided by your specific scenario.
5. Connect as `ubuntu`. With key-based access, use `ssh ubuntu@<IP> -i <key_path>`; if the environment outputs a password, connect with `ssh ubuntu@<IP>` and enter it when prompted.
6. If needed, check that initialization finished on the appropriate machine: `tail -f /var/log/cloud-init-output.log`.
7. Complete the tasks. In composite labs, run `check_result` on the workstation; follow the validation method in the exercise description.
8. Review the reference solution. For lab 101: [CKA + CKAD](../tasks/cka/labs/101/worker/files/solutions/1.MD) and [CKS](../tasks/cks/labs/101/worker/files/solutions/1.MD). Other exercises may store solutions elsewhere; use the link in the catalog or description.
9. Perform any preliminary cleanup in the lab's deletion section, then delete the environment: `TASK=101 make delete_cka_task` or `TASK=101 make delete_cks_task`.

To relaunch after clearing the local environment directory, use `run_cka_task_clean` or `run_cks_task_clean`. Cloud resources must be removed with `delete_*` commands.

</details>

<details>
<summary>Practical CKA, CKAD, CKS, ICA, and HR mock exams</summary>

General procedure:

1. Choose an exam number and open its README in `tasks/<track>/mock/<number>/`.
2. If needed, change supported settings in `env.hcl`: OS (`ubuntu_version`), EC2 purchase mode (`spot` or `ondemand`), and instance types.
3. Launch the environment with `TASK=<number> make run_<track>_mock`. Use `run_<track>_mock_clean` to launch after clearing the local environment directory.
4. Find `worker_pc_ip` or the ready-to-run SSH command in the Terraform output, then connect to the workstation as `ubuntu` with the key or password specified for that environment.
5. Open the task list and work from the workstation. To access a cluster node, use `ssh <node_name>` according to the exam description.
6. Check remaining time with `time_left` and results with `check_result`, where these commands are supported.
7. After your attempt, review the solutions and tests linked below.
8. Delete the environment with `TASK=<number> make delete_<track>_mock`.

| Track | Exam 01 tasks | Solutions | Automated checks |
|---|---|---|---|
| CKA | [Description](../tasks/cka/mock/01) | [Solutions](../tasks/cka/mock/01/worker/files/solutions) | [tests.bats](../tasks/cka/mock/01/worker/files/tests.bats) |
| CKAD | [Description](../tasks/ckad/mock/01) | [Solutions](../tasks/ckad/mock/01/worker/files/solutions) | [tests.bats](../tasks/ckad/mock/01/worker/files/tests.bats) |
| CKS | [Description](../tasks/cks/mock/01) | [Solutions](../tasks/cks/mock/01/worker/files/solutions) | [tests.bats](../tasks/cks/mock/01/worker/files/tests.bats) |
| ICA | [Description](../tasks/ica/mock/01) | [Solutions](../tasks/ica/mock/01/worker/files/solutions) | [Test directory](../tasks/ica/mock/01/worker/files/tests) |
| HR | [Description](../tasks/hr/mock/01) | [Solutions](../tasks/hr/mock/01/worker/files/solutions) | [tests.bats](../tasks/hr/mock/01/worker/files/tests.bats) |

Video instructions and walkthroughs:

- CKA: [launch the mock exam](https://www.youtube.com/watch?v=P-YYX4CTWIg), [exam 01 solutions](https://youtu.be/IZsqAPpbBxM).
- CKS: [launch the mock exam](https://youtu.be/_GbsBOMaJ9Q), [solution walkthrough](https://youtu.be/I8CPwcGbrG8).
- CKAD: [launch the mock exam](https://youtu.be/7X4Y9QhbTsk), [solution walkthrough](https://youtu.be/yQK7Ca8d-yw).
- HR: [scenario walkthrough video](https://youtu.be/4CTC1jl8lxE).

</details>

<details>
<summary>Amazon EKS: working through a lab</summary>

1. Choose a number in the [EKS catalog](labs.MD#eks-labs) and read the exercise description.
2. Check `env.hcl`, then run `TASK=101 make run_eks_task`, substituting the chosen lab number.
3. Find the workstation's `worker_pc_ip` or SSH command in the Terraform output. Connect as `ubuntu` using a key or password according to the exercise description.
4. Complete the tasks and validate the result. Composite labs provide `check_result`.
5. Review the solution linked in the description or catalog, for example the [lab 101 solution](../tasks/eks/labs/101/worker/files/solutions/1.MD).
6. Perform the preliminary cleanup in the exercise's deletion section, then run `TASK=101 make delete_eks_task` with the correct number.

</details>

Other scenarios: [Istio / ICA labs](../tasks/ica/README.MD), [LFCS mock exam 01](../tasks/lfcs/mock/01), [KCSA test materials](../tasks/kcsa/README.md), [KCNA mock exam 01](../tasks/kcna/mock/01/README.MD), [AWS Certified AI Practitioner mock exam 01](../tasks/aws_AI_practitioner/mock/01/README.MD).
