# ALNIAC configuration release

The hostname stays **`dots.aliabbas.dev`**.

The Worker project is `~/code/dotfiles-bootstrap`. Its release guard checks a
published, immutable dotfiles commit and the SHA-256 of that commit's
`bootstrap/start.sh`, and it accepts only the ALNIAC profile.

1. Run `bash bootstrap/check-source.sh`. Review `git diff --check`, every added
   and removed file, and `git status --short`.
2. Test setup on an ALNIAC machine. Local rendering tests alone do not qualify
   a fresh bootstrap.
3. With approval, commit and push the reviewed change to `main`.
4. In the Worker project, set the dotfiles ref and the bootstrap SHA-256 to
   that published commit. Keep the `dots.aliabbas.dev` route.
5. Run the Worker's tests, release guard and deployment dry run. Deploy only
   with approval.
6. Download the hosted response and check its ref, checksum and ALNIAC
   preflight. Do not run it on the working laptop only to test the deployment.

Applying dotfiles and publishing a release are separate, explicit actions.
