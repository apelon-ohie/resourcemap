class ExecVisitor < Visitor
  MSG = {
    :query_not_match => "No result. Your query did not match.",
    :update_successfully => "Data has been successfully updated.",
    :can_not_update => "You have no access right to update. Please contact the layer's owner for more information.", :can_not_query => "You have no access right to view. Please contact the layer's owner for more information.", :can_not_use_gateway => "You cannot use this channel for viewing or updating this layer. Please contact the layer's owner for more information."
  }

  attr_accessor :context
def initialize(context={})
    self.context = context
  end

  def visit_query_command(node)
    if collection = Collection.find_by_id(node.collection_id.value)
      #raise MSG[:can_not_use_gateway] unless can_use_gateway?(collection)
      raise MSG[:can_not_query]       unless can_view?(node.conditional_expression.to_options, node.sender, collection)
      if reply = collection.query_sites(node.conditional_expression.to_options)
        reply.empty? ? MSG[:query_not_match] : reply
      end
    end
  end

  def visit_update_command(node)
    id = node.resource_id.text_value

    if site = Site.find_by_id_with_prefix(id)
      #raise MSG[:can_not_use_gateway] unless can_use_gateway?(site.collection)
      raise MSG[:can_not_update]      unless can_update?(node.property_list, node.sender, site)
      update site, node.property_list, node.sender
      MSG[:update_successfully]
    else
      raise "Can't find site with ID=#{id}" if site.nil?
    end
  end

  def can_use_gateway?(colleciton)
    gateway = Gateway.find_by_nuntium_name(self.context[:channel])
    gateway.nil? || gateway.allows_layer?(layer)
  end

  def can_view?(option, sender, collection)
    sender && sender.can_view?(collection, option[:code])
  end

  def can_update?(node, sender, site)
    properties = node_to_properties node
    sender && sender.can_update?(site, properties)
  end

  private

  def update(site, node, sender)
    properties = node_to_properties(node)
    update_properties site, sender, properties
  end

  def update_properties(site, user, props)
    site.user = user
    props.each do |p|
      field = Field.find_by_code(p.values[0])
      site.properties[field.es_code] = p.values[1]
    end
    site.save!
  end

  def node_to_properties(node)
    properties = []
		until node and node.kind_of? AssignmentExpressionNode
      properties << node.assignment_expression.to_options
      node = node.next
    end
    properties << node.to_options
  end
end
