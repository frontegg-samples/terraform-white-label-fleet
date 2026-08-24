variable "workspace_name" {
  description = "Name of the Frontegg workspace (environment) the fleet lives in."
  type        = string
}

variable "frontegg_domain" {
  description = "The environment's default Frontegg domain, e.g. \"example.frontegg.com\"."
  type        = string
}

variable "brands" {
  description = <<-EOT
    Every brand in the fleet, keyed by a stable identifier.

    Adding a brand means adding one entry here. Nothing else in this configuration
    changes -- the workspace custom_domains set and the per-brand resources are both
    derived from this map.
  EOT

  type = map(object({
    name      = string
    auth_host = string
    app_url   = string
    mobile_apps = optional(object({
      ios = optional(list(object({
        bundle_id = string
        team_id   = string
      })), [])
      android = optional(list(object({
        package_name             = string
        sha256_cert_fingerprints = list(string)
      })), [])
    }), {})
    extra_redirect_uris = optional(list(string), [])
    metadata            = optional(map(string), {})
  }))
}

variable "country" {
  description = "Two-letter country code for the workspace, e.g. \"US\"."
  type        = string
}

variable "backend_stack" {
  description = "Backend stack reported for the workspace, e.g. \"Node\"."
  type        = string
  default     = "Node"
}

variable "frontend_stack" {
  description = "Frontend stack reported for the workspace, e.g. \"React\"."
  type        = string
  default     = "React"
}
