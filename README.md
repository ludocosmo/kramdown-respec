# kramdown-respec

[kramdown][] is a [markdown][] parser by Thomas Leitner, which has a
number of backends for generating HTML, LaTeX, and markdown again.

**kramdown-respec** is an additional backend to that: It allows the
generation of W3C/ReSpec markup ([https://respec.org/docs/][]).

Who would care?  Anybody who is writing Internet-Drafts and RFCs in
the [IETF][] and prefers (or has co-authors who prefer) to do part of
their work in markdown.

# Usage

Start by installing the kramdown-respec gem (this automatically
installs appropriate versions of referenced gems such as kramdown as
well):

    gem install kramdown-respec

(Add a `sudo` and a space in front of that command if you don't have
all the permissions needed.)

