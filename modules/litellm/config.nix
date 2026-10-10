{ catalog }:

{
  model_list = catalog.modelList;
  general_settings = {
    master_key = "os.environ/LITELLM_MASTER_KEY";
    database_url = "os.environ/DATABASE_URL";
    enable_health_check_routing = true;
  };
  router_settings = {
    timeout = 900;
    cooldown_time = 600;
    routing_strategy = "simple-shuffle";
    enable_weighted_failover = true;
    num_retries = 3;
    model_group_alias = catalog.modelGroupAlias;
  };
  litellm_settings = {
    telemetry = false;
    drop_params = true;
  };
}
