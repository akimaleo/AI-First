# Sync or Sink — Agent Instructions

## Git Workflow (Required)

All engineers and the CTO **must** follow this git workflow for every ticket:

1. **Branch from main** — Before starting work on a ticket, create a feature branch off `main`:
   ```
   git checkout main && git pull origin main
   git checkout -b feat/<ticket-identifier>-<short-description>
   ```

2. **Commit every change** — Make atomic commits as you work. Do not batch all changes into a single commit at the end. Each meaningful change should be its own commit with a clear message.

3. **Push changes when the ticket is done** — Once your work is complete and the ticket is ready to close, push your feature branch to the remote:
   ```
   git push origin feat/<ticket-identifier>-<short-description>
   ```

4. **Merge to main** — After pushing, merge your feature branch into `main`:
   ```
   git checkout main && git pull origin main
   git merge feat/<ticket-identifier>-<short-description>
   git push origin main
   ```

5. **Do not delete the feature branch** — Keep feature branches intact after merging. Do not run `git branch -d` or `git push origin --delete` on them.

### Commit Message Format

- Use clear, descriptive commit messages
- Include the ticket identifier when relevant (e.g., `feat(GUSAA-42): add login screen`)
- Always add the co-author trailer:
  ```
  Co-Authored-By: Paperclip <noreply@paperclip.ing>
  ```
