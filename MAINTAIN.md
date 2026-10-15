# Chatwoot Customization & Maintenance Guide

This document outlines the workflow for developing custom features, maintaining our Chatwoot fork, upgrading to new upstream releases, and deploying to production without causing downtime for the support team.

---

## Architecture & Repositories Overview

We follow a strict 4-location workflow to prevent conflicts and ensure high availability:

```
┌────────────────────────────────────────────────────────┐
│  1. UPSTREAM (Official Chatwoot Repo on GitHub)         │
│     github.com/chatwoot/chatwoot                       │
│     * Read-only source of truth for new releases/tags   │
└──────────────────────────┬─────────────────────────────┘
                           │ (Fetch tags & official code)
                           ▼
┌────────────────────────────────────────────────────────┐
│  2. ORIGIN (Our Private Fork on GitHub)                │
│     github.com/pantry-snacks/chatwoot                  │
│     * Stores custom features & the production branch   │
└─────────────┬────────────────────────────┬─────────────┘
              │                            │
   (git push) │ (git pull)      (git pull) │
              ▼                            ▼
┌─────────────────────────┐   ┌──────────────────────────┐
│ 3. LOCAL DEV MACHINE    │   │ 4. PRODUCTION VPS        │
│    (Laptop / Workstation)│  │    (/home/chatwoot/...)  │
│    * Write custom code  │   │    * Runs live Chatwoot  │
│    * Test & merge       │   │    * NEVER edit code here│
└─────────────────────────┘   └──────────────────────────┘
```

### Golden Rules
1. **Never edit or test code directly on the VPS.** Always develop and test on your local development machine.
2. **Never commit directly to `production`.** Always use feature branches (`feature/...`) or upgrade branches (`upgrade/...`).
3. **Keep custom logic modular.** Write new logic in isolated service classes (`app/services/custom/...`) or listeners (`app/listeners/...`) rather than hacking core Chatwoot models or controllers directly. This minimizes merge conflicts during upgrades.

---

## 1. Initial Local Setup

Clone our fork and set up both remotes (`origin` for our fork, `upstream` for official Chatwoot):

```bash
# 1. Clone our fork
git clone git@github.com:pantry-snacks/chatwoot.git
cd chatwoot

# 2. Add official Chatwoot upstream remote
git remote add upstream https://github.com/chatwoot/chatwoot.git

# 3. Verify remotes
git remote -v
# origin   -> git@github.com:pantry-snacks/chatwoot.git (fetch & push)
# upstream -> https://github.com/chatwoot/chatwoot.git (fetch & push)

# 4. Fetch all tags and branches
git fetch origin
git fetch upstream --tags
```

---

## 2. Developing a Custom Feature

Follow this workflow every time you build a new feature or customize the UI/backend.

### Step 2.1: Create a Feature Branch
Always start from the latest `production` branch:

```bash
git checkout production
git pull origin production

# Create a feature branch
git checkout -b feature/my-custom-feature
```

### Step 2.2: Implement Your Changes
Chatwoot's directory structure:
- **Dashboard UI (Agent App):** `app/javascript/dashboard/` (Vue.js)
- **Live Chat Widget:** `app/javascript/widget/` (Vue.js)
- **APIs & Controllers:** `app/controllers/api/v1/`
- **Business Logic & Integrations:** `app/services/`
- **Background Jobs:** `app/jobs/`, `app/workers/` (Sidekiq)
- **Event Listeners / Webhooks:** `app/listeners/`
- **Database Migrations:** `db/migrate/`

Commit your changes:
```bash
git add .
git commit -m "feat: implement custom ticket SLA indicator"
```

### Step 2.3: Test Locally
Ensure dependencies and assets compile without errors:
```bash
bundle exec rake assets:precompile RAILS_ENV=production
```

### Step 2.4: Merge into `production` and Push
Once tested and reviewed:

```bash
# Switch to production
git checkout production
git pull origin production

# Merge feature branch (use --no-ff to keep history clean)
git merge feature/my-custom-feature --no-ff -m "Merge feature/my-custom-feature into production"

# Push to our GitHub fork
git push origin production

# Clean up local feature branch
git branch -d feature/my-custom-feature
```

---

## 3. Deploying to the Production VPS

Deployments must be performed without interrupting active customer chats or support team agents.

Log in to the VPS as the `chatwoot` user:

```bash
sudo -i -u chatwoot
cd /home/chatwoot/chatwoot
```

### Deployment Commands

```bash
# 1. Pull the latest verified code from our fork
git pull origin production

# 2. Install any new Ruby gems or Node dependencies (if changed)
bundle install --without development test --quiet
yarn install --pure-lockfile --silent

# 3. Run database migrations (safe expand/contract pattern)
RAILS_ENV=production bundle exec rake db:migrate

# 4. Precompile frontend assets with CPU throttling (prevents server freezing)
nice -n 15 ionice -c 3 bundle exec rake assets:precompile RAILS_ENV=production

# 5. Phased reload of Puma web server (keeps WebSocket connections alive)
sudo systemctl reload chatwoot-web

# 6. Graceful restart of Sidekiq worker (waits for ongoing jobs to finish)
sudo systemctl restart chatwoot-worker
```

> **Automated Deploy Script:** You can place the above commands in `/home/chatwoot/deploy.sh` and make it executable (`chmod +x /home/chatwoot/deploy.sh`). Whenever you push changes, simply run `./deploy.sh` on the server.

---

## 4. Upgrading to New Official Chatwoot Releases

When Chatwoot releases a new official version tag (e.g. `v3.16.0`), follow these steps on your **local machine** (never on the VPS).

### Step 4.1: Fetch New Upstream Tags
```bash
git fetch upstream --tags
```

### Step 4.2: Create a Test Upgrade Branch
```bash
git checkout production
git pull origin production

# Branch off current production
git checkout -b upgrade/v3.16.0   # Replace with actual tag name
```

### Step 4.3: Merge the Upstream Tag
```bash
git merge v3.16.0
```

### Step 4.4: Resolve Any Conflicts
If Git reports merge conflicts:
1. Open conflicting files in your editor (e.g. VS Code).
2. Look for conflict markers:
   ```text
   <<<<<<< HEAD (Our custom code)
   <custom-ticket-sla-badge :conversation="conversation" />
   =======
   <new-upstream-agent-status :conversation="conversation" />
   >>>>>>> v3.16.0 (Official Chatwoot)
   ```
3. Keep what is needed, delete the marker lines, and save.
4. For lockfiles (`yarn.lock`, `Gemfile.lock`), resolve by running:
   ```bash
   bundle install
   yarn install
   ```
5. Commit the resolved merge:
   ```bash
   git add .
   git commit -m "chore: upgrade upstream to v3.16.0 and resolve conflicts"
   ```

### Step 4.5: Validate Build Locally
```bash
bundle install
yarn install
bundle exec rake db:migrate
bundle exec rake assets:precompile RAILS_ENV=production
```

### Step 4.6: Merge into `production` and Push
```bash
git checkout production
git merge upgrade/v3.16.0 --no-ff -m "chore: upgrade production to v3.16.0"
git push origin production

# Delete the temporary upgrade branch
git branch -d upgrade/v3.16.0
```

### Step 4.7: Deploy the Upgrade on VPS
Run your VPS deploy script:
```bash
sudo -i -u chatwoot
cd /home/chatwoot/chatwoot
./deploy.sh
```

---

## 5. Troubleshooting & Maintenance Tips

| Issue | Cause | Solution |
| :--- | :--- | :--- |
| `Permission denied (publickey)` on VPS | VPS SSH key not registered on GitHub | Generate key via `ssh-keygen` and add public key to **GitHub Repo Settings ➔ Deploy keys**. |
| High CPU/RAM during deployment | Asset precompilation consumes 100% resources | Always use `nice -n 15 ionice -c 3` before running `assets:precompile`. |
| Disconnected WebSockets / Live chats | Hard restart of Puma (`systemctl restart`) | Use `systemctl reload chatwoot-web` instead of restart (phased rolling reload). |
| Unresolved DB conflicts during upgrade | Column names or types conflict | Follow the expand-and-contract pattern. Avoid dropping columns until old code is completely phased out. |
