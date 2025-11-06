# MindLock Git Workflow Primer

Use this as a literal checklist when you want to preserve the current state, explore a big change, or roll back if it doesn’t work out. The commands assume you run them from the project root (`/Users/lucaszambrano/app blocking productivity app`).

---

## 1. Initialize the repo (only once)

```bash
git init
git add .
git commit -m "snapshot: current MindLock build before structural changes"
```

Now Git is tracking every file.

---

## 2. Tag the baseline

```bash
git tag -a v0.1.0-current -m "Pre-refactor baseline"
```

Optional but recommended. Tags let you jump back later.

---

## 3. Start a new experiment

```bash
git checkout -b backend-rework
```

Work on this branch. Commit as you go:

```bash
git add .
git commit -m "feat: scaffold new backend"
```

---

## 4. Undo the experiment

If you want to abandon the branch:

```bash
git checkout main          # or the branch/tag you want
git branch -D backend-rework
```

To check out the saved baseline exactly as it was:

```bash
git checkout v0.1.0-current
```

If you need to keep working from that point, create a new branch while you’re there:

```bash
git checkout -b recovery-from-baseline
```

---

## 5. Share the repo (optional but recommended)

1. Create a repository on GitHub.
2. Set the remote and push:

```bash
git branch -M main
git remote add origin https://github.com/USERNAME/mindlock.git
git push -u origin main
git push origin v0.1.0-current   # push the tag
```

Now any machine (including future you) can restore that exact state with `git clone`.

---

## 6. Recover the code later

```bash
git clone https://github.com/USERNAME/mindlock.git mindlock-restore
cd mindlock-restore
git checkout v0.1.0-current
```

You can open this folder in Xcode, or use `git checkout main` to work from the latest commits.

---

## Xcode Tips

* Xcode detects Git automatically. Once the repo is initialized, the Source Control navigator shows your branches, history, and diffs.
* `Source Control > New Branch…` mirrors `git checkout -b`.
* `Source Control > Check Out…` lets you jump to a tag or branch without touching Terminal.

Keep this guide handy whenever you freeze a milestone or need to undo a refactor.***
