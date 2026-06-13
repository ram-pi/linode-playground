apiVersion: v1
kind: ConfigMap
metadata:
  name: litellm-config
  namespace: litellm-gateway
data:
  config.yaml: |
    model_list:
      - model_name: mistral-fra
        litellm_params:
          model: openai/mistralai/Mistral-7B-Instruct-v0.2
          api_base: http://${FRA_ENDPOINT}/v1
          api_key: os.environ/INFERENCE_API_KEY

      - model_name: mistral-sea
        litellm_params:
          model: openai/mistralai/Mistral-7B-Instruct-v0.2
          api_base: http://${SEA_ENDPOINT}/v1
          api_key: os.environ/INFERENCE_API_KEY

      - model_name: mistral-global
        litellm_params:
          model: openai/mistralai/Mistral-7B-Instruct-v0.2
          api_base: http://${FRA_ENDPOINT}/v1
          api_key: os.environ/INFERENCE_API_KEY

      - model_name: mistral-global
        litellm_params:
          model: openai/mistralai/Mistral-7B-Instruct-v0.2
          api_base: http://${SEA_ENDPOINT}/v1
          api_key: os.environ/INFERENCE_API_KEY

    router_settings:
      routing_strategy: simple-shuffle
      allowed_fails: 2
      cooldown_time: 30

    general_settings:
      master_key: os.environ/LITELLM_MASTER_KEY
