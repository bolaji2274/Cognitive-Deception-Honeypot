#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "🚀 [1/6] System Update & Dependency Installation..."
# Update system and install Python, Pip, and System dependencies
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get install -y python3-pip python3-venv authbind iptables-persistent git jq

# Create a dedicated directory for the CDL (Cognitive Deception Labyrinth)
APP_DIR="/opt/cdl-honeypot"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

echo "🧠 [2/6] Writing the Cognitive Brain (Python Application)..."

# We embed the Python code directly here so you don't need a separate file upload.
# This writes 'cognitive_shell.py' to /opt/cdl-honeypot/cognitive_shell.py
cat << 'EOF' > "$APP_DIR/cognitive_shell.py"
import asyncio
import asyncssh
import os
import sys
import random
import time
import json
from openai import AsyncOpenAI

# --- CONFIGURATION ---
# We bind to 2222 internally. IPTables will forward Port 22 to us.
SSH_PORT = 2222
SSH_KEY_PATH = "host_key"

# Get Key from Environment or use placeholder for safety
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
AI_MODEL = "gpt-4-turbo-preview" 

# --- THE COGNITIVE PERSONA ---
SYSTEM_PROMPT = """
You are 'SRV-ALPHA-04', a Ubuntu 22.04 LTS production server at 'Nebula-X Defense Systems'.
Your role is to ACT AS THE TERMINAL. The user is an attacker or employee.
1. COMMAND HANDLING:
   - I will type a command (e.g., 'ls -la', 'cat /etc/passwd').
   - You reply with the EXACT standard output of that command.
   - Do not explain anything. Do not use markdown blocks.
   - If the command is 'whoami', return 'sysadmin'.
   
2. DECEPTION LOGIC:
   - If I look for files, 'hallucinate' plausible sensitive files (e.g., 'backup_codes.txt', 'project_chimera_specs.pdf').
   - If I delete files, pretend they are gone.
   - If I try to download malware (wget/curl), simulate a network timeout or 403 Forbidden.
   
3. TONE:
   - You are a cold, unfeeling Linux kernel.
"""

# Initialize OpenAI Client
if not OPENAI_API_KEY:
    print("CRITICAL: OPENAI_API_KEY is missing. Using dummy mode.")
    client = None
else:
    client = AsyncOpenAI(api_key=OPENAI_API_KEY)

class CognitiveSSHServer(asyncssh.SSHServer):
    def connection_made(self, conn):
        self._conn = conn
        peer = conn.get_extra_info('peername')[0]
        print(f"[!] New Victim Connected: {peer}")

    def connection_lost(self, exc):
        print(f"[-] Victim Disconnected")

    def begin_auth(self, username):
        # We let EVERYONE in. This is a honeypot.
        return True

    def password_auth_supported(self):
        return True

    def validate_password(self, username, password):
        print(f"[*] Credentials Captured: User='{username}' | Pass='{password}'")
        # Log this to a JSON file for the admin to see later
        with open("captured_creds.json", "a") as f:
            entry = {"timestamp": time.time(), "user": username, "pass": password}
            f.write(json.dumps(entry) + "\n")
        return True

async def handle_client(process):
    # The Interactive Shell Handler
    process.stdout.write(f"Welcome to Ubuntu 22.04.2 LTS (GNU/Linux 5.15.0-generic x86_64)\n")
    process.stdout.write(f"System load: 0.02, 0.01, 0.00\n\n")
    
    # Session History for Context
    history = [{"role": "system", "content": SYSTEM_PROMPT}]
    
    while True:
        try:
            # Simulate the shell prompt
            process.stdout.write("sysadmin@srv-alpha-04:~$ ")
            
            # Read command from user
            cmd = await process.stdin.readline()
            if not cmd:
                break
            
            cmd = cmd.strip()
            if cmd == "exit":
                process.exit(0)
                break
            if cmd == "":
                continue

            # Log the command
            print(f"[>] Command: {cmd}")

            # AI Generation Logic
            if client:
                history.append({"role": "user", "content": cmd})
                
                try:
                    # Call OpenAI API
                    response = await client.chat.completions.create(
                        model=AI_MODEL,
                        messages=history,
                        temperature=0.1, 
                        max_tokens=600
                    )
                    output = response.choices[0].message.content
                    
                    # Clean up output (remove markdown code blocks if AI adds them)
                    output = output.replace("```bash", "").replace("```", "").strip()
                    
                    history.append({"role": "assistant", "content": output})
                    
                    # Stream response to attacker
                    process.stdout.write(output + "\n")
                except Exception as e:
                    process.stdout.write(f"bash: {cmd}: command not found (System Error)\n")
                    print(f"AI Error: {e}")
            else:
                # Fallback if no API key is set
                process.stdout.write(f"bash: {cmd}: command not found\n")

        except asyncssh.BreakReceived:
            process.stdout.write("\n")
        except Exception as e:
            break

async def start_server():
    # Create SSH Host Keys if they don't exist
    if not os.path.exists(SSH_KEY_PATH):
        print("Generating SSH Host Keys...")
        # We generate a new keypair for the honeypot identity
        from asyncssh import generate_private_key
        key = generate_private_key('ssh-rsa')
        key.write_private_key(SSH_KEY_PATH)

    print(f"🧠 Cognitive Shell Listening on 0.0.0.0:{SSH_PORT}...")
    
    await asyncssh.create_server(
        CognitiveSSHServer, 
        '', SSH_PORT, 
        server_host_keys=[SSH_KEY_PATH], 
        process_factory=handle_client
    )

if __name__ == '__main__':
    if sys.platform == 'win32':
        asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
        
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    
    try:
        loop.run_until_complete(start_server())
    except (OSError, asyncssh.Error) as exc:
        sys.exit(f'Error starting server: {exc}')
    loop.run_forever()
EOF

echo "📦 [3/6] Setting up Virtual Environment..."
# Setup Python Venv
python3 -m venv venv
source venv/bin/activate

# Install dependencies inside venv
pip install asyncssh openai

echo "🛡️ [4/6] Configuring Network & Ports..."
# 1. Move REAL SSH to port 22222 so we don't lock ourselves out (just in case SSM fails)
sed -i 's/#Port 22/Port 22222/' /etc/ssh/sshd_config
# Ensure password auth is disabled for REAL SSH (Keys only)
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh

# 2. Redirect Port 22 (Standard SSH) -> Port 2222 (Our Python Honeypot)
# This allows the honeypot to run as non-root user but accept traffic on port 22
iptables -t nat -A PREROUTING -p tcp --dport 22 -j REDIRECT --to-port 2222
netfilter-persistent save

echo "⚙️ [5/6] Creating Systemd Service..."
# Create a service so the honeypot starts on boot and restarts if it crashes
cat <<EOF > /etc/systemd/system/honeypot.service
[Unit]
Description=CDL Cognitive Honeypot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
# IMPORTANT: Replace the Key below with your actual key or inject via AWS Secrets Manager
Environment="OPENAI_API_KEY=sk-proj-YOUR-ACTUAL-KEY-HERE-PLEASE-CHANGE"
ExecStart=$APP_DIR/venv/bin/python3 $APP_DIR/cognitive_shell.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Reload and Start
systemctl daemon-reload
systemctl enable honeypot.service
systemctl start honeypot.service

echo "✅ [6/6] Deployment Complete. Honeypot is active."