require 'spec_helper'

describe AccessController do
	before(:each) do
		@member = stub_model(Member, :member_type => 'current', :billing_plan => 'full', :rfid => '1234', :key_enabled => true)
		Member.stub(:find_by_rfid) { @member }
		@door_controller = stub_model(DoorController, :address => "abc", :success_response => "OK")
		DoorController.stub(:find_by_address) { @door_controller }
	end

	it "assigns to @door_controller" do
		get :show, :address => @door_controller.address, :rfid => @member.rfid
		assigns(:door_controller).should eq(@door_controller)
	end

	it "assigns to @member" do
		get :show, :address => @door_controller.address, :rfid => @member.rfid
		assigns(:member).should eq(@member)
	end

	it "sees if the member should be granted access" do
		@member.should_receive(:access_enabled?)
		get :show, :address => @door_controller.address, :rfid => @member.rfid
	end

	it "gets door controller's success response if member should be granted access" do
		@door_controller.should_receive(:success_response)
		get :show, :address => @door_controller.address, :rfid => @member.rfid
	end

	it "gets door controller's error response if member should not be granted access" do
		@member.stub(:access_enabled?) { false }
		@door_controller.should_receive(:error_response)
		get :show, :address => @door_controller.address, :rfid => @member.rfid
	end

	it "logs the access" do
		AccessLog.should_receive(:create).with(
				:member => @member,
				:door_controller => @door_controller,
				:member_name => @member.full_name,
				:member_type => @member.member_type,
				:billing_plan => @member.billing_plan,
				:door_controller_location => @door_controller.location,
				:access_granted => true
			)
		get :show, :address => @door_controller.address, :rfid => @member.rfid
	end

	it "sees if the member should be sent an email" do
		@member.should_receive(:send_usage_email)
		get :show, :address => @door_controller.address, :rfid => @member.rfid
	end	

	it "renders the show template" do
		get :show, :address => @door_controller.address, :rfid => @member.rfid
		response.should render_template('show')
	end

end