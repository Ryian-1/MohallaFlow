#!/usr/bin/env python3
"""Read-only production membership compatibility census for the reviewed Rules."""
import argparse, concurrent.futures, hashlib, json, subprocess, sys, time
import urllib.error, urllib.parse, urllib.request
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

PROJECT="mohallaflow"
RULES_SHA="c5172f7b37059687f4545af60787eb383e5c8f1c0f79572e3ae5e975915899ed"
INDEX_SHA="29fd77ce28c3a52fdfa7dce9834683a6c441cd7bfb75de54cdc5e19e35b1bd63"
ROOT="https://firestore.googleapis.com/v1/projects/mohallaflow/databases/%28default%29/documents"
ROLES={"admin","resident","cleanliness_manager","worker"}

def run(args):
    return subprocess.check_output(args,text=True,stderr=subprocess.PIPE).strip()

def decode(v):
    if not isinstance(v,dict): return None
    for k in ("stringValue","booleanValue","integerValue","doubleValue","timestampValue"):
        if k in v:
            x=v[k]
            if k=="integerValue":
                try:return int(x)
                except Exception:return x
            if k=="doubleValue":
                try:return float(x)
                except Exception:return x
            return x
    if "nullValue" in v:return None
    if "arrayValue" in v:return [decode(x) for x in v["arrayValue"].get("values",[])]
    if "mapValue" in v:return fields(v["mapValue"].get("fields",{}))
    return None

def fields(obj): return {k:decode(v) for k,v in obj.items()}
def data(doc): return fields(doc.get("fields",{})) if doc else {}
def docid(doc): return doc.get("name","").rsplit("/",1)[-1]

class DB:
    def __init__(self,token): self.token=token
    def request(self,url,missing=False):
        headers={"Authorization":"Bearer "+self.token,"x-goog-user-project":PROJECT,"Accept":"application/json"}
        for n in range(5):
            try:
                with urllib.request.urlopen(urllib.request.Request(url,headers=headers),timeout=45) as r:
                    return json.loads(r.read().decode())
            except urllib.error.HTTPError as e:
                if missing and e.code==404:return None
                if e.code in (429,500,502,503,504) and n<4:
                    time.sleep(2**n);continue
                raise RuntimeError(f"Firestore REST HTTP {e.code}: {e.read().decode(errors='replace')[:800]}") from e
            except urllib.error.URLError as e:
                if n<4:time.sleep(2**n);continue
                raise RuntimeError(f"Firestore network error: {e}") from e
    def listing(self,path):
        out=[];token=None
        while True:
            q={"pageSize":"1000"}
            if token:q["pageToken"]=token
            url=ROOT+"/"+urllib.parse.quote(path,safe="/")+"?"+urllib.parse.urlencode(q)
            res=self.request(url);out.extend(res.get("documents",[]));token=res.get("nextPageToken")
            if not token:return out
    def get(self,path):
        return self.request(ROOT+"/"+urllib.parse.quote(path,safe="/"),missing=True)

def inspect(db,colony,doc):
    path=doc.get("name","").split("/documents/",1)[-1]
    uid=docid(doc);m=data(doc);status=m.get("status")
    active=isinstance(status,str) and status.strip().lower()=="active"
    bad=[];warn=[]
    def issue(code):
        x={"colony_id":colony,"issue":code,"document_fingerprint":hashlib.sha256(path.encode()).hexdigest()[:16]}
        (bad if active else warn).append(x)
    if m.get("uid")!=uid:issue("membership_uid_missing_or_mismatched")
    if m.get("colonyId")!=colony:issue("membership_colony_id_missing_or_mismatched")
    if not active:return bad,warn
    if status!="active":issue("membership_status_not_canonical")
    role=m.get("role")
    if role not in ROLES:issue("active_membership_role_invalid_or_noncanonical")
    if m.get("uid")!=uid or m.get("colonyId")!=colony:return bad,warn
    profile=db.get("users/"+uid);p=data(profile)
    if not profile:issue("active_user_profile_missing")
    else:
        if not isinstance(p.get("status"),str) or p["status"].lower()!="active":issue("user_profile_not_active")
        if not isinstance(p.get("colonyIds"),list) or colony not in p["colonyIds"]:issue("user_profile_colony_ids_missing_membership")
    if role=="resident":
        rid=m.get("residentId")
        if not isinstance(rid,str) or not rid.strip():issue("resident_id_missing")
        else:
            resident=db.get(f"colonies/{colony}/residents/{rid}")
            if not resident:issue("resident_record_missing")
            elif data(resident).get("residentStatus")!="active":issue("resident_record_not_active")
    if role=="worker":
        wid=m.get("workerId")
        if not isinstance(wid,str) or not wid.strip():issue("worker_id_missing")
        else:
            worker=db.get(f"colonies/{colony}/cleanlinessWorkers/{wid}")
            if not worker:issue("worker_profile_missing")
            elif data(worker).get("status")!="active":issue("worker_profile_not_active")
    return bad,warn

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--project",required=True);ap.add_argument("--rules",default="firestore.rules")
    ap.add_argument("--indexes",default="firestore.indexes.json");ap.add_argument("--output",default="reports/preflight.json")
    a=ap.parse_args()
    if a.project!=PROJECT:raise RuntimeError("This release package is pinned to mohallaflow.")
    if hashlib.sha256(Path(a.rules).read_bytes()).hexdigest()!=RULES_SHA:raise RuntimeError("Rules SHA mismatch.")
    if hashlib.sha256(Path(a.indexes).read_bytes()).hexdigest()!=INDEX_SHA:raise RuntimeError("Indexes SHA mismatch.")
    if run(["gcloud","config","get-value","project"])!=PROJECT:raise RuntimeError("Run: gcloud config set project mohallaflow")
    account=run(["gcloud","auth","list","--filter=status:ACTIVE","--format=value(account)"])
    if not account:raise RuntimeError("No active gcloud account.")
    db=DB(run(["gcloud","auth","print-access-token"]))
    colonies=db.listing("colonies")
    if not colonies:raise RuntimeError("No colonies found; refusing an empty-data pass.")
    members=[];counts={}
    for colony_doc in colonies:
        cid=docid(colony_doc);docs=db.listing(f"colonies/{cid}/members");counts[cid]=len(docs)
        members.extend((cid,d) for d in docs)
    blockers=[];warnings=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as pool:
        futures=[pool.submit(inspect,db,c,d) for c,d in members]
        for f in concurrent.futures.as_completed(futures):
            b,w=f.result();blockers.extend(b);warnings.extend(w)
    active=sum(1 for _,d in members if data(d).get("status")=="active")
    report={"project":PROJECT,"database":"(default)","gcloud_account":account,
      "scanned_at_utc":datetime.now(timezone.utc).isoformat(),"rules_sha256":RULES_SHA,"indexes_sha256":INDEX_SHA,
      "colonies_scanned":len(colonies),"membership_documents_scanned":len(members),"active_memberships_scanned":active,
      "blocking_issues":len(blockers),"blocking_issue_counts":dict(Counter(x["issue"] for x in blockers)),
      "inactive_legacy_warnings":len(warnings),"warning_counts":dict(Counter(x["issue"] for x in warnings)),
      "colony_membership_counts":counts,"blocking_fingerprints":blockers,"warning_fingerprints":warnings,
      "result":"PASS" if not blockers else "BLOCKED"}
    out=Path(a.output);out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(report,indent=2)+"\n")
    print(f"Account: {account} | colonies: {len(colonies)} | members: {len(members)} | active: {active}")
    print(f"Blocking issues: {len(blockers)} | inactive legacy warnings: {len(warnings)}")
    print(f"Report: {out} | result: {report['result']}")
    return 0 if not blockers else 3

if __name__=="__main__":
    try:sys.exit(main())
    except Exception as e:print("[BLOCKED]",e,file=sys.stderr);sys.exit(2)
