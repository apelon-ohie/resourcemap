class SitesController < ApplicationController
  before_filter :setup_guest_user, :if => Proc.new { collection && collection.public }
  before_filter :authenticate_user!, :except => [:index, :search], :unless => Proc.new { collection && collection.public }

  authorize_resource :only => [:index, :search], :decent_exposure => true

  expose(:sites) {if !current_user_snapshot.at_present? && collection then collection.site_histories.at_date(current_user_snapshot.snapshot.date) else collection.sites end}
  expose(:site) { Site.find(params[:site_id] || params[:id]) }

  def index
    search = new_search

    search.name_start_with params[:name] if params[:name].present?
    search.offset params[:offset]
    search.limit params[:limit]

    render json: search.ui_results.map { |x| x['_source'] }
  end

  def show
    search = new_search

    search.id params[:id]
    # If site does not exists, return empty object
    result = search.ui_results.first['_source'] rescue {}
    render json: result
  end

  def create
    site_params = JSON.parse params[:site]

    site = collection.sites.new(user: current_user)

    process_site_params(site, site_params)

    if site.valid?
      site.save!
      current_user.site_count += 1
      current_user.update_successful_outcome_status
      current_user.save!
      render json: site, :layout => false
    else
      render json: site.errors.messages, status: :unprocessable_entity, :layout => false
    end
  end

  def update
    site_params = JSON.parse params[:site]
    site.user = current_user
    site.properties_will_change!

    process_site_params(site, site_params)

    if site.valid?
      site.save!
      render json: site, :layout => false
    else
      render json: site.errors.messages, status: :unprocessable_entity, :layout => false
    end
  end

  def update_property
    field = site.collection.fields.where_es_code_is params[:es_code]

    #Pending: Check custom site permission
    return head :forbidden unless can?(:update_site_property, field)

    site.user = current_user
    site.properties_will_change!

    site.properties[params[:es_code]] = field.decode_from_ui(params[:value])
    if site.valid?
      site.save!
      render json: site, :status => 200, :layout => false
    else
      error_message = site.errors[:properties][0][params[:es_code]]
      render json: {:error_message => error_message}, status: :unprocessable_entity, :layout => false
    end
  end

  def search
    zoom = params[:z].to_i

    search = MapSearch.new params[:collection_ids], user: current_user

    search.zoom = zoom
    search.bounds = params if zoom >= 2
    search.exclude_id params[:exclude_id].to_i if params[:exclude_id].present?
    search.after params[:updated_since] if params[:updated_since]
    search.full_text_search params[:search] if params[:search].present?
    search.location_missing if params[:location_missing].present?
    if params[:selected_hierarchies].present?
      search.selected_hierarchy params[:hierarchy_code], params[:selected_hierarchies]
    end
    search.where params.except(:action, :controller, :format, :n, :s, :e, :w, :z, :collection_ids, :exclude_id, :updated_since, :search, :location_missing, :hierarchy_code, :selected_hierarchies)

    search.apply_queries
    render json: search.results
  end

  def destroy
    site.user = current_user
    site.destroy
    render json: site
  end

  private

  def process_site_params(site, site_params)
    # TODO: Use cancan and return forbbiden if the user does not have permission
    user_membership = current_user.membership_in(collection)
    site.name = site_params["name"] if site_params.has_key?("name") && user_membership.can_update?("name")
    site.lat = site_params["lat"] if site_params.has_key?("lat") && user_membership.can_update?("location")
    site.lng = site_params["lng"] if site_params.has_key?("lng") && user_membership.can_update?("location")
    site.properties = prepare_from_ui(site_params) if site_params.has_key?("properties")
  end

  def prepare_from_ui(parameters)
    fields = collection.fields.index_by(&:es_code)
    decoded_properties = {}
    site_properties = parameters.delete "properties"
    site_properties ||= {}
    site_properties.each_pair do |es_code, value|
      decoded_properties[es_code] = fields[es_code].decode_from_ui(value)
    end

    decoded_properties
  end

end
