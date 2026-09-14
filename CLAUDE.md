# Working rules for this repo

## Comments

Code should read without commentary. Do not restate what the code already
says, and do not leave notes that the next refactor will outdate. Dense
comments are harder for a human to read past than the code itself.

Write a comment only where the code is genuinely surprising and would mislead
someone without it: a workaround for another project's bug, a constant that
was measured rather than chosen, a literal that looks translatable but is
load-bearing. Keep it to a line or two. If the reason needs a paragraph, it is
not a comment.

Everything else worth recording -- why an approach was chosen, what was tried
and failed, how a subsystem fits together -- goes in `tmp/comments/` as
`yyyy-MM-dd-<slug>.md`, dated the day it was written. That is the place for
background an agent will want later; it keeps it out of the way of anyone
reading the code.

## Commits

Scope first, then a short subject: `client:`, `ci:`, `docs:`, `comments:`,
`files:`. One line, and stop there. Add a body only when the change has a
reason that is not visible in the diff -- a constraint that forced it, or an
exception that would otherwise look like an oversight.

## Merging

`main` takes pull requests only; direct pushes are refused for everyone,
admins included. An agent opens the PR, pushes to its branch, and stops there.
Merging is done by hand -- never by an agent -- so that a person has read the
diff before it lands. `.claude/settings.json` denies `gh pr merge` to stop it
happening by reflex, but the rule matters more than the guard: there is more
than one way to merge a pull request.

Release bumps are no exception. The `PKG_VERSION` commit goes through a PR
like anything else, and the tag is pushed only once that has been merged.

## Reference only what the reader can see

A code comment, a commit message, an issue or a pull request is read by someone
who has the repository and nothing else. Everything outside it is invisible to
them: files under `tmp/`, a branch that was never pushed, a scratch review
document, and above all the short labels such documents use -- `C1`, `P1`,
"proposal 2 of the review". Those read as if they were common knowledge and
are not.

Name the thing rather than its label. "the hardcoded target list in the
download table" still means something a year from now; `P6` means nothing to a
reader who never saw that list, and nothing to you either once the file is
gone.

## Language

Code, comments, identifiers, log output and docs are English. No em dashes;
use `-`.

Talking to people is Russian: issue and pull request titles and bodies, and
every comment on them. The users and contributors of this project are mostly
Russian-speaking, so that is where they read. The split is by audience, not by
file -- an English PR describing a Russian-facing change reaches the wrong
people, and a Russian identifier in the code reaches nobody at all.

Two places keep Russian on purpose, both load-bearing:

- `client/namegen.go` -- given names, surnames, and the `HasSuffix`
  morphology that feminises a surname. This is data for VK profile
  plausibility, not prose.
- `client/group.go` -- the `"хеш мёртв"` matcher. Nothing here produces that
  text; it arrives from the server, so translating it turns off dead-hash
  detection.

## Verifying a change

The client is Linux-only (`listen.go` and `tun_fd.go` use `syscall.Handle`
and `unix.CmsgSpace`), so a native Windows build fails and proves nothing:

    cd client
    GOOS=linux GOARCH=amd64 go build -tags=openwrt -o /dev/null .
    GOOS=linux GOARCH=amd64 go vet -tags=openwrt ./...

`-tags=openwrt` is not optional: without it the wrong raw-socket
implementation is selected, and it is what the release workflow builds with.

Tests need a Linux host to execute, so on Windows run them in a container
(`MSYS_NO_PATHCONV=1` stops Git Bash rewriting `/src`):

    MSYS_NO_PATHCONV=1 docker run --rm -v "<repo>:/src" -w /src/client \
      golang:1.27-alpine go test -tags=openwrt ./...

`gofmt -l` flags every file on a CRLF checkout, so on its own it says nothing.
Seven files are unformatted in upstream's own history; compare against that
set rather than expecting a clean run.
