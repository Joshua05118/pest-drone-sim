"""Build a second Iris model with two illustrative single-beam ToF sensors."""

from pathlib import Path
from shutil import copytree
import xml.etree.ElementTree as ET

bridge = Path("/opt/bridge")
models = bridge / "models"
body = copytree(models / "iris_with_standoffs", models / "lucid_body")
vehicle = copytree(models / "iris_with_gimbal", models / "lucid_demo")
body_xml = ET.parse(body / "model.sdf")
vehicle_xml = ET.parse(vehicle / "model.sdf")
world = ET.parse(bridge / "worlds/iris_runway.sdf")
link = body_xml.find(".//link[@name='base_link']")
plugin = vehicle_xml.find(".//plugin[@filename='ArduPilotPlugin']")
assert link is not None and plugin is not None

for index, name, pose in [(1, "down", "0.20 0.08 0.02 0 1.5707963 0"),
                          (2, "front", "0.18 0 0 0 0 0")]:
    topic = f"/lucid/tof/{name}"
    link.append(ET.fromstring(f"""
      <sensor name="tof_{name}" type="gpu_lidar">
        <pose>{pose}</pose><topic>{topic}</topic>
        <update_rate>20</update_rate><always_on>true</always_on>
        <lidar>
          <scan><horizontal><samples>1</samples><resolution>1</resolution>
            <min_angle>0</min_angle><max_angle>0</max_angle></horizontal></scan>
          <range><min>0.05</min><max>4</max><resolution>0.01</resolution></range>
        </lidar>
      </sensor>"""))
    plugin.append(ET.fromstring(f"""
      <sensor><type>range</type><index>{index}</index><topic>{topic}</topic></sensor>"""))

# Keep scoped joint and link names used by the upstream controller.
include = next(i for i in vehicle_xml.findall(".//include")
               if i.findtext("uri") == "model://iris_with_standoffs")
include.find("uri").text = "model://lucid_body"
if include.find("name") is None:
    ET.SubElement(include, "name").text = "iris_with_standoffs"
next(uri for uri in world.findall(".//include/uri")
     if uri.text == "model://iris_with_gimbal").text = "model://lucid_demo"
world.find("world").append(ET.fromstring("""
  <model name="range_reference"><static>true</static><pose>0 2 0.5 0 0 0</pose>
    <link name="wall"><collision name="wall"><geometry><box><size>2 0.1 1</size></box></geometry></collision>
      <visual name="wall"><geometry><box><size>2 0.1 1</size></box></geometry></visual></link>
  </model>"""))
body_xml.write(body / "model.sdf")
vehicle_xml.write(vehicle / "model.sdf")
world.write(bridge / "worlds/lucid_tof.sdf")
