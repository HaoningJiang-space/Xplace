import sys, json
sys.argv = ["probe2"]
from cpp_to_py import io_parser
from utils import IOParser
params = json.load(open("/data/ziheng/wzh/bridge/gcd.json"))
parser = IOParser()
parser.check_params(params, False, 2, True, False, 8)
print("STEP params_checked", flush=True)
io_parser.load_params(parser.params);            print("STEP load_params", flush=True)
rawdb = io_parser.create_database();              print("STEP create_database", flush=True)
rawdb.load();                                     print("STEP rawdb_load", flush=True)
rawdb.setup();                                    print("STEP rawdb_setup", flush=True)
gpdb = io_parser.create_gpdatabase(rawdb);        print("STEP create_gpdatabase", flush=True)
gpdb.setup();                                     print("STEP gpdb_setup", flush=True)
print("STEP ALL_DONE", flush=True)
