# Contributing

Thanks for your interest. A few things to know before you start.

## Scope

This repository is a sanitized public mirror of a private home-network setup. It
is published as a reference architecture / feasibility study, not as a general
purpose product. Because of that the scope for changes is limited: fixes and
small improvements are welcome, larger features may not fit the project's goals.

## Workflow

- Open an issue before sending a pull request, so we can agree on the change
  first and avoid wasted work.
- Keep pull requests small and focused.

## Keep secrets out

Never commit secrets, real IP addresses, hostnames, tokens or other private
network details. The repository uses `<TOKEN>` placeholders in `*.tmpl` files
plus a gitignored `config.env` for local values.

- Copy `config.env.example` to `config.env` and fill in your own values.
- Run `./render.sh` locally to generate the deploy-ready files and test your
  change.
- Only the `*.tmpl` files and other tracked sources are committed; the rendered
  outputs stay local.
