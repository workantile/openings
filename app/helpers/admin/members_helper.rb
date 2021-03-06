module Admin::MembersHelper
	def build_filters
		type_list = Member::MEMBER_TYPES.collect { |type| [type, type] }
		type_list << ['all', 'all']
		plan_list = Member::BILLING_PLANS.collect { |plan| [plan, plan] }
		plan_list << ['all', 'all']
		member_filter(type_list) + plan_filter(plan_list)
	end

	def member_filter(type_list)
		content_tag :div, class: "form-group" do
			label_tag(:type, "Filter by member type") +
			select_tag(
				:type,
				options_for_select(type_list, params[:type]),
				{ "data-url": admin_members_url, class: "form-control" }
			)
		end
	end

	def plan_filter(plan_list)
		content_tag :div, class: 'form-group' do
			label_tag(:plan, "Filter by billing plan") +
			select_tag(
				:plan,
				options_for_select(plan_list, params[:plan]),
				{ "data-url": admin_members_url, class: "form-control" }
			)
		end
	end
end
