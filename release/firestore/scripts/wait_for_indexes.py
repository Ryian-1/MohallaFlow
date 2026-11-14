#!/usr/bin/env python3
"""Wait until the required Firestore composite and single-field indexes are READY."""
import argparse,json,subprocess,sys,time
PROJECT="mohallaflow";DATABASE="(default)"
def listing(args):
    v=json.loads(subprocess.check_output(args,text=True,stderr=subprocess.PIPE) or "[]")
    return v.get("items",[]) if isinstance(v,dict) else v
def composite():
    rows=listing(["gcloud","firestore","indexes","composite","list",f"--database={DATABASE}",f"--project={PROJECT}","--format=json"])
    for x in rows:
        name=x.get("name","")
        if x.get("collectionGroup")!="emergencyAlerts" and "collectionGroups/emergencyAlerts/indexes/" not in name:continue
        if x.get("queryScope")!="COLLECTION_GROUP":continue
        fs=[(v.get("fieldPath"),v.get("order")) for v in x.get("fields",[])]
        if fs[:2]==[("status","ASCENDING"),("nextEscalationAt","ASCENDING")]:return x.get("state","UNKNOWN")
    return "NOT_FOUND"
def field_scopes():
    rows=listing(["gcloud","firestore","indexes","fields","list",f"--database={DATABASE}",f"--project={PROJECT}","--format=json"])
    for x in rows:
        name=x.get("name","")
        match=(x.get("collectionGroup")=="residentLoginRegistrations" and x.get("fieldPath")=="phoneNumberE164") or "collectionGroups/residentLoginRegistrations/fields/phoneNumberE164" in name
        if match:
            out={}
            for index in x.get("indexConfig",{}).get("indexes",[]):
                if index.get("order")=="ASCENDING":
                    scope=index.get("queryScope");out[scope]=index.get("state",x.get("state","UNKNOWN"))
            return out
    return {}
def main():
    ap=argparse.ArgumentParser();ap.add_argument("--timeout",type=int,default=3600);ap.add_argument("--interval",type=int,default=20);a=ap.parse_args()
    end=time.time()+a.timeout;last=None
    while time.time()<end:
        c=composite();f=field_scopes();state=(c,f.get("COLLECTION"),f.get("COLLECTION_GROUP"))
        if state!=last:print("emergencyAlerts:",c,"phoneNumberE164:",f);last=state
        if c=="ERROR" or "ERROR" in f.values():raise RuntimeError("Firestore reports an index ERROR state.")
        if state==("READY","READY","READY"):
            print("[PASS] Both required index configurations are READY.");return 0
        time.sleep(a.interval)
    print("[TIMEOUT] Required indexes did not reach READY.",file=sys.stderr);return 3
if __name__=="__main__":
    try:sys.exit(main())
    except subprocess.CalledProcessError as e:print(e.stderr or e,file=sys.stderr);sys.exit(2)
    except Exception as e:print("[FAIL]",e,file=sys.stderr);sys.exit(2)
