class ApplicationHelper::ToolbarChooser
  include RestfulControllerMixin

  # Return a blank tb if a placeholder is needed for AJAX explorer screens, return nil if no center toolbar to be shown
  def center_toolbar_filename
    return "#{@center_toolbar}_center_tb" if @center_toolbar

    @explorer ? center_toolbar_filename_explorer : center_toolbar_filename_classic
  end

  def x_view_toolbar_filename
    if x_download_view_tb_render?
      'download_view_tb'
    elsif %w[miq_capacity_utilization].include?(@layout)
      'miq_capacity_view_tb'
    elsif @record && @explorer && (%w[catalogs].include?(@layout) || %w[performance timeline].include?(@display))
      nil
    elsif @layout == 'report'
      @report ? "report_view_tb" : nil
    elsif %w[vm_infra vm_cloud].include?(@layout)
      @showtype == 'main' ? 'x_summary_view_tb' : nil
    end
  end

  def view_toolbar_filename
    if render_download_view_tb?
      'download_view_tb'
    elsif @lastaction == "compare_miq" || @lastaction == "compare_compress"
      'compare_view_tb'
    elsif @lastaction == "drift"
      'drift_view_tb'
    elsif %w[ems_container ems_infra ems_physical_infra].include?(@layout) && %w[main dashboard].include?(@display)
      'dashboard_summary_toggle_view_tb'
    elsif %w[container_project].include?(@layout)
      'container_project_view_tb'
    elsif %w[all_tasks condition timeline diagnostics miq_action miq_alert miq_alert_set miq_event_definition miq_policy miq_policy_set my_tasks miq_server usage services].exclude?(@layout) &&
      !@layout.starts_with?("miq_request") && @display == "main" &&
      @showtype == "main" && !@in_a_form
      'summary_view_tb'
    end
  end

  private

  delegate :session, :x_node, :x_active_tree, :super_admin_user?, :render_download_view_tb?,
           :parse_nodetype_and_id, :to => :@view_context

  def initialize(view_context, view_binding, instance_data)
    @view_context = view_context
    @view_binding = view_binding

    instance_data.each do |name, value|
      instance_variable_set(:"@#{name}", value)
    end
  end

  def center_toolbar_name_vm_or_template
    if @record
      return "vm_performance_tb" if @display == "performance"

      case @record
      when ManageIQ::Providers::CloudManager::Vm
        'x_vm_cloud_center_tb'
      when ManageIQ::Providers::CloudManager::Template
        'x_template_cloud_center_tb'
      when ManageIQ::Providers::InfraManager::Vm
        'x_vm_center_tb'
      when ManageIQ::Providers::InfraManager::Template
        'x_miq_template_center_tb'
      else
        raise 'FIXME: this would return "x_# {@button_group}_center_tb' # FIXME: remove this branch
      end
    else
      case x_active_tree
      when :images_filter_tree, :images_tree       then 'template_clouds_center_tb'
      when :instances_filter_tree, :instances_tree then 'vm_clouds_center_tb'
      when :templates_images_filter_tree           then 'miq_templates_center_tb'
      when :templates_filter_tree                  then 'template_infras_center_tb'
      when :vms_filter_tree, :vandt_tree           then 'vm_infras_center_tb'
      when :vms_instances_filter_tree              then 'vms_center_tb'
      end
    end
  end

  # Return explorer based toolbar file name
  def center_toolbar_filename_explorer
    if %w[vm_cloud vm_infra vm_or_template].include?(@layout)
      center_toolbar_name_vm_or_template
    elsif x_active_tree == :ae_tree
      center_toolbar_filename_automate
    elsif x_active_tree == :infra_networking_tree
      infra_networking_tree_center_tb(x_node_split)
    elsif x_active_tree == :containers_tree
      center_toolbar_filename_containers
    elsif %i[sandt_tree svccat_tree stcat_tree ot_tree].include?(x_active_tree)
      center_toolbar_filename_services
    elsif @layout == "chargeback_report"
      center_toolbar_filename_chargeback_report
    elsif @layout == "miq_ae_tools"
      super_admin_user? ? "miq_ae_tools_simulate_center_tb" : nil
    elsif @layout == "ops"
      center_toolbar_filename_ops
    elsif @layout == "pxe"
      center_toolbar_filename_pxe
    elsif @layout == "storage"
      center_toolbar_filename_storage
    elsif @layout == "report"
      center_toolbar_filename_report
    elsif @layout == "miq_ae_customization"
      center_toolbar_filename_automate_customization
    end
  end

  def center_toolbar_filename_automate
    nodes = x_node_split
    case nodes.first
    when "root" then "miq_ae_domains_center_tb"
    when "aen"  then domain_or_namespace_toolbar(nodes.last)
    when "aec"  then case @sb[:active_tab]
                     when "methods" then  "miq_ae_methods_center_tb"
                     when "props"   then  "miq_ae_class_center_tb"
                     when "schema"  then  "miq_ae_fields_center_tb"
                     else                 "miq_ae_instances_center_tb"
                     end
    when "aei"  then "miq_ae_instance_center_tb"
    when "aem"  then "miq_ae_method_center_tb"
    end
  end

  def domain_or_namespace_toolbar(node_id)
    ns = MiqAeNamespace.find(node_id)
    if ns.domain?
      "miq_ae_domain_center_tb"
    elsif !ns.domain?
      "miq_ae_namespace_center_tb"
    end
  end

  def center_toolbar_filename_automate_customization
    if x_active_tree == :old_dialogs_tree
      return @dialog ? "miq_dialog_center_tb" : "miq_dialogs_center_tb"
    elsif x_active_tree == :dialogs_tree
      if x_node == "root"
        return "dialogs_center_tb"
      elsif @record && !@in_a_form
        return "dialog_center_tb"
      end
    elsif x_active_tree == :ab_tree
      if x_node != "root"
        nodes = x_node.split('_')
        if nodes.length == 2 && nodes[0] == "xx-ab"
          return "custom_button_set_center_tb"  # CI node is selected
        elsif (nodes.length == 1 && nodes[0].split('-').length == 3 && nodes[0].split('-')[1] == "ub") ||
              (nodes.length == 3 && nodes[0] == "xx-ab")
          return "custom_buttons_center_tb"     # group node is selected
        else
          return "custom_button_center_tb"      # button node is selected
        end
      end
    elsif @in_a_form # to show buttons on dialog add/edit screens
      return "dialog_center_tb"
    end
    nil
  end

  def center_toolbar_filename_services
    if x_active_tree == :sandt_tree
      if TreeBuilder.get_model_for_prefix(@nodetype) == "ServiceTemplate"
        "servicetemplate_center_tb"
      elsif @sb[:buttons_node]
        nodes = x_node.split('_')
        if nodes.length == 3 && nodes[2].split('-').first == "cbg"
          return "catalogitem_buttons_center_tb"
        else
          return "catalogitem_button_center_tb"
        end
      else
        "servicetemplates_center_tb"
      end
    elsif x_active_tree == :stcat_tree
      if TreeBuilder.get_model_for_prefix(@nodetype) == "ServiceTemplateCatalog"
        "servicetemplatecatalog_center_tb"
      else
        "servicetemplatecatalogs_center_tb"
      end
    elsif x_active_tree == :ot_tree
      return nil if x_node == "xx-otovf" || @record.kind_of?(ManageIQ::Providers::Vmware::InfraManager::OrchestrationTemplate)
      if %w[root xx-otcfn xx-othot xx-otazu xx-otazs xx-otvnf xx-otvap xx-ovf].include?(x_node)
        "orchestration_templates_center_tb"
      else
        "orchestration_template_center_tb"
      end
    end
  end

  def center_toolbar_filename_containers
    x_node == 'root' ? 'containers_center_tb' : 'container_center_tb'
  end

  def center_toolbar_filename_chargeback_report
    return "chargeback_center_tb" if @report
    nil
  end

  def center_toolbar_filename_ops
    if x_active_tree == :settings_tree
      if x_node.split('-').last == "msc"
        return "miq_schedules_center_tb"
      elsif x_node.split('-').first == "msc"
        return "miq_schedule_center_tb"
      elsif x_node.split('-').last == "sis"
        return "scan_profiles_center_tb"
      elsif x_node.split('-').first == "sis"
        return "scan_profile_center_tb"
      elsif x_node.split('-').last == "z"
        return "zones_center_tb"
      elsif x_node_split.first == "z" && @sb[:active_tab] != "settings_smartproxy_affinity"
        return "zone_center_tb"
      end
    elsif x_active_tree == :diagnostics_tree
      if x_node == "root"
        return "diagnostics_region_center_tb"
      elsif x_node.split('-').first == "svr"
        return "diagnostics_server_center_tb"
      elsif x_node.split('-').first == "z"
        return "diagnostics_zone_center_tb"
      end
    elsif x_active_tree == :rbac_tree
      node = x_node.split('-')
      if node.last == "g"
        return "miq_groups_center_tb"
      elsif node.first == "g"
        return "miq_group_center_tb"
      elsif node.last == "u"
        return "users_center_tb"
      elsif node.first == "u"
        return "user_center_tb"
      elsif node.last == "ur"
        return "user_roles_center_tb"
      elsif node.first == "ur"
        return "user_role_center_tb"
      elsif node.last == "tn"
        return "tenants_center_tb"
      elsif node.first == "tn" && @record
        return "tenant_center_tb"
      end
    end
    nil
  end

  def center_toolbar_filename_report
    if x_active_tree == :db_tree
      node = x_node
      if %w[root xx-g].include?(node)
        return nil
      elsif node.split('-').length == 3
        return "miq_widget_sets_center_tb"
      else
        return "miq_widget_set_center_tb"
      end
    elsif x_active_tree == :savedreports_tree
      if x_node == "root" || parse_nodetype_and_id(x_node).first != "rr"
        return "saved_reports_center_tb"
      else
        return "saved_report_center_tb"
      end
    elsif x_active_tree == :reports_tree
      nodes = x_node.split('-')
      if nodes.length == 5
        # on report show
        return "miq_report_center_tb"
      elsif nodes.length == 6
        # on savedreport in reports tree
        return "saved_report_center_tb"
      else
        # on folder node
        return "miq_reports_center_tb"
      end
    elsif x_active_tree == :schedules_tree
      return x_node == "root" ? "miq_report_schedules_center_tb" : "miq_report_schedule_center_tb"
    elsif x_active_tree == :widgets_tree
      node = x_node
      return node == "root" || node.split('-').length == 2 ? "miq_widgets_center_tb" : "miq_widget_center_tb"
    end
    nil
  end

  def center_toolbar_filename_pxe
    if x_active_tree == :pxe_servers_tree
      if x_node == "root"
        return "pxe_servers_center_tb"
      elsif x_node.split('-').first == "pi"
        return "pxe_image_center_tb"
      elsif x_node.split('-').first == "wi"
        return "windows_image_center_tb"
      else
        return "pxe_server_center_tb"
      end
    elsif x_active_tree == :customization_templates_tree
      if x_node_split.first == 'ct'
        return "customization_template_center_tb"
      else
        return "customization_templates_center_tb"
      end
    elsif x_active_tree == :pxe_image_types_tree
      if x_node == "root"
        return "pxe_image_types_center_tb"
      else
        return "pxe_image_type_center_tb"
      end
    elsif x_active_tree == :iso_datastores_tree
      if x_node == "root"
        return "iso_datastores_center_tb"
      elsif x_node_split.first == "isi"
        # on image node
        return "iso_image_center_tb"
      else
        return "iso_datastore_center_tb"
      end
    end
    nil
  end

  def center_toolbar_filename_storage
    if x_active_tree == :storage_tree
      if x_node_split.first == 'ds'
        return "storage_center_tb"
      else
        return "storages_center_tb"
      end
    elsif x_active_tree == :storage_pod_tree
      nodetype = x_node_split.first
      if nodetype == 'ds'
        return "storage_center_tb"
      elsif nodetype != 'root'
        return "storages_center_tb"
      end
    end
    nil
  end

  # Return non-explorer based toolbar file name
  def center_toolbar_filename_classic
    # Original non vmx view code follows
    # toolbar buttons on sub-screens
    to_display = %w[availability_zones cloud_networks cloud_object_store_containers cloud_subnets configured_systems
                    cloud_tenants cloud_volumes ems_clusters flavors floating_ips host_aggregates hosts host_initiators host_initiator_groups
                    volume_mappings network_ports network_routers network_services orchestration_stacks resource_pools
                    security_groups security_policies security_policy_rules storages physical_storages storage_services]
    to_display_center = %w[stack_orchestration_template cloud_object_store_objects generic_objects physical_servers guest_devices]
    performance_layouts = %w[vm host ems_container]

    if @lastaction == 'show' && (@view || @display != 'main') && !@layout.starts_with?("miq_request")
      if @display == "vms" || @display == "all_vms"
        return "vm_infras_center_tb"
      elsif @display == "images"
        return "template_clouds_center_tb"
      elsif @display == "instances"
        return "vm_clouds_center_tb"
      elsif @display == "miq_templates"
        return "template_infras_center_tb"
      elsif performance_layouts.include?(@layout) && @display == "performance"
        return "#{@explorer ? "x_" : ""}vm_performance_tb"
      elsif @display == "dashboard"
        return "#{@layout}_center_tb"
      elsif to_display.include?(@display)
        return "#{@display}_center_tb"
      elsif to_display_center.include?(@display)
        return "#{@display}_center"
      elsif @layout == 'ems_container'
        return nil if @display == 'custom_button_events'
        return "#{@display}_center"
      end
    elsif @display == 'generic_objects'
      return @lastaction == 'generic_object' ? nil : 'generic_objects_center'
    elsif @lastaction == "compare_miq" || @lastaction == "compare_compress"
      return "compare_center_tb"
    elsif @lastaction == "drift_history"
      return "drifts_center_tb"
    elsif @lastaction == "drift"
      return "drift_center_tb"
    else
      return nil if @in_a_form

      # show_list and show screens
      if %w[auth_key_pair_cloud
            availability_zone
            host_aggregate
            cloud_object_store_object
            cloud_object_store_container
            cloud_tenant
            cloud_volume
            cloud_volume_backup
            cloud_volume_snapshot
            cloud_volume_type
            configuration_job
            configuration_script
            configured_system
            container
            container_group
            container_node
            container_service
            persistent_volume
            ems_cloud
            ems_cluster
            ems_configuration
            ems_container
            container_project
            container_route
            container_replicator
            container_image
            ems_network
            security_group
            security_policy
            security_policy_rule
            floating_ip
            cloud_subnet
            network_router
            network_port
            network_service
            network_service_rule
            cloud_database
            cloud_network
            load_balancer
            container_image_registry
            ems_infra
            ems_physical_infra
            flavor
            host
            host_initiator
            host_initiator_group
            volume_mapping
            container_build
            infra_networking
            ems_storage
            orchestration_stack
            physical_rack
            physical_server
            physical_switch
            physical_storage
            placement_group
            container_template
            storage_service
            resource_pool
            timeline
            usage
            guest_device
            generic_object_definition].include?(@layout)

        return @lastaction == 'show_list' ? "#{@layout.pluralize}_center_tb" : "#{@layout}_center_tb"

      elsif @layout == "configuration_profile"
        return "configuration_profile_center_tb"
      elsif @layout == "configuration" && @tabform == "ui_4"
        return "time_profiles_center_tb"
      elsif @layout == "diagnostics"
        return "diagnostics_center_tb"
      elsif @layout == "miq_policy_logs" || @layout == "miq_ae_logs"
        return "logs_center_tb"
      elsif @layout.to_s.starts_with?("miq_request_")
        return @lastaction == 'show_list' ? 'miq_requests_center_tb' : 'miq_request_center_tb'
      elsif %w[my_tasks all_tasks].include?(@layout)
        return "tasks_center_tb"
      end
    end
    nil
  end

  def x_node_split
    x_node.split('-')
  end

  def cs_filter_tree_center_tb(nodes)
    case nodes.first
    when "root", "ms", "xx", "csa", "csf" then "configured_systems_center_tb"
    end
  end

  def configuration_scripts_tree_center_tb(nodes)
    if %w[root at].include?(nodes.first)
      "configuration_scripts_center_tb"
    else
      "configuration_script_center_tb"
    end
  end

  def infra_networking_tree_center_tb(nodes)
    if %w[root e h c].include?(nodes.first)
      "infra_networkings_center_tb"
    end
  end

  def configuration_profile_center_tb
    if @sb[:active_tab] == "configured_systems"
      "unassigned_profiles_group_center_tb"
    end
  end

  def inventory_group_center_tb
    if @sb[:active_tab] == "configured_systems"
      "configured_systems_ansible_center_tb"
    end
  end

  NO_DOWNLOAD_VIEW_BUTTONS = %w[chargeback_assignment
                           chargeback_rate
                           chargeback_report
                           generic_object
                           generic_object_definition
                           miq_ae_class
                           miq_ae_customization
                           miq_ae_tools
                           miq_capacity_utilization
                           ops
                           pxe
                           report].to_set.freeze

  def x_download_view_tb_render?
    @record.nil? && @explorer && !NO_DOWNLOAD_VIEW_BUTTONS.include?(@layout)
  end
end
