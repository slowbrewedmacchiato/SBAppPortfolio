# Security Policy

## Supported versions

The latest tagged release receives security fixes. Older tags do not.

## Reporting a vulnerability

Please do not open a public issue for a security problem.

Use GitHub's private vulnerability reporting on this repository: go to the
**Security** tab and choose **Report a vulnerability**. That opens a private
channel visible only to the maintainer.

You can expect an acknowledgement within seven days. If a fix is warranted it
ships in the next patch release, and the advisory is published once the fix is
available.

## Scope

SBAppPortfolio makes unauthenticated GET requests to Apple's iTunes Lookup
endpoint and renders the response. It stores nothing, sends no user data, and
requires no credentials or API keys.

The most relevant classes of issue are therefore how untrusted response data is
decoded and rendered, and anything that would let a malicious response affect
the host app.
