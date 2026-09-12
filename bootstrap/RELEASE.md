# Omarchy configuration release

The hostname remains **`dots.aliabbas.dev`**. Do not revert it to the former
hostname or deploy the retired standalone bootstrap.

The separate Worker project is `~/code/dotfiles-bootstrap`. Its release guard
checks an immutable, published dotfiles commit and the SHA-256 of that commit's
`bootstrap/start.sh`. This repository restoration does not itself change the
hosted release. At restoration time, the endpoint still served `b468b33`.

1. Run `bash bootstrap/check-source.sh`; review `git diff --check`, all restored
   and removed files, and `git status --short` (restored files may be untracked).
2. Test setup on a disposable, already-installed Omarchy 4 machine. Local
   rendering tests alone do not qualify a fresh bootstrap.
3. With publication approval, commit and push the reviewed restoration.
4. In the Worker project, update the immutable dotfiles ref and bootstrap
   SHA-256 to that published commit. Keep the existing `dots.aliabbas.dev` route.
5. Run the Worker's tests, checksum/publication guard and deployment dry run.
   Deploy only with approval.
6. Download the hosted response and verify its ref, checksum and Omarchy
   preflight. Do not execute it on the working laptop merely to test deployment.

Keep the root README's release-review guidance when updating the pin. Applying
dotfiles and publishing/deploying releases are separate, explicit actions;
neither requires restoring historical boot artifacts.
