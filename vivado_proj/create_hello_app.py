#!/usr/bin/env python3
import vitis
import os

workspace = os.path.abspath("./vitis_ws")

client = vitis.create_client()
client.set_workspace(workspace)

platform_xpfm = client.find_platform_in_repos("viterbi_platform")
app = client.create_app_component(
    name="hello_test",
    platform=platform_xpfm,
    domain="standalone_domain",
    template="hello_world",
)

print("HELLO_APP_CREATED: OK")
vitis.dispose()
