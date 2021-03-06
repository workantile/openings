require 'acceptance/acceptance_helper'

feature 'Updating members', %q{
  In order to updage members in the system
  As an admin
  I want to update members
} do

  background do
    # Given I am an admin
    @i_am_an_admin = FactoryBot.create(:admin)

    # And I have signed in
    sign_in_as @i_am_an_admin

    # And I have a member I want to update
    @member_to_update = FactoryBot.create(:full_member)

    # When I visit the update member page
    visit edit_admin_member_path(@member_to_update)

  end

  scenario 'Updating a new member correctly' do
    # And I update a new member correctly
    fill_in 'member_first_name',        :with => 'joe'
    fill_in 'member_last_name',         :with => 'blow'
    fill_in 'member_email',             :with => 'jblow@foobar.com'
    fill_in 'member_task',              :with => 'cruise director'
    fill_in 'member_anniversary_date',  :with => Date.today.strftime("%m/%d/%Y")
    fill_in 'member_rfid',              :with => '1234'
    select 'current',                   :from => 'Member type'
    select 'full',                      :from => 'Billing plan'
    click_button 'Update member'

    # Then I should not see an error message.
    expect(page).to have_no_selector('div.field_with_errors')
  end

  scenario 'Screwing up updating a new member' do
    # And I screw up updating a new member
    fill_in 'member_first_name',        :with => 'joe'
    fill_in 'member_last_name',         :with => 'blow'
    fill_in 'member_email',             :with => ''
    fill_in 'member_task',              :with => 'cruise director'
    fill_in 'member_anniversary_date',  :with => Date.today.strftime("%m/%d/%Y")
    fill_in 'member_rfid',              :with => '1234'
    select 'current',                   :from => 'Member type'
    select 'full',                      :from => 'Billing plan'
    click_button 'Update member'

    # Then I should see an error message
    expect(page).to have_selector('div.field_with_errors')
  end
end