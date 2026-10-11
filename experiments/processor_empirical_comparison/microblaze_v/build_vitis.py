import os
import vitis

root = os.path.dirname(os.path.abspath(__file__))
project = os.path.join(root, "project")
xsa = os.path.join(project, "mb_system_fixed.xsa")
workspace = os.path.join(root, "vitis_workspace")
source = os.path.join(root, "software")

client = vitis.create_client()
client.set_workspace(workspace)
platform = client.create_platform_component(name="mb_platform", hw_design=xsa, os="standalone", cpu="microblaze_0", domain_name="standalone_microblaze_0")
platform.build()
platform_xpfm = client.find_platform_in_repos("mb_platform")
app = client.create_app_component(name="dotprod_app", platform=platform_xpfm, domain="standalone_microblaze_0")
app.import_files(from_loc=source, files=["dotprod.c"], dest_dir_in_cmp="src", is_skip_copy_sources=False)
app.set_app_config(key="USER_COMPILE_OPTIONS", values="-O2 -ffreestanding -fno-builtin")
app.build()
print("VITIS_BUILD_COMPLETE")
vitis.dispose()
