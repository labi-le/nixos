from litellm import Router

_original_set_model_list = Router.set_model_list
_original_get_model_group_info = Router.get_model_group_info


def _declares_reasoning_levels(model_info):
    return bool((model_info or {}).get("reasoning_effort_levels"))


def _with_reasoning_effort(params):
    params = list(params or [])
    if "reasoning_effort" not in params:
        params.append("reasoning_effort")
    return params


def _publish_to_deployments(router):
    for deployment in router.model_list:
        model_info = deployment.get("model_info") or {}
        if _declares_reasoning_levels(model_info):
            model_info["supported_openai_params"] = _with_reasoning_effort(model_info.get("supported_openai_params"))


def _patched_set_model_list(self, model_list):
    _original_set_model_list(self, model_list)
    _publish_to_deployments(self)


def _patched_get_model_group_info(self, model_group):
    info = _original_get_model_group_info(self, model_group)
    if info is not None:
        for deployment in self.model_list:
            if deployment.get("model_name") == model_group:
                if _declares_reasoning_levels(deployment.get("model_info")):
                    info.supported_openai_params = _with_reasoning_effort(info.supported_openai_params)
                break
    return info


def install_reasoning_effort_params():
    Router.set_model_list = _patched_set_model_list
    Router.get_model_group_info = _patched_get_model_group_info
