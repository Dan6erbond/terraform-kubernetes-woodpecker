variable "namespace" {
  description = "Namespace to deploy workloads and configuration"
  type        = string
  default     = "default"
}

variable "match_labels" {
  description = "Match labels to add to the MariaDB deployment, will be merged with labels"
  type        = map(any)
  default     = {}
}

variable "server_labels" {
  description = "Labels to add to the Woodpecker server deployment"
  type        = map(any)
  default     = {}
}

variable "agent_labels" {
  description = "Labels to add to the Woodpecker agent deployment"
  type        = map(any)
  default     = {}
}

variable "image_registry" {
  description = "Image registry, e.g. gcr.io, docker.io"
  type        = string
  default     = ""
}

variable "server_image_repository" {
  description = "Image to start for the server"
  type        = string
  default     = "woodpeckerci/woodpecker-server"
}

variable "server_image_tag" {
  description = "Image tag to for the server"
  type        = string
  default     = "v0.15.6"
}

variable "agent_image_repository" {
  description = "Image to start for the agent"
  type        = string
  default     = "woodpeckerci/woodpecker-agent"
}

variable "agent_image_tag" {
  description = "Image tag to use for the agent"
  type        = string
  default     = "v0.15.6"
}

variable "woodpecker_agent_replicas" {
  description = "Number of agent replicas to deploy, setting to zero will disable agent deployment"
  type        = number
  default     = 2
}

variable "woodpecker_host" {
  description = "Woodpecker host in <scheme>://<hostname> format"
  type        = string
}

variable "woodpecker_admin" {
  description = "Comma-delimited list of Woodpecker admin users"
  type        = string
}

variable "woodpecker_open" {
  description = "Open Woodpecker registrations"
  type        = bool
  default     = true
}

variable "woodpecker_orgs" {
  description = "Comma-delimited list of organizations granted to use Woodpecker"
  type        = string
  default     = ""
}

variable "woodpecker_gitea" {
  description = "Enable Woodpecker Gitea integration"
  type        = bool
  default     = false
}

variable "woodpecker_gitea_url" {
  description = "Gitea URL"
  type        = string
  default     = ""
}

variable "woodpecker_gitea_client" {
  description = "Gitea client ID"
  type        = string
  default     = ""
}

variable "woodpecker_gitea_secret" {
  description = "Gitea client secret"
  type        = string
  default     = ""
}

variable "woodpecker_database_driver" {
  description = "Woodpecker database driver"
  type        = string
  default     = "postgres"
}

variable "woodpecker_database_datasource" {
  description = "Database URL"
  type        = string
  default     = ""
}
