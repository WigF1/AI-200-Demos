"""
LP08 / M02 - Retrieve settings from Azure App Configuration

Demonstrates (mapped to deck slides):
  - Slide 17: SettingSelector filters by key prefix + label; provider load()
    returns a dictionary-like object
  - Slide 18: labels/composition - defaults load first, environment label
    overrides matching keys; FeatureManager.is_enabled()

Requires:
  pip install azure-appconfiguration-provider azure-identity
  export APPCONFIG_ENDPOINT=https://appcs-<suffix>.azconfig.io
"""
import os

from azure.appconfiguration.provider import SettingSelector, load
from azure.identity import DefaultAzureCredential
from azure.appconfiguration.provider import FeatureFlagOptions

ENDPOINT = os.environ["APPCONFIG_ENDPOINT"]
credential = DefaultAzureCredential()


def demo_labeled_config(label: str):
    # Slide 17: filter by key prefix and label.
    selects = [SettingSelector(key_filter="Pipeline:*", label_filter=label)]
    config = load(endpoint=ENDPOINT, credential=credential, selects=selects)
    batch_size = config.get("Pipeline:BatchSize", "not set")
    print(f"[{label}] Pipeline:BatchSize = {batch_size}")


def demo_feature_flags():
    # Slide 18: FeatureManager evaluates flags at runtime.
    config = load(
        endpoint=ENDPOINT,
        credential=credential,
        feature_flag_options=FeatureFlagOptions(enabled=True),
    )
    from azure.appconfiguration.provider import FeatureManager
    feature_manager = FeatureManager(config)
    if feature_manager.is_enabled("UseNewModel"):
        print("Feature flag ON: routing to the new model")
    else:
        print("Feature flag OFF: routing to the current model")


if __name__ == "__main__":
    demo_labeled_config("Production")
    demo_labeled_config("Development")
    demo_feature_flags()
