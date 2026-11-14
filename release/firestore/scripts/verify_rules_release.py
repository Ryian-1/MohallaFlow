#!/usr/bin/env python3
"""Verify the active production Firestore Rules release source SHA."""
import argparse,hashlib,json,subprocess,sys,urllib.error,urllib.request
PROJECT="mohallaflow";EXPECTED="c5172f7b37059687f4545af60787eb383e5c8f1c0f79572e3ae5e975915899ed"
def get(url,token):
    req=urllib.request.Request(url,headers={"Authorization":"Bearer "+token,"x-goog-user-project":PROJECT,"Accept":"application/json"})
    try:
        with urllib.request.urlopen(req,timeout=45) as r:return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:raise RuntimeError(f"Rules API HTTP {e.code}: {e.read().decode(errors='replace')[:800]}")
def main():
    ap=argparse.ArgumentParser();ap.add_argument("--project",required=True);a=ap.parse_args()
    if a.project!=PROJECT:raise RuntimeError("Package is pinned to mohallaflow.")
    if subprocess.check_output(["gcloud","config","get-value","project"],text=True,stderr=subprocess.DEVNULL).strip()!=PROJECT:raise RuntimeError("gcloud project must be mohallaflow.")
    token=subprocess.check_output(["gcloud","auth","print-access-token"],text=True).strip()
    release=get(f"https://firebaserules.googleapis.com/v1/projects/{PROJECT}/releases/cloud.firestore",token)
    name=release.get("rulesetName","")
    if not name.startswith(f"projects/{PROJECT}/rulesets/"):raise RuntimeError("Unexpected active Ruleset reference.")
    ruleset=get("https://firebaserules.googleapis.com/v1/"+name,token)
    files=ruleset.get("source",{}).get("files",[])
    if len(files)!=1:raise RuntimeError(f"Expected one deployed rules source file; found {len(files)}.")
    actual=hashlib.sha256(files[0].get("content","").encode()).hexdigest()
    print("Active release:",release.get("name"));print("Ruleset:",name);print("Updated:",release.get("updateTime"));print("SHA256:",actual)
    if actual!=EXPECTED:raise RuntimeError("Active Rules release does not match the reviewed candidate.")
    print("[PASS] Exact reviewed Rules source is active.")
if __name__=="__main__":
    try:main()
    except Exception as e:print("[FAIL]",e,file=sys.stderr);sys.exit(2)
