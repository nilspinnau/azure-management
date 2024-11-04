


resource "azurerm_shared_image_gallery" "default" {
  count = var.shared_image_gallery.enabled == true ? 1 : 0

  name                = replace("gal-${var.resource_suffix}", "/[^A-Za-z0-9]+/", "")
  resource_group_name = var.resource_group_name
  location            = var.location

  # dynamic "sharing" {
  #   for_each = var.shared_image_gallery.config.enable_sharing == true ? var.shared_image_gallery.config.sharing : {}
  #   content {
  #     dynamic "community_gallery" {
  #       for_each = coalesce(var.shared_image_gallery.config.sharing.community_gallery, {})
  #       content {
  #         eula            = var.shared_image_gallery.config.sharing.community_gallery.eula
  #         prefix          = var.shared_image_gallery.config.sharing.community_gallery.prefix
  #         publisher_email = var.shared_image_gallery.config.sharing.community_gallery.publisher_email
  #         publisher_uri   = var.shared_image_gallery.config.sharing.community_gallery.publisher_uri
  #       }
  #     }
  #     permission = var.shared_image_gallery.config.sharing.permission
  #   }
  # }

  description = var.shared_image_gallery.config.description

  tags = coalesce(var.shared_image_gallery.config.tags, var.tags, {})
}