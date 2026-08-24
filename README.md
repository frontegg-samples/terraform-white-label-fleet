# White-label fleet onboarding with Terraform

Onboarding a brand in a white-label fleet means repeating the same set of steps —
custom domain, tenant, application, allowed origin, redirect URIs — once per brand.
Done by hand that is several portal visits each, and the cost scales with the number
of brands rather than staying flat.

Built on the [Frontegg Terraform provider](https://registry.terraform.io/providers/frontegg/frontegg/latest/docs).

This example collapses those steps into a single map entry per brand.

```hcl
brands = {
  northwind = {
    name      = "Northwind Clinic"
    auth_host = "auth.northwind.example.com"
    app_url   = "https://app.northwind.example.com"

    mobile_apps = {
      ios     = [{ bundle_id = "com.example.northwind", team_id = "ABCDE12345" }]
      android = [{ package_name = "com.example.northwind", sha256_cert_fingerprints = ["14:6D:..."] }]
    }
  }
}
```

Adding a brand is adding an entry. Nothing else in the configuration changes.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
export FRONTEGG_CLIENT_ID=... FRONTEGG_SECRET_KEY=...
terraform init
terraform plan
```

Generate the credentials in the Frontegg portal under **[ENVIRONMENT] → Keys & domains**.
They are environment-scoped, so an apply only ever touches the environment they belong to.

Both default to the EU region. For another region set `FRONTEGG_API_BASE_URL` and
`FRONTEGG_PORTAL_BASE_URL`, or configure them on the `provider` block.

Read the plan before applying. Several Frontegg resources are `ForceNew`, so editing
an existing brand can mean a destroy and recreate rather than an update.

## Why custom domains and allowed origins live in the root, not the module

Both `custom_domains` and `allowed_origins` are *attributes* of the single
`frontegg_workspace` resource, not resources per domain. Terraform cannot have several
resources managing one attribute — they would each plan to overwrite the others on
every apply.

So the workspace aggregates them across every brand:

```hcl
custom_domains  = [for brand in var.brands : brand.auth_host]
allowed_origins = [for brand in var.brands : brand.app_url]
```

and the per-brand module takes `auth_host` and `app_url` as inputs it *uses* but does
not own. This is the one place the fleet cannot be expressed as "everything for a brand
lives in the brand module", and it is worth understanding before extending this example.

There is a standalone `frontegg_allowed_origin` resource, and it works correctly per
brand. It is not used here because the workspace already sets `allowed_origins` from
the same data, and two things managing one attribute is what this section is about.
Aggregating in the root is also a single API call rather than one per brand.

The DNS side is still yours: each `auth_host` needs a CNAME pointing at the environment,
and Frontegg will report the domain as `Pending` until that record resolves.

## Mobile app registration

Frontegg serves the `apple-app-site-association` and `assetlinks.json` files that bind
a mobile app to its auth host, and `frontegg_associated_domain` registers the apps that
go into them. The brand module registers whatever `mobile_apps` lists, so a brand's apps
are bound by the same map entry that creates the brand.

Those registrations are environment-wide rather than per brand, so two brands must not
declare the same app. In a white-label fleet each brand ships its own, so they stay
distinct.

iOS is registered by its `{teamId}.{bundleId}` identifier and Android by its package name
plus signing-certificate fingerprints, so the two are configured separately.

## Mobile redirect URIs

The Frontegg mobile SDKs do not read their OAuth callback from configuration. They
derive it from the auth host:

```
https://{auth_host}/oauth/account/redirect/{ios|android}/{bundleId}
```

The app cannot be told to use anything else, so this exact URI has to be registered or
authorization fails with `Redirect uri wasn't found` — and it fails *after* the user has
already authenticated, which makes it look like a broken login rather than a missing
setting.

The module derives those URIs from `auth_host` and `mobile_apps` so they cannot drift
from what the SDK actually sends. List every app that ships for the brand.

## What this example does not cover

- **Passkeys.** WebAuthn `rp.id` is derived by the identity service, not set through
  this provider. If you intend to scope passkeys per brand, settle that *before* a
  brand's first passkey enrolment — changing `rp.id` afterwards orphans credentials
  already registered against the old value.
- **Per-brand branding and email templates.** `frontegg_email_template` and the admin
  portal resources exist and can be folded into the brand module if you want them
  versioned alongside the rest.
