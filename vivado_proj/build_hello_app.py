#!/usr/bin/env python3
import vitis
import os

workspace = os.path.abspath("./vitis_ws")

client = vitis.create_client()
client.set_workspace(workspace)

app = client.get_component(name="hello_test")
app.build()

print("HELLO_APP_BUILD_RESULT: OK")
vitis.dispose()
