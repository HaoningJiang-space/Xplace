import sys, json
sys.argv = ["probe"]
import torch
from utils import IOParser
params = json.load(open("/data/ziheng/wzh/bridge/gcd.json"))
print("params keys:", list(params.keys()), flush=True)
parser = IOParser()
rawdb, gpdb = parser.read(params, verbose_log=False, log_level=2,
                          lite_mode=True, random_place=False, num_threads=8)
print("=== parser.read OK ===", flush=True)
methods = ["coreInfo","net_names","pin_names","node_names","microns",
           "siteWidth","siteHeight","node_cpos_tensor","node_lpos_tensor",
           "node_size_tensor","pin_rel_cpos_tensor","pin_rel_lpos_tensor",
           "pin_size_tensor","pin_id2node_id_tensor","hyperedge_info_tensor",
           "node2pin_info_tensor","region_info_tensor","node_type_indices",
           "node_id2node_name","node_id2celltype_name"]
for m in methods:
    print("CALLING", m, flush=True)
    try:
        r = getattr(gpdb, m)()
        print("  OK", m, flush=True)
    except Exception as e:
        print("  PYEXC", m, repr(e), flush=True)
print("=== ALL METHODS OK ===", flush=True)
