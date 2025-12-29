# 🌌 Nebula-X: Cognitive Deception Labyrinth (CDL)

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Terraform](https://img.shields.io/badge/IaC-Terraform-623CE4.svg)
![AI](https://img.shields.io/badge/AI-GPT--4--Turbo-00A67E.svg)

**Nebula-X** is an advanced, high-interaction honeypot that leverages Large Language Models (LLMs) to create a "Cognitive Shell." Unlike traditional honeypots that use static scripts, Nebula-X hallucinates an entire Linux operating system in real-time, adapting to attacker behavior and maintaining stateful deception.

---

## 🏗️ System Architecture

The project deploys a fully isolated environment in AWS, ensuring that even if a "breakout" occurs, the attacker is trapped in a sandbox with no route to production assets.



### Key Components:
* **Cognitive Shell (Python/AsyncSSH):** The core engine that captures SSH connections and pipes commands to an LLM.
* **Port 22 Trap:** Transparently redirects standard SSH traffic to the honeypot using `iptables`.
* **Stealth Management:** Real administrative access is moved to port `22222`.
* **Infrastructure as Code (Terraform):** Complete automation of VPC, IAM roles, and instance provisioning.

---

## 🚀 Quick Start

### 1. Prerequisites
* AWS CLI configured with appropriate permissions.
* Terraform installed.
* An OpenAI API Key.

### 2. Environment Setup
Create a `.env` file in the root directory (this is ignored by git for security):
```bash
export TF_VAR_openai_api_key="your-api-key-here"
export TF_VAR_key_name="your-aws-key-name"