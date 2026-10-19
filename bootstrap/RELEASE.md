# Publishing

`dots.aliabbas.dev` serves `bootstrap/start.sh` from the **head of `main`**
(the Worker in `~/code/dotfiles-bootstrap`). A push to `main` is what new
machines run within a few minutes, so `main` must always be bootstrappable:

1. Run `bash bootstrap/check-source.sh`. Review `git diff --check`, every added
   and removed file, and `git status --short`.
2. Test larger changes on a branch first: on an ALNIAC machine, run
   `bash bootstrap/setup.sh --plan` and `bash bootstrap/setup.sh` from that
   checkout. Local rendering tests alone do not qualify a fresh bootstrap.
3. Push to `main` only what is ready for a new machine.

The Worker serves a script only if it is the ALNIAC profile; any other script
at the head of `main` gets HTTP 503 and no installer. The Worker needs no
deployment for a dotfiles change.
