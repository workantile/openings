require 'acceptance/acceptance_helper'

feature 'Running reports', %q{
  In order to see what is going on in the system
  As an admin
  I want to run reports
} do
  
  background do
    # Given I am an admin
    @i_am_an_admin = FactoryGirl.create(:admin)
    
    # And I have signed in
    sign_in_as @i_am_an_admin

    # When I visit the new admin page
    visit 'reports'
    
  end

  scenario "reporting access log" do
    page.should have_content('beginning')
    page.should have_content('ending')
    page.should have_content('Access log')
  end

end