#!/usr/bin/env python3
import vitis
import os

xsa_path = os.path.abspath("./viterbi_zcu104_axis_wrapper.xsa")
workspace = os.path.abspath("./vitis_ws")

client = vitis.create_client()
client.set_workspace(workspace)

platform = client.create_platform_component(
    name="viterbi_platform",
    hw_design=xsa_path,
    os="standalone",
    cpu="psu_cortexa53_0",
    domain_name="standalone_domain",
)
platform.report()
platform.build()

platform_xpfm = client.find_platform_in_repos("viterbi_platform")
app = client.create_app_component(
    name="viterbi_hw_test",
    platform=platform_xpfm,
    domain="standalone_domain",
    template="empty_application",
)

print("PLATFORM_AND_APP_CREATED: OK")
vitis.dispose()
