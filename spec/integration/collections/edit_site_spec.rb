require 'spec_helper' 

describe "edit_site", :type => :request do 
 
  it "edit site", js:true do
    user = User.make(:email => 'user@manas.com.ar', :password => '1234567', :phone_number => '855123456789')
    page.save_screenshot 'create_collection.png'
    collection = create_collection_for (user)
    create_site_for (collection)
    login_as (user)
    visit collections_path
    find(:xpath, '//div[@id="collections-main"]/div[1]/div[2]/table/tbody/tr[1]/td/button').click
    find(:xpath, '//div[@id="collections-main"]/div[1]/div[2]/table/tbody/tr[1]/td/button').click
    click_link 'Edit Site'
    sleep 2
  	fill_in 'locationText', :with => '-37.991902, -57.602087'
  	sleep 3
    click_button 'Done'
  	sleep 4
  	expect(page).not_to have_content ('26.7574, 14.3574')
  end
end