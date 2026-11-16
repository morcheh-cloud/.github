# Security policy

Morche holds SSH keys and passwords for the servers it manages, so we take
reports seriously.

## Reporting a vulnerability

Please **don't open a public issue**. Report it privately through GitHub:
open the affected repository's **Security** tab and choose
**Report a vulnerability**.

Include what you found, the version (image tag or commit) and the steps to
reproduce it. We'll answer within a few days and keep you posted until it's
fixed.

## Supported versions

Only the latest release gets security fixes. Keep `MORCHE_VERSION` on a
current release and update with `docker compose pull && docker compose up -d`.
