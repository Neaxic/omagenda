# datebook site

The public homepage and privacy policy. Google's OAuth verification requires both,
on a domain you can prove you own, and the privacy policy must be on the **same
domain** as the homepage.

Two static pages, one stylesheet, two screenshots. No build step, no dependencies.

## Deploy

```bash
./configure <domain> <contact-email>     # stamp in the real values, once
```

Then serve this directory as the site root, so that:

| Path | URL |
|---|---|
| `index.html` | `https://<domain>/` |
| `privacy/index.html` | `https://<domain>/privacy/` |
| `style.css` | `https://<domain>/style.css` |

Any static host works. On Vercel, point a project at this directory with no
framework preset and no build command — the defaults serve it as-is.

Check it locally first:

```bash
python3 -m http.server 8000     # then open http://localhost:8000
```

## Why the pages say what they say

They are written to be read by a Google reviewer as much as by a user. The homepage
has to make it obvious the app is real, what it does, and that the Google scopes it
asks for are needed for the feature it describes. The privacy policy has to name each
scope, say where the data goes, and carry the Limited Use disclosure verbatim.

Do not remove the Limited Use paragraph or the per-scope table — those are the parts
verification actually checks. See `../docs/google-verification.md`.
