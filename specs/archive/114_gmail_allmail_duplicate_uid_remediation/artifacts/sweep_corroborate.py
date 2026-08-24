import os, re, sys, subprocess, imaplib, email

MAIL = os.path.expanduser("~/Mail/Gmail/.All_Mail")
CUR = os.path.join(MAIL, "cur")
STATE = os.path.join(MAIL, ".mbsyncstate")

uid_re = re.compile(r',U=(\d+):')

# 1. Build near-uid -> far-uid map from .mbsyncstate
near_to_far = {}
far_uidvalidity = None
with open(STATE, "r", errors="replace") as f:
    for line in f:
        line = line.rstrip("\n")
        if line.startswith("FarUidValidity"):
            far_uidvalidity = line.split()[1]
        parts = line.split()
        if len(parts) == 3 and parts[0].isdigit() and parts[1].isdigit():
            far, near, flag = parts
            near_to_far[near] = far

# 2. Group files by UID in cur/
from collections import defaultdict
groups = defaultdict(list)
for fn in os.listdir(CUR):
    m = uid_re.search(fn)
    if m:
        groups[m.group(1)].append(fn)
dupes = {uid: files for uid, files in groups.items() if len(files) > 1}

print(f"Total collisions: {len(dupes)}")
print(f"FarUidValidity (state file): {far_uidvalidity}")

# 3. Map near-uid -> far-uid for each collision; flag missing
resolved_far = {}
unresolved_no_state = []
for near in dupes:
    far = near_to_far.get(near)
    if far is None:
        unresolved_no_state.append(near)
    else:
        resolved_far[near] = far

print(f"Collisions with a .mbsyncstate near->far mapping: {len(resolved_far)}")
print(f"Collisions with NO .mbsyncstate mapping (cannot primary-corroborate): {len(unresolved_no_state)}")
if unresolved_no_state:
    print("  UNRESOLVED (no state mapping):", sorted(unresolved_no_state, key=int))

# 4. Single IMAP session, verify UIDVALIDITY, batch UID FETCH
pw = subprocess.run(
    ["secret-tool", "lookup", "service", "gmail-app-password", "username", "benbrastmckie@gmail.com"],
    capture_output=True, text=True, check=True
).stdout.strip()

M = imaplib.IMAP4_SSL("imap.gmail.com", 993)
M.login("benbrastmckie@gmail.com", pw)
typ, data = M.select('"[Gmail]/All Mail"', readonly=True)
typ, data = M.status('"[Gmail]/All Mail"', '(UIDVALIDITY)')
live_uidvalidity = data[0].decode().split("UIDVALIDITY ")[1].rstrip(")")
print(f"Live IMAP UIDVALIDITY: {live_uidvalidity}  (match: {live_uidvalidity == far_uidvalidity})")
if live_uidvalidity != far_uidvalidity:
    print("ABORT: UIDVALIDITY MISMATCH -- far-UID mapping cannot be trusted. STOP.")
    M.logout()
    sys.exit(2)

far_to_msgid = {}
far_list = sorted(set(resolved_far.values()), key=int)
BATCH = 40
for i in range(0, len(far_list), BATCH):
    batch = far_list[i:i+BATCH]
    uid_set = ",".join(batch)
    typ, data = M.uid('fetch', uid_set, '(UID BODY.PEEK[HEADER.FIELDS (MESSAGE-ID)])')
    if typ != "OK":
        print(f"FETCH FAILED for batch {uid_set}: {typ} {data}")
        continue
    for item in data:
        if not isinstance(item, tuple):
            continue
        header_line, payload = item
        m_uid = re.search(rb'UID (\d+)', header_line)
        if not m_uid:
            continue
        far_uid = m_uid.group(1).decode()
        msg = email.message_from_bytes(payload)
        msgid = msg.get("Message-ID", "").strip()
        far_to_msgid[far_uid] = msgid

M.close()
M.logout()

print(f"Far-UIDs fetched: {len(far_to_msgid)} / requested {len(far_list)}")
missing_fetch = [f for f in far_list if f not in far_to_msgid or not far_to_msgid[f]]
if missing_fetch:
    print(f"WARNING: {len(missing_fetch)} far-UIDs returned no Message-ID: {missing_fetch}")

# 5. For each resolved near-uid, match against the two candidate files' local Message-ID headers
def get_local_msgid(fname):
    path = os.path.join(CUR, fname)
    with open(path, "rb") as fh:
        msg = email.message_from_binary_file(fh)
    return (msg.get("Message-ID") or "").strip()

decisions = []
unresolved_mismatch = []
for near, files in dupes.items():
    if near not in resolved_far:
        continue
    far = resolved_far[near]
    fetched_msgid = far_to_msgid.get(far, "")
    file_msgids = {fn: get_local_msgid(fn) for fn in files}
    matches = [fn for fn, mid in file_msgids.items() if mid == fetched_msgid and mid != ""]
    if len(matches) == 1:
        legit = matches[0]
        stray = [fn for fn in files if fn != legit][0]
        decisions.append((near, far, legit, stray))
    else:
        unresolved_mismatch.append((near, far, fetched_msgid, file_msgids))

print(f"\nRESOLVED (unambiguous legit/stray via primary IMAP signal): {len(decisions)}")
print(f"UNRESOLVED (fetched Message-ID matched 0 or 2+ candidate files): {len(unresolved_mismatch)}")

with open(os.path.join(os.path.dirname(__file__), "05_sweep-decisions.tsv"), "w") as out:
    out.write("near_uid\tfar_uid\tlegit_file\tstray_file\n")
    for near, far, legit, stray in sorted(decisions, key=lambda x: int(x[0])):
        out.write(f"{near}\t{far}\t{legit}\t{stray}\n")

with open(os.path.join(os.path.dirname(__file__), "05_sweep-unresolved.txt"), "w") as out:
    for near in sorted(unresolved_no_state, key=int):
        out.write(f"NO_STATE_MAPPING near_uid={near} files={dupes[near]}\n")
    for near, far, fetched_msgid, file_msgids in unresolved_mismatch:
        out.write(f"MISMATCH near_uid={near} far_uid={far} fetched_msgid={fetched_msgid!r} files={file_msgids}\n")

print("\nWrote 05_sweep-decisions.tsv and 05_sweep-unresolved.txt")
