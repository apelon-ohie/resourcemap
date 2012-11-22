class GatewaysController < ApplicationController
  before_filter :authenticate_user!
  def index
    method = Channel.nuntium_info_methods
    respond_to do |format|
      format.html 
      format.json { render json: current_user.channels.select('channels.id,channels.collection_id,channels.name,channels.password,channels.nuntium_channel_name,is_manual_configuration, channels.is_share').all.as_json(methods: method)}    
    end
  end

  def create
    #params[:gateway][:collection_id] = current_user.memberships.find_by_admin(true).collection_id  # to be refactor in near future 
    puts params[:gateway] 
    channel = current_user.channels.create params[:gateway]
    render json: channel.as_json
  end

  def update
    channel = Channel.find params[:id]
    channel.update_attributes params[:gateway]
    render json: channel
  end

  def destroy
    channel = Channel.find params[:id]
    channel.destroy
    render json: channel 
  end

  def try
    channel = Channel.find params[:gateway_id] 
    SmsNuntium.notify_sms [params[:phone_number]], 'Welcome to resource map!', channel.nuntium_channel_name    
    render json: channel.as_json
  end
end
