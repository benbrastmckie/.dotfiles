import imaplib
import subprocess
import sys

pw = subprocess.run(
    ["secret-tool", "lookup", "service", "gmail-app-password", "username", "benbrastmckie@gmail.com"],
    capture_output=True, text=True, check=True
).stdout.strip()

M = imaplib.IMAP4_SSL("imap.gmail.com", 993)
try:
    M.login("benbrastmckie@gmail.com", pw)
    # READ-ONLY select — examine, not select, guarantees no flag mutation possible
    typ, data = M.select('"[Gmail]/All Mail"', readonly=True)
    print("SELECT status:", typ, data)

    # UID FETCH 34, BODY.PEEK to avoid setting \Seen (pure read, no STORE)
    typ, data = M.uid('fetch', '34', '(BODY.PEEK[HEADER.FIELDS (MESSAGE-ID SUBJECT)] UID)')
    print("FETCH status:", typ)
    for item in data:
        print(repr(item))
finally:
    try:
        M.close()
    except Exception:
        pass
    M.logout()
