terraform {
  required_providers {
    frontegg = {
      source = "frontegg/frontegg"
    }
  }
}

locals {
  login_url = "https://${var.auth_host}"

  # The callback each Frontegg mobile SDK derives from the auth host. It is not
  # configurable in the app -- the SDK builds this exact string -- so it has to be
  # registered verbatim.
  mobile_redirect_uris = concat(
    [for app in var.mobile_apps.ios : "https://${var.auth_host}/oauth/account/redirect/ios/${app.bundle_id}"],
    [for app in var.mobile_apps.android : "https://${var.auth_host}/oauth/account/redirect/android/${app.package_name}"],
  )

  redirect_uris = toset(concat(local.mobile_redirect_uris, var.extra_redirect_uris))
}

resource "frontegg_tenant" "this" {
  name              = var.name
  key               = var.key
  application_uri   = var.app_url
  selected_metadata = var.metadata
}

resource "frontegg_application" "this" {
  name        = var.name
  app_url     = var.app_url
  login_url   = local.login_url
  access_type = "FREE_ACCESS"
  is_active   = true
  is_default  = false
  type        = "web"
}

resource "frontegg_application_tenant_assignment" "this" {
  app_id    = frontegg_application.this.id
  tenant_id = frontegg_tenant.this.id
}

resource "frontegg_redirect_uri" "this" {
  for_each = local.redirect_uris

  redirect_uri = each.value
}

# Registers the apps into the association files Frontegg serves, which is what binds
# them to the auth host for Universal Links and App Links.
#
# These registrations are environment-wide rather than per brand, so two brands must
# not declare the same app. In a white-label fleet each brand ships its own app, so
# they stay distinct.
resource "frontegg_associated_domain" "ios" {
  for_each = { for app in var.mobile_apps.ios : app.bundle_id => app }

  platform = "ios"
  app_id   = "${each.value.team_id}.${each.value.bundle_id}"
}

resource "frontegg_associated_domain" "android" {
  for_each = { for app in var.mobile_apps.android : app.package_name => app }

  platform                 = "android"
  package_name             = each.value.package_name
  sha256_cert_fingerprints = each.value.sha256_cert_fingerprints
}
